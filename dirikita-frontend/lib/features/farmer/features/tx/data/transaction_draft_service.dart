import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/domain/pledge_model.dart';

class TransactionDraftService {
  static const String _draftPrefix = 'tx_draft_';

  /// Saves the draft data for a specific crop.
  static Future<void> saveDraft(String cropId, CropDraftData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_draftPrefix$cropId', jsonEncode(data.toJson()));
  }

  /// Retrieves the draft data for a specific crop.
  static Future<CropDraftData?> getDraft(String cropId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_draftPrefix$cropId');
    if (jsonStr != null) {
      try {
        return CropDraftData.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        // If data is corrupted or schema changed, return null
        return null;
      }
    }
    return null;
  }

  /// Clears the draft for a specific crop.
  static Future<void> clearDraft(String cropId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_draftPrefix$cropId');
  }

  /// Clears all transaction drafts.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_draftPrefix));
    for (var key in keys) {
      await prefs.remove(key);
    }
  }
}

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

  CropDraftData({
    this.selectedHarvestDates = const [],
    this.availableDate,
    this.disposalDate,
    required this.selectedUnit,
    this.varietyQuantities = const {},
    this.simulatedDemand,
    this.perDatePledges = const [],
    this.dateSpecificDemand = const {},
    this.varietyAvailableDates = const {},
    this.varietyDisposalDates = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'selectedHarvestDates': selectedHarvestDates
          .map((e) => e.toIso8601String())
          .toList(),
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
    };
  }

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
      selectedHarvestDates: json['selectedHarvestDates'] != null
          ? (json['selectedHarvestDates'] as List)
                .map((e) => DateTime.parse(e))
                .toList()
          : [],
      availableDate: json['availableDate'] != null
          ? DateTime.parse(json['availableDate'])
          : null,
      disposalDate: json['disposalDate'] != null
          ? DateTime.parse(json['disposalDate'])
          : null,
      selectedUnit: json['selectedUnit'] ?? 'kg',
      varietyQuantities: Map<String, double>.from(
        json['varietyQuantities'] ?? {},
      ),
      simulatedDemand: json['simulatedDemand'] != null
          ? List<Map<String, dynamic>>.from(json['simulatedDemand'])
          : null,
      perDatePledges: parsedPledges,
      dateSpecificDemand: json['dateSpecificDemand'] != null
          ? (json['dateSpecificDemand'] as Map<String, dynamic>).map((
              key,
              value,
            ) {
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
                DateDemandData.fromJson(value),
              );
            })
          : {},
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
    );
  }
}

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

  factory DateDemandData.fromJson(Map<String, dynamic> json) {
    return DateDemandData(
      totalDemand: (json['totalDemand'] as num).toDouble(),
      totalFulfilled: (json['totalFulfilled'] as num).toDouble(),
      varietyBreakdown: List<Map<String, dynamic>>.from(
        json['varietyBreakdown'] ?? [],
      ),
    );
  }
}

/// One offer entry: variety + produce form (listing) + quantity + dates.
/// This is the canonical data unit for the Offer transaction flow.
class OfferFormEntry {
  final String varietyName;
  final String listingId;
  final String produceForm;
  final double quantity;
  final double pricePerUnit;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final bool isPriceLock;
  final String? fplsId;
  final double? totalPriceLockCredit;

  const OfferFormEntry({
    required this.varietyName,
    required this.listingId,
    required this.produceForm,
    required this.quantity,
    required this.pricePerUnit,
    this.availableFrom,
    this.availableTo,
    this.isPriceLock = false,
    this.fplsId,
    this.totalPriceLockCredit,
  });

  bool get hasDate => availableFrom != null && availableTo != null;
  bool get isInfinite => availableTo != null && availableTo!.year > 2090;

  OfferFormEntry copyWith({
    String? varietyName,
    String? listingId,
    String? produceForm,
    double? quantity,
    double? pricePerUnit,
    DateTime? availableFrom,
    DateTime? availableTo,
    bool? isPriceLock,
    String? fplsId,
    double? totalPriceLockCredit,
  }) {
    return OfferFormEntry(
      varietyName: varietyName ?? this.varietyName,
      listingId: listingId ?? this.listingId,
      produceForm: produceForm ?? this.produceForm,
      quantity: quantity ?? this.quantity,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
      isPriceLock: isPriceLock ?? this.isPriceLock,
      fplsId: fplsId ?? this.fplsId,
      totalPriceLockCredit: totalPriceLockCredit ?? this.totalPriceLockCredit,
    );
  }
}
