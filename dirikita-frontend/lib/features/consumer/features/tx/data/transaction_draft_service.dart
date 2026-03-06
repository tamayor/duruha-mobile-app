import 'dart:convert';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Draft key strategy:
///   Order Mode  →  'ord_draft_<cropId>'
///   Plan Mode   →  'pln_draft_<cropId>'
///
/// This prevents data contamination when the user switches modes.
class TransactionDraftService {
  static const String _orderPrefix = 'ord_draft_';
  static const String _planPrefix = 'pln_draft_';

  static String _key(String cropId, TransactionMode mode) {
    final prefix =
        mode == TransactionMode.order ? _orderPrefix : _planPrefix;
    return '$prefix$cropId';
  }

  /// Saves the draft data for a specific crop and mode.
  static Future<void> saveDraft(
    String cropId,
    CropDraftData data,
    TransactionMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(cropId, mode), jsonEncode(data.toJson()));
  }

  /// Retrieves the draft data for a specific crop and mode.
  static Future<CropDraftData?> getDraft(
    String cropId,
    TransactionMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key(cropId, mode));
    if (jsonStr != null) {
      try {
        return CropDraftData.fromJson(jsonDecode(jsonStr));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Clears the draft for a specific crop and mode.
  static Future<void> clearDraft(String cropId, TransactionMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(cropId, mode));
  }

  /// Clears all drafts for a given mode.
  static Future<void> clearAllForMode(TransactionMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix =
        mode == TransactionMode.order ? _orderPrefix : _planPrefix;
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Clears ALL drafts (both modes) — used on full reset.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith(_orderPrefix) || k.startsWith(_planPrefix),
        )
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

/// Which transaction mode is active.
enum TransactionMode { order, plan }

// ─── CropDraftData ────────────────────────────────────────────────────────────

class CropDraftData {
  final List<DateTime> selectedHarvestDates;
  final DateTime? availableDate;
  final DateTime? disposalDate;
  final String selectedUnit;
  final Map<String, double> varietyQuantities;
  final List<Map<String, dynamic>>? simulatedDemand;
  final List<HarvestEntry> perDatePledges;
  final Map<DateTime, DateDemandData> dateSpecificDemand;
  final Map<String, DateTime?> varietyAvailableDates;
  final Map<String, DateTime?> varietyDisposalDates;
  final Map<String, DateTime?> varietyDateNeeded;
  final List<Set<String>> varietyGroups;
  final List<String>? qualityPreferences;
  final double? qualityFee;
  final Map<String, String?> varietySelectedFormId;
  final Map<String, bool> varietyPriceLock;
  final Map<String, String?> varietyRecurrence;

  CropDraftData({
    this.selectedHarvestDates = const [],
    this.availableDate,
    this.disposalDate,
    required this.selectedUnit,
    Map<String, double>? varietyQuantities,
    this.simulatedDemand,
    List<HarvestEntry>? perDatePledges,
    Map<DateTime, DateDemandData>? dateSpecificDemand,
    Map<String, DateTime?>? varietyAvailableDates,
    Map<String, DateTime?>? varietyDisposalDates,
    Map<String, DateTime?>? varietyDateNeeded,
    List<Set<String>>? varietyGroups,
    this.qualityPreferences,
    this.qualityFee,
    Map<String, String?>? varietySelectedFormId,
    Map<String, bool>? varietyPriceLock,
    Map<String, String?>? varietyRecurrence,
  }) : varietyQuantities = varietyQuantities ?? {},
       perDatePledges = perDatePledges ?? [],
       dateSpecificDemand = dateSpecificDemand ?? {},
       varietyAvailableDates = varietyAvailableDates ?? {},
       varietyDisposalDates = varietyDisposalDates ?? {},
       varietyDateNeeded = varietyDateNeeded ?? {},
       varietyGroups = varietyGroups ?? [],
       varietySelectedFormId = varietySelectedFormId ?? {},
       varietyPriceLock = varietyPriceLock ?? {},
       varietyRecurrence = varietyRecurrence ?? {};

  Map<String, dynamic> toJson() => {
    'selectedHarvestDates':
        selectedHarvestDates.map((e) => e.toIso8601String()).toList(),
    'availableDate': availableDate?.toIso8601String(),
    'disposalDate': disposalDate?.toIso8601String(),
    'selectedUnit': selectedUnit,
    'varietyQuantities': varietyQuantities,
    'simulatedDemand': simulatedDemand,
    'perDatePledges': perDatePledges.map((e) => e.toJson()).toList(),
    'dateSpecificDemand': dateSpecificDemand.map(
      (key, value) => MapEntry(key.toIso8601String(), value.toJson()),
    ),
    'varietyAvailableDates': varietyAvailableDates.map(
      (key, value) => MapEntry(key, value?.toIso8601String()),
    ),
    'varietyDisposalDates': varietyDisposalDates.map(
      (key, value) => MapEntry(key, value?.toIso8601String()),
    ),
    'varietyDateNeeded': varietyDateNeeded.map(
      (key, value) => MapEntry(key, value?.toIso8601String()),
    ),
    'varietyGroups': varietyGroups.map((g) => g.toList()).toList(),
    'qualityPreferences': qualityPreferences,
    'qualityFee': qualityFee,
    'varietySelectedFormId': varietySelectedFormId,
    'varietyPriceLock': varietyPriceLock,
    'varietyRecurrence': varietyRecurrence,
  };

  factory CropDraftData.fromJson(Map<String, dynamic> json) {
    List<HarvestEntry> parsedPledges = [];
    if (json['perDatePledges'] != null) {
      if (json['perDatePledges'] is List) {
        parsedPledges = (json['perDatePledges'] as List)
            .map((e) => HarvestEntry.fromJson(e))
            .toList();
      } else if (json['perDatePledges'] is Map) {
        (json['perDatePledges'] as Map<String, dynamic>).forEach((
          dateKey,
          value,
        ) {
          final date = DateTime.parse(dateKey);
          if (value is Map) {
            value.forEach((variety, qty) {
              parsedPledges.add(
                HarvestEntry(
                  date: date,
                  variety: variety,
                  quantity: (qty as num).toDouble(),
                ),
              );
            });
          }
        });
      }
    }

    return CropDraftData(
      selectedHarvestDates: (json['selectedHarvestDates'] as List? ?? [])
          .map((e) => DateTime.parse(e as String))
          .toList(),
      availableDate: json['availableDate'] != null
          ? DateTime.parse(json['availableDate'] as String)
          : null,
      disposalDate: json['disposalDate'] != null
          ? DateTime.parse(json['disposalDate'] as String)
          : null,
      selectedUnit: json['selectedUnit'] as String? ?? 'kg',
      varietyQuantities:
          Map<String, double>.from(json['varietyQuantities'] ?? {}),
      simulatedDemand: json['simulatedDemand'] != null
          ? List<Map<String, dynamic>>.from(json['simulatedDemand'] as List)
          : null,
      perDatePledges: parsedPledges,
      dateSpecificDemand: (json['dateSpecificDemand'] as Map<String, dynamic>?)
              ?.map((key, value) {
            if (value is num) {
              return MapEntry(
                DateTime.parse(key),
                DateDemandData(
                  totalDemand: value.toDouble(),
                  totalFulfilled: 0,
                  varietyBreakdown: [],
                ),
              );
            }
            return MapEntry(
              DateTime.parse(key),
              DateDemandData.fromJson(value as Map<String, dynamic>),
            );
          }) ??
          {},
      varietyAvailableDates: (json['varietyAvailableDates'] as Map? ?? {}).map(
        (key, value) => MapEntry(
          key.toString(),
          value != null ? DateTime.parse(value.toString()) : null,
        ),
      ),
      varietyDisposalDates: (json['varietyDisposalDates'] as Map? ?? {}).map(
        (key, value) => MapEntry(
          key.toString(),
          value != null ? DateTime.parse(value.toString()) : null,
        ),
      ),
      varietyDateNeeded: (json['varietyDateNeeded'] as Map? ?? {}).map(
        (key, value) => MapEntry(
          key.toString(),
          value != null ? DateTime.parse(value.toString()) : null,
        ),
      ),
      varietyGroups: (json['varietyGroups'] as List? ?? [])
          .map((g) => Set<String>.from(g as List))
          .toList(),
      qualityPreferences: json['qualityPreferences'] != null
          ? List<String>.from(json['qualityPreferences'] as List)
          : (json['qualityPreference'] != null
                ? [json['qualityPreference'] as String]
                : null),
      qualityFee: (json['qualityFee'] as num?)?.toDouble(),
      varietySelectedFormId: Map<String, String?>.from(
        json['varietySelectedFormId'] ?? {},
      ),
      varietyPriceLock:
          Map<String, bool>.from(json['varietyPriceLock'] ?? {}),
      varietyRecurrence: Map<String, String?>.from(
        json['varietyRecurrence'] ?? {},
      ),
    );
  }
}

// ─── DateDemandData ───────────────────────────────────────────────────────────

class DateDemandData {
  final double totalDemand;
  final double totalFulfilled;
  final List<Map<String, dynamic>> varietyBreakdown;

  DateDemandData({
    required this.totalDemand,
    required this.totalFulfilled,
    required this.varietyBreakdown,
  });

  Map<String, dynamic> toJson() => {
    'totalDemand': totalDemand,
    'totalFulfilled': totalFulfilled,
    'varietyBreakdown': varietyBreakdown,
  };

  factory DateDemandData.fromJson(Map<String, dynamic> json) => DateDemandData(
    totalDemand: (json['totalDemand'] as num).toDouble(),
    totalFulfilled: (json['totalFulfilled'] as num).toDouble(),
    varietyBreakdown:
        List<Map<String, dynamic>>.from(json['varietyBreakdown'] ?? []),
  );
}
