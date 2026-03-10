import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a farmer's in-progress pledge form keyed by order_id.
///
/// Key strategy: `pledge_draft_<orderId>`
///
/// Data stored per order:
///   covgId → { selectedVarieties: [varietyName|null], quantities: {varietyName|"__open__": qty} }
class PledgeDraftRepository {
  static const String _prefix = 'pledge_draft_';

  static String _key(String orderId) => '$_prefix$orderId';

  // ── Save ──────────────────────────────────────────────────────────────────

  static Future<void> saveDraft(String orderId, PledgeDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(orderId), jsonEncode(draft.toJson()));
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  static Future<PledgeDraft?> getDraft(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(orderId));
    if (raw == null) return null;
    try {
      return PledgeDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  static Future<void> clearDraft(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(orderId));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

// ─── Domain models ────────────────────────────────────────────────────────────

/// Top-level draft for one order.
class PledgeDraft {
  /// covg_id → per-group draft data
  final Map<String, PledgeGroupDraft> groups;

  PledgeDraft({required this.groups});

  Map<String, dynamic> toJson() => {
        'groups': groups.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory PledgeDraft.fromJson(Map<String, dynamic> json) {
    final raw = json['groups'] as Map<String, dynamic>? ?? {};
    return PledgeDraft(
      groups: raw.map(
        (k, v) => MapEntry(k, PledgeGroupDraft.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  /// Returns a copy with the given group draft updated / inserted.
  PledgeDraft withGroup(String covgId, PledgeGroupDraft groupDraft) {
    return PledgeDraft(groups: {...groups, covgId: groupDraft});
  }
}

/// Draft state for one variety-group (one delivery date).
class PledgeGroupDraft {
  /// variety name (or "__open__" when no specific variety) → qty entered
  final Map<String, double> quantities;

  /// variety names that the farmer has checked
  final Set<String> selectedVarieties;

  PledgeGroupDraft({
    required this.quantities,
    required this.selectedVarieties,
  });

  static const String openVarietyKey = '__open__';

  Map<String, dynamic> toJson() => {
        'quantities': quantities.map((k, v) => MapEntry(k, v)),
        'selectedVarieties': selectedVarieties.toList(),
      };

  factory PledgeGroupDraft.fromJson(Map<String, dynamic> json) {
    return PledgeGroupDraft(
      quantities: Map<String, double>.from(
        (json['quantities'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      ),
      selectedVarieties: Set<String>.from(
        json['selectedVarieties'] as List<dynamic>? ?? [],
      ),
    );
  }
}
