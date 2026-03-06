import 'package:duruha/features/consumer/features/manage/domain/order_details_model.dart';
import 'package:duruha/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../../../../shared/produce/domain/produce_model.dart';
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
    String? cplsId,
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
              cplsId: cplsId,
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
            cplsId: cplsId,
          );
        }
      }

      final orderEntries = groupedProduce.values.toList();
      if (orderEntries.isEmpty) {
        debugPrint('⚠️ [ORDER] No valid quantities/dates to submit.');
        return null;
      }

      // debugPrint('🚀 [ORDER] Submitting ${orderEntries.length} entries');

      final payload = {
        'p_payload': {'p_orders': orderEntries},
        'p_note': note,
      };
      // debugPrint('🚀 [ORDER] Payload: $payload');
      final match = await supabase.rpc(
        'om_place_and_match_order',
        params: payload,
      );

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

      final payload = {'p_note': note ?? '', 'p_orders': pOrders};
      // debugPrint('Payload: $payload');

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
    required String? cplsId,
  }) {
    groupedProduce.putIfAbsent(
      cropId,
      () => {
        'produce_id': cropId,
        'order_items': <Map<String, dynamic>>[],
        'quality': quality,
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
        if (cplsId != null) 'cpls_id': cplsId,
      });
    }
  }
}
