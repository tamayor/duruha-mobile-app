import 'package:duruha/features/consumer/features/manage/domain/order_details_model.dart';
import 'package:duruha/supabase_config.dart';
import 'package:flutter/foundation.dart';
import '../../../../../shared/produce/domain/produce_model.dart';

class TransactionRepository {
  /// Creates orders and attempts to match them.
  /// Returns a [PlaceOrderResult] with details about the outcome.
  Future<PlaceOrderResult?> txCreateOrder({
    required List<Produce> selectedProduce,
    required Map<String, Map<String, double>> cropQuantities,
    required Map<String, String> cropQualities,
    required Map<String, Map<String, DateTime?>> varietyDateNeeded,
    required Map<String, List<Set<String>>> varietyGroups,
    Map<String, Map<String, String?>>? varietySelectedFormId,
    Map<String, Map<String, bool>>? varietyPriceLock,
    String? note,
    String paymentMethod = 'Cash',
    String? cplsId,
  }) async {
    try {
      final List<Map<String, dynamic>> orderEntries = [];
      final Map<String, Map<String, dynamic>> groupedProduce = {};

      for (var produce in selectedProduce) {
        final cropId = produce.id;
        final quantities = cropQuantities[cropId] ?? {};
        final dates = varietyDateNeeded[cropId] ?? {};
        final groups = varietyGroups[cropId] ?? [];
        final formIds = varietySelectedFormId?[cropId] ?? {};

        // Track which varieties have been processed via grouping
        final Set<String> processedVarieties = {};

        // 1. Process Groups
        for (var group in groups) {
          final groupVarietyIds = <String>[];
          String? groupFormName;
          double groupTotalQty = 0;
          DateTime? groupDate;

          for (var variantName in group) {
            if (quantities.containsKey(variantName)) {
              final qty = quantities[variantName] ?? 0;
              groupTotalQty += qty;
              processedVarieties.add(variantName);

              // Get date - all varieties in a group should share the same date
              groupDate ??= dates[variantName];

              // Find variety ID
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
            final dateStr = groupDate.toIso8601String().split('T')[0];
            _addOrUpdateProduceGroup(
              groupedProduce: groupedProduce,
              cropId: cropId,
              dateStr: dateStr,
              varietyIds: groupVarietyIds,
              formName: groupFormName,
              quantity: groupTotalQty,
              quality: cropQualities[cropId] ?? 'Saver',
              cplsId: cplsId,
            );
          }
        }

        // 2. Process Remaining Ungrouped Varieties
        for (var entry in quantities.entries) {
          final variantName = entry.key;
          if (processedVarieties.contains(variantName)) continue;

          final qty = entry.value;
          if (qty <= 0) continue;

          final date = dates[variantName];
          if (date == null) continue;

          final dateStr = date.toIso8601String().split('T')[0];
          final isAny = variantName.toLowerCase() == 'any';
          final List<String> varietyIdsList = [];

          if (isAny) {
            varietyIdsList.add("");
          } else {
            final variety = produce.varieties.firstWhere(
              (v) => v.name == variantName,
              orElse: () => produce.varieties.first,
            );
            varietyIdsList.add(variety.id);
          }
          final formName = formIds[variantName];

          _addOrUpdateProduceGroup(
            groupedProduce: groupedProduce,
            cropId: cropId,
            dateStr: dateStr,
            varietyIds: varietyIdsList,
            formName: formName,
            quantity: qty,
            quality: cropQualities[cropId] ?? 'Saver',
            cplsId: cplsId,
          );
        }
      }

      orderEntries.addAll(groupedProduce.values);

      if (orderEntries.isEmpty) {
        debugPrint('⚠️ [TX CREATE ORDER] No valid quantities/dates to insert.');
        return null;
      }

      debugPrint(
        '🚀 [TX CREATE ORDER] Preparing ${orderEntries.length} produce entries',
      );

      // New payload shape:
      // {
      //   "payment_method": "Cash",
      //   "p_orders": [ { produce_id, order_items: [...] } ]
      // }
      final payload = {
        'p_payload': {
          'payment_method': paymentMethod,
          'p_orders': orderEntries,
        },
        'p_note': note,
      };
      // debugPrint('📦 [TX PAYLOAD]: ${jsonEncode(payload)}');

      final match = await supabase.rpc(
        'place_and_match_order',
        params: payload,
      );

      // debugPrint('📦 [TX MATCH RESPONSE]: ${jsonEncode(match)}');

      if (match != null) {
        return PlaceOrderResult.fromJson(Map<String, dynamic>.from(match));
      }

      return null;
    } catch (e) {
      debugPrint('❌ [TX CREATE ORDER ERROR]: $e');
      rethrow;
    }
  }

  /// Fetches a single order match detail by order ID.
  Future<ConsumerOrderMatch?> fetchOrderMatch(String orderId) async {
    try {
      final response = await supabase.rpc(
        'get_consumer_orders_match',
        params: {'p_match_id': orderId},
      );

      if (response != null && response is List && response.isNotEmpty) {
        return ConsumerOrderMatch.fromJson(
          Map<String, dynamic>.from(response.first),
        );
      }
      return null;
    } catch (e) {
      debugPrint('❌ [TX FETCH ORDER MATCH ERROR]: $e');
      return null;
    }
  }

  /// Fetches a single order detail by order ID using the specific fetcher.
  Future<ConsumerOrderMatch?> fetchSpecificOrder(String orderId) async {
    try {
      final response = await supabase.rpc(
        'get_consumer_order_by_id',
        params: {'p_order_id': orderId},
      );

      if (response != null) {
        return ConsumerOrderMatch.fromJson(Map<String, dynamic>.from(response));
      }
      return null;
    } catch (e) {
      debugPrint('❌ [TX FETCH SPECIFIC ORDER ERROR]: $e');
      return null;
    }
  }

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
    final produceKey = cropId; // Group only by cropId

    if (!groupedProduce.containsKey(produceKey)) {
      groupedProduce[produceKey] = {
        'produce_id': cropId,
        'order_items': <Map<String, dynamic>>[],
        'quality': quality,
      };
    }

    final produceGroup = groupedProduce[produceKey]!;
    final varietiesList =
        produceGroup['order_items'] as List<Map<String, dynamic>>;

    // Check if this exact set of variety IDs AND the date already exists in this produce group
    final existingEntry = varietiesList
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (v) =>
              (v?['variety_ids'] as List).join(',') == varietyIds.join(',') &&
              v?['date_needed'] == dateStr,
          orElse: () => null,
        );

    if (existingEntry != null) {
      existingEntry['quantity'] =
          (existingEntry['quantity'] as double) + quantity;
    } else {
      varietiesList.add({
        'variety_ids': varietyIds,
        'form': formName,
        'quantity': quantity,
        'date_needed': dateStr,
        if (cplsId != null) 'cpls_id': cplsId,
      });
    }
  }
}
