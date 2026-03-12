import 'package:duruha/features/consumer/features/manage/domain/order_details_model.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../../../../shared/produce/domain/produce_model.dart';
import '../../../../../shared/user/domain/user_address_model.dart';
import '../presentation/widgets/recurring_picker.dart';

// ─── Return Shapes ────────────────────────────────────────────────────────────

/// Returned after successfully placing an Order (single purchase).
/// Wraps the RPC result which contains match details.
class OrderSubmitResult {
  final PlaceOrderResult placeOrderResult;
  const OrderSubmitResult(this.placeOrderResult);
}

// ─── Repository ───────────────────────────────────────────────────────────────

class TransactionRepository {
  // ── Order Mode ──────────────────────────────────────────────────────────────

  /// Creates a single-purchase order and attempts immediate matching.
  /// Returns [OrderSubmitResult] on success.
  Future<OrderSubmitResult?> txCreateOrder({
    required List<Produce> selectedProduce,
    required Map<String, Map<String, double>> cropQuantities,
    required Map<String, String> cropQualities,
    required Map<String, Map<String, DateTime?>> varietyDateNeeded,
    required Map<String, List<Set<String>>> varietyGroups,
    Map<String, Map<String, String?>>? varietySelectedFormId,
    Map<String, Map<String, bool>>? varietyPriceLock,
    String? note,
    String? cpsId,
    String? addressId,
  }) async {
    try {
      final Map<String, Map<String, dynamic>> groupedProduce = {};

      for (var produce in selectedProduce) {
        final cropId = produce.id;
        final quantities = cropQuantities[cropId] ?? {};
        final dates = varietyDateNeeded[cropId] ?? {};
        final groups = varietyGroups[cropId] ?? [];
        final formIds = varietySelectedFormId?[cropId] ?? {};

        final Set<String> processedVarieties = {};

        // 1. Process grouped varieties
        for (var group in groups) {
          final groupVarietyIds = <String>[];
          String? groupFormName;
          double groupTotalQty = 0;
          DateTime? groupDate;
          final groupIndex = groups.indexOf(group);
          final groupKey = 'group_$groupIndex';

          for (var variantName in group) {
            if (quantities.containsKey(variantName)) {
              if (groupTotalQty == 0) {
                groupTotalQty = quantities[variantName] ?? 0;
              }
              processedVarieties.add(variantName);
              groupDate ??= dates[variantName];

              final variety = produce.varieties.firstWhere(
                (v) => v.name == variantName,
                orElse: () => produce.varieties.first,
              );
              groupVarietyIds.add(variety.id);

              final lid = formIds[variantName];
              if (lid != null) groupFormName ??= lid;
            }
          }

          if (groupTotalQty > 0 && groupDate != null) {
            _addOrUpdateProduceGroup(
              groupedProduce: groupedProduce,
              cropId: cropId,
              dateStr: groupDate.toIso8601String().split('T')[0],
              varietyIds: groupVarietyIds,
              formName: groupFormName,
              quantity: groupTotalQty,
              quality: cropQualities[cropId] ?? 'Saver',
              isPriceLock: varietyPriceLock?[cropId]?[groupKey] ?? false,
            );
          }
        }

        // 2. Process ungrouped varieties
        for (var entry in quantities.entries) {
          final variantName = entry.key;
          if (processedVarieties.contains(variantName)) continue;

          final qty = entry.value;
          if (qty <= 0) continue;

          final date = dates[variantName];
          if (date == null) continue;

          final isAny = variantName.toLowerCase() == 'any';
          final List<String> varietyIdsList = isAny
              ? []
              : [
                  produce.varieties
                      .firstWhere(
                        (v) => v.name == variantName,
                        orElse: () => produce.varieties.first,
                      )
                      .id,
                ];

          _addOrUpdateProduceGroup(
            groupedProduce: groupedProduce,
            cropId: cropId,
            dateStr: date.toIso8601String().split('T')[0],
            varietyIds: varietyIdsList,
            formName: formIds[variantName],
            quantity: qty,
            quality: cropQualities[cropId] ?? 'Saver',
            isPriceLock: varietyPriceLock?[cropId]?[variantName] ?? false,
          );
        }
      }

      final orderEntries = groupedProduce.values.toList();
      if (orderEntries.isEmpty) {
        debugPrint('⚠️ [ORDER] No valid quantities/dates to submit.');
        return null;
      }

      // If explicitly 'profile', treat as null to trigger fetchUserAddressId() fallback
      final effectiveAddressId =
          (addressId == 'profile' ? null : addressId) ??
          await fetchUserAddressId();

      final payload = {
        'p_orders': orderEntries,
        if (cpsId != null) 'p_cps_id': cpsId,
        'p_note': note,
        'p_address_id': effectiveAddressId,
      };

      final match = await supabase.rpc('match_order', params: payload);

      if (match != null) {
        return OrderSubmitResult(
          PlaceOrderResult.fromJson(Map<String, dynamic>.from(match)),
        );
      }

      return null;
    } catch (e) {
      debugPrint('❌ [ORDER ERROR]: $e');
      rethrow;
    }
  }

  // ── Plan Mode ───────────────────────────────────────────────────────────────

  /// Creates a recurring plan (pledge schedule).
  /// Returns [PlanSubmitResult] on success.
  Future<String?> txCreatePlan({
    required List<Produce> selectedProduce,
    required Map<String, Map<String, double>> cropQuantities,
    required Map<String, String> cropQualities,
    required Map<String, Map<String, String?>> cropVarietyRecurrence,
    required Map<String, List<Set<String>>> varietyGroups,
    Map<String, Map<String, String?>>? varietySelectedFormId,
    String? note,
    String? addressId,
  }) async {
    try {
      // Key: produceId_quality
      final Map<String, Map<String, dynamic>> produceGroups = {};

      for (var produce in selectedProduce) {
        final cropId = produce.id;
        final quantities = cropQuantities[cropId] ?? {};
        final recurrences = cropVarietyRecurrence[cropId] ?? {};
        final groups = varietyGroups[cropId] ?? [];
        final formIds = varietySelectedFormId?[cropId] ?? {};
        final quality = cropQualities[cropId] ?? 'Regular';

        final groupKey = '${cropId}_$quality';
        produceGroups.putIfAbsent(
          groupKey,
          () => {
            'produce_id': cropId,
            'quality': quality,
            'order_items': <Map<String, dynamic>>[],
          },
        );

        final orderItems =
            produceGroups[groupKey]!['order_items']
                as List<Map<String, dynamic>>;
        final Set<String> processedVarieties = {};

        // 1. Grouped items
        for (int i = 0; i < groups.length; i++) {
          final group = groups[i];
          final vGroupKey = 'group_$i';
          final recurrence =
              recurrences[vGroupKey] ?? recurrences['qty_$vGroupKey'];
          if (recurrence == null || recurrence.isEmpty) continue;

          final groupVarietyIds = <String>[];
          double groupQty = 0;
          String? groupFormName;

          for (var variantName in group) {
            processedVarieties.add(variantName);
            if (groupQty == 0) {
              groupQty = quantities[variantName] ?? 0;
            }

            final variety = produce.varieties.firstWhere(
              (v) => v.name == variantName,
              orElse: () => produce.varieties.first,
            );
            groupVarietyIds.add(variety.id);

            final lid = formIds[variantName];
            if (lid != null) groupFormName ??= lid;
          }

          if (groupQty <= 0) continue;

          final dates = RecurringPickerUtil.computeDates(
            recurrence,
          ).map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

          if (dates.isEmpty) continue;

          orderItems.add({
            'variety_ids': groupVarietyIds,
            'form': groupFormName,
            'quantity': groupQty,
            'date_needed': dates,
          });
        }

        // 2. Ungrouped items
        for (var entry in quantities.entries) {
          final variantName = entry.key;
          if (processedVarieties.contains(variantName)) continue;

          final qty = entry.value;
          final recurrenceKey = 'qty_$variantName';
          final recurrence =
              recurrences[recurrenceKey] ?? recurrences[variantName];
          if (recurrence == null || recurrence.isEmpty) continue;
          if (qty <= 0) continue;

          final isAny = variantName.toLowerCase() == 'any';
          final List<String> varietyIdsList = isAny
              ? []
              : [
                  produce.varieties
                      .firstWhere(
                        (v) => v.name == variantName,
                        orElse: () => produce.varieties.first,
                      )
                      .id,
                ];

          final dates = RecurringPickerUtil.computeDates(
            recurrence,
          ).map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

          if (dates.isEmpty) continue;

          orderItems.add({
            'variety_ids': varietyIdsList,
            'form': formIds[variantName],
            'quantity': qty,
            'date_needed': dates,
          });
        }
      }

      // Filter out produce groups with no items
      final pOrders = produceGroups.values
          .where((g) => (g['order_items'] as List).isNotEmpty)
          .toList();

      if (pOrders.isEmpty) {
        debugPrint('⚠️ [PLAN] No valid entries to submit.');
        return null;
      }

      debugPrint('🗓️ [PLAN] Submitting ${pOrders.length} produce groups');

      // If explicitly 'profile', treat as null to trigger fetchUserAddressId() fallback
      final effectiveAddressId =
          (addressId == 'profile' ? null : addressId) ??
          await fetchUserAddressId();

      final payload = {
        'p_note': note ?? '',
        'p_orders': pOrders,
        'p_address_id': effectiveAddressId,
      };
      debugPrint('Payload: $payload');

      final response = await supabase.rpc(
        'plan_orders',
        params: {'p_payload': payload},
      );

      if (response != null) {
        final orderId = response as String;
        debugPrint('🗓️ [PLAN] Created order: $orderId');
        return orderId;
      }

      return null;
    } catch (e) {
      debugPrint('❌ : $e');
      rethrow;
    }
  }

  /// Fetches the user's default address ID from the users table.
  Future<String?> fetchUserAddressId() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final response = await supabase
          .from('users')
          .select('address_id')
          .eq('id', user.id)
          .maybeSingle();

      return response?['address_id'] as String?;
    } catch (e) {
      debugPrint('⚠️ [FETCH ADDRESS ERROR]: $e');
      return null;
    }
  }

  /// Fetches all saved addresses for the current user.
  /// Falls back to Profile address if users_addresses is empty.
  Future<List<UserAddress>> fetchAllUserAddresses() async {
    try {
      final authUser = supabase.auth.currentUser;
      if (authUser == null) return [];

      final response = await supabase.rpc(
        'manage_profile',
        params: {'p_mode': 'get_addresses'},
      );

      if (response != null) {
        final list = response as List;
        if (list.isNotEmpty) {
          return list
              .map((addr) =>
                  UserAddress.fromJson(Map<String, dynamic>.from(addr as Map)))
              .toList();
        }
      }

      // ── Fallback to Profile ───────────────────────────────────────────────
      final profile = await SessionService.getSavedUser();
      if (profile != null &&
          profile.province != null &&
          profile.province!.isNotEmpty) {
        return [
          UserAddress(
            addressId: 'profile', // Virtual ID
            userId: authUser.id,
            createdAt: DateTime.now(),
            city: profile.city ?? '',
            province: profile.province ?? '',
            landmark: profile.landmark ?? '',
            postalCode: profile.postalCode ?? '',
            latitude: profile.latitude ?? 0.0,
            longitude: profile.longitude ?? 0.0,
          ),
        ];
      }

      return [];
    } catch (e) {
      debugPrint('⚠️ [FETCH ALL ADDRESSES ERROR]: $e');
      return [];
    }
  }

  /// Upserts a user address entry via the manage_profile RPC (insert_address mode).
  /// This correctly handles the location::geography conversion via ST_MakePoint.
  Future<UserAddress?> upsertUserAddress(
    UserAddress address, {
    bool setAsActive = false,
  }) async {
    try {
      final isNew = address.addressId.isEmpty || address.addressId == 'new';

      final pData = <String, dynamic>{
        if (!isNew) 'address_id': address.addressId,
        'address_line_1': address.addressLine1,
        'address_line_2': address.addressLine2,
        'city': address.city,
        'province': address.province,
        'landmark': address.landmark,
        'region': address.region,
        'postal_code': address.postalCode,
        'country': address.country,
        if (address.latitude != null) 'latitude': address.latitude,
        if (address.longitude != null) 'longitude': address.longitude,
        'set_as_active': setAsActive,
      };

      final result = await supabase.rpc(
        'manage_profile',
        params: {'p_mode': 'insert_address', 'p_data': pData},
      );

      final savedId = result['address_id'] as String?;
      if (savedId == null) return null;

      // Re-fetch via RPC so lat/lng are returned as decoded numbers (not WKB).
      final allAddresses = await fetchAllUserAddresses();
      final saved = allAddresses.where((a) => a.addressId == savedId).firstOrNull;
      if (saved != null) return saved;

      // Fallback: return address without coordinates if RPC fetch fails.
      return UserAddress(
        addressId: savedId,
        createdAt: DateTime.now(),
        addressLine1: address.addressLine1,
        addressLine2: address.addressLine2,
        city: address.city,
        province: address.province,
        region: address.region,
        country: address.country,
        landmark: address.landmark,
        postalCode: address.postalCode,
        latitude: address.latitude,
        longitude: address.longitude,
      );
    } catch (e) {
      debugPrint('❌ [UPSERT ADDRESS ERROR]: $e');
      rethrow;
    }
  }

  // ── Query helpers ────────────────────────────────────────────────────────────

  /// Fetches a single order match detail by match ID.
  Future<ConsumerOrderMatch?> fetchOrderMatch(String matchId) async {
    try {
      final response = await supabase.rpc(
        'get_consumer_orders_match',
        params: {'p_match_id': matchId},
      );
      if (response is List && response.isNotEmpty) {
        return ConsumerOrderMatch.fromJson(
          Map<String, dynamic>.from(response.first as Map),
        );
      }
      return null;
    } catch (e) {
      debugPrint('❌ [FETCH MATCH ERROR]: $e');
      return null;
    }
  }

  /// Fetches a single order by order ID.
  Future<ConsumerOrderMatch?> fetchSpecificOrder(String orderId) async {
    try {
      final response = await supabase.rpc(
        'get_consumer_order_by_id',
        params: {'p_order_id': orderId},
      );
      if (response != null) {
        return ConsumerOrderMatch.fromJson(
          Map<String, dynamic>.from(response as Map),
        );
      }
      return null;
    } catch (e) {
      debugPrint('❌ [FETCH ORDER ERROR]: $e');
      return null;
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  void _addOrUpdateProduceGroup({
    required Map<String, Map<String, dynamic>> groupedProduce,
    required String cropId,
    required String dateStr,
    required List<String> varietyIds,
    required String? formName,
    required double quantity,
    required String quality,
    required bool isPriceLock,
  }) {
    groupedProduce.putIfAbsent(
      cropId,
      () => {
        'produce_id': cropId,
        'order_items': <Map<String, dynamic>>[],
        'quality': quality.toLowerCase(),
      },
    );

    final items =
        groupedProduce[cropId]!['order_items'] as List<Map<String, dynamic>>;

    final existing = items.cast<Map<String, dynamic>?>().firstWhere(
      (v) =>
          (v?['variety_ids'] as List).join(',') == varietyIds.join(',') &&
          v?['date_needed'] == dateStr,
      orElse: () => null,
    );

    if (existing != null) {
      existing['quantity'] = (existing['quantity'] as double) + quantity;
    } else {
      items.add({
        'variety_ids': varietyIds,
        'form': formName,
        'quantity': quantity,
        'date_needed': dateStr,
        'is_price_lock': isPriceLock,
      });
    }
  }
}
