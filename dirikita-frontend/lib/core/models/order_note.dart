import 'dart:convert';

// ─── ItemSpecialRequest ────────────────────────────────────────────────────────
// Represents a per-produce note attached to a specific key.
// Key convention: "produce-{produceIndex}" — one entry per produce item.
// All variety groups within that produce share the same note.

class ItemSpecialRequest {
  final String itemKey; // e.g. "produce-0-group-1"
  final String itemName; // human-readable label, e.g. "Tomato – Group 2"
  final String note;

  const ItemSpecialRequest({
    required this.itemKey,
    required this.itemName,
    required this.note,
  });

  Map<String, dynamic> toMap() => {
    'itemKey': itemKey,
    'itemName': itemName,
    'note': note,
  };

  factory ItemSpecialRequest.fromMap(Map<String, dynamic> map) =>
      ItemSpecialRequest(
        itemKey: map['itemKey'] as String? ?? '',
        itemName: map['itemName'] as String? ?? '',
        note: map['note'] as String? ?? '',
      );
}

// ─── OrderNote ─────────────────────────────────────────────────────────────────
// Serialises every free-text field on an order into a single JSON string stored
// in the `note` column.  Call [toNoteString] before inserting and
// [OrderNote.fromNoteString] when displaying existing orders.

class OrderNote {
  /// General delivery instructions (e.g. "Leave at the gate").
  final String deliveryInstructions;

  /// Allergy list – stored as CSV in the UI, parsed into individual strings.
  final List<String> allergies;

  /// Per-produce notes keyed by "produce-{pi}".
  final List<ItemSpecialRequest> specialRequests;

  /// Optional message to include if the order is a gift.
  final String? giftMessage;

  const OrderNote({
    this.deliveryInstructions = '',
    this.allergies = const [],
    this.specialRequests = const [],
    this.giftMessage,
  });

  // ── Serialisation ────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'deliveryInstructions': deliveryInstructions,
    'allergies': allergies,
    // Each ItemSpecialRequest is stored as a sub-map so the JSON is self-describing.
    'specialRequests': specialRequests.map((r) => r.toMap()).toList(),
    if (giftMessage != null && giftMessage!.isNotEmpty)
      'giftMessage': giftMessage,
  };

  /// Encodes this note to a JSON string ready for the `note` DB column.
  String toNoteString() => jsonEncode(toMap());

  // ── Deserialisation ──────────────────────────────────────────────────────────

  factory OrderNote.fromMap(Map<String, dynamic> map) => OrderNote(
    deliveryInstructions: map['deliveryInstructions'] as String? ?? '',
    allergies: List<String>.from(
      (map['allergies'] as List<dynamic>? ?? []).map((e) => e.toString()),
    ),
    specialRequests: List<ItemSpecialRequest>.from(
      (map['specialRequests'] as List<dynamic>? ?? []).map(
        (e) => ItemSpecialRequest.fromMap(Map<String, dynamic>.from(e as Map)),
      ),
    ),
    giftMessage: map['giftMessage'] as String?,
  );

  /// Decodes a JSON string from the `note` column back into an [OrderNote].
  /// Returns an empty [OrderNote] if [raw] is null, empty, or malformed.
  factory OrderNote.fromNoteString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const OrderNote();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return OrderNote.fromMap(decoded);
      }
      // Legacy: plain-text note stored before structured notes were introduced.
      return OrderNote(deliveryInstructions: raw);
    } catch (_) {
      return OrderNote(deliveryInstructions: raw);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Returns true when there is nothing meaningful in this note.
  bool get isEmpty =>
      deliveryInstructions.isEmpty &&
      allergies.isEmpty &&
      specialRequests.every((r) => r.note.isEmpty) &&
      (giftMessage == null || giftMessage!.isEmpty);
}
