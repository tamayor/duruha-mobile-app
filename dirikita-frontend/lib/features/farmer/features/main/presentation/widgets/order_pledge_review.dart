import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_button.dart';
import 'package:duruha/features/farmer/features/main/data/pledge_draft_repository.dart';
import 'package:duruha/features/farmer/features/main/domain/find_orders_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Read-only summary of the farmer's pledge selections.
/// Shown after tapping "Confirm Pledge" in the form sheet.
/// Back button returns to the form sheet.
class OrderPledgeReview extends StatelessWidget {
  final FindOrderItem order;
  final List<VarietyGroup> selectedGroups;

  /// Snapshot of qty (covgId → varKey → qty string) — read-only
  final Map<String, Map<String, String>> qtys;

  /// Snapshot of selected varieties (covgId → varKey → isSelected)
  final Map<String, Map<String, bool>> varietySelected;

  final VoidCallback onBack;
  final void Function(String orderId, List<Map<String, dynamic>> pledges)
  onSubmit;

  const OrderPledgeReview({
    super.key,
    required this.order,
    required this.selectedGroups,
    required this.qtys,
    required this.varietySelected,
    required this.onBack,
    required this.onSubmit,
  });

  void _handleSubmit(BuildContext context) {
    final List<Map<String, dynamic>> pledges = [];

    for (final g in selectedGroups) {
      final selMap = varietySelected[g.covgId] ?? {};
      final qMap = qtys[g.covgId] ?? {};
      final List<Map<String, dynamic>> varieties = [];

      for (final entry in qMap.entries) {
        if (selMap[entry.key] == true) {
          final qty = double.tryParse(entry.value) ?? 0;
          if (qty <= 0) continue;

          final variety = g.varieties.firstWhere(
            (v) =>
                (v.varietyName ?? PledgeGroupDraft.openVarietyKey) == entry.key,
            orElse: () => VarietyOption(),
          );

          varieties.add({'cov_id': variety.covId, 'quantity': qty});
        }
      }

      if (varieties.isNotEmpty) {
        pledges.add({
          'covg_id': g.covgId,
          'date_needed': g.dateNeeded.toIso8601String().split('T')[0],
          'varieties': varieties,
        });
      }
    }

    HapticFeedback.mediumImpact();
    onSubmit(order.orderId, pledges);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    double grandTotal = 0;
    double grandEarnings = 0;
    for (final g in selectedGroups) {
      final selMap = varietySelected[g.covgId] ?? {};
      final qMap = qtys[g.covgId] ?? {};
      for (final entry in qMap.entries) {
        if (selMap[entry.key] == true) {
          final qty = double.tryParse(entry.value) ?? 0;
          grandTotal += qty;
          if (entry.key != PledgeGroupDraft.openVarietyKey) {
            final price = g.varieties
                .where((v) => v.varietyName == entry.key)
                .firstOrNull
                ?.ftdPrice;
            if (price != null) grandEarnings += qty * price;
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Back + header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                tooltip: 'Back to edit',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.produceLocalName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Review your pledge',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Grand total badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_fmtQty(grandTotal)} kg total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        Divider(color: cs.outline.withValues(alpha: 0.15), height: 20),

        // ── Per-group summary cards ────────────────────────────────────────
        ...selectedGroups.map((g) {
          final selMap = varietySelected[g.covgId] ?? {};
          final qMap = qtys[g.covgId] ?? {};
          double groupEarnings = 0;
          for (final entry in qMap.entries) {
            if (selMap[entry.key] == true &&
                entry.key != PledgeGroupDraft.openVarietyKey) {
              final price = g.varieties
                  .where((v) => v.varietyName == entry.key)
                  .firstOrNull
                  ?.ftdPrice;
              if (price != null) {
                groupEarnings += (double.tryParse(entry.value) ?? 0) * price;
              }
            }
          }
          return _ReviewGroupCard(
            group: g,
            qtys: qMap,
            varietySelected: selMap,
            estimatedEarnings: groupEarnings,
            cs: cs,
            theme: theme,
          );
        }),

        const SizedBox(height: 20),

        // ── Grand total row ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.summarize_rounded,
                          size: 16,
                          color: cs.onSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${selectedGroups.length} date${selectedGroups.length > 1 ? 's' : ''} pledged',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_fmtQty(grandTotal)} kg',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
                if (grandEarnings > 0) ...[
                  Divider(
                    height: 16,
                    thickness: 0.5,
                    color: cs.outline.withValues(alpha: 0.2),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 16,
                            color: cs.onSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Est. total earnings',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        DuruhaFormatter.formatCurrency(grandEarnings),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Submit button ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DuruhaButton(
            text: 'Submit Pledge',
            onPressed: () => _handleSubmit(context),
            icon: const Icon(Icons.handshake_rounded),
          ),
        ),

        const SizedBox(height: 8),

        // ── Back to edit ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DuruhaButton(
            text: 'Edit Pledge',
            onPressed: onBack,
            icon: const Icon(Icons.edit_rounded),
            isOutline: true,
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  static String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-group summary card
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewGroupCard extends StatelessWidget {
  final VarietyGroup group;
  final Map<String, String> qtys;
  final Map<String, bool> varietySelected;
  final double estimatedEarnings;
  final ColorScheme cs;
  final ThemeData theme;

  const _ReviewGroupCard({
    required this.group,
    required this.qtys,
    required this.varietySelected,
    required this.estimatedEarnings,
    required this.cs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d yyyy').format(group.dateNeeded);
    final selectedEntries = qtys.entries
        .where((e) => varietySelected[e.key] == true)
        .toList();
    final groupTotal = selectedEntries.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse(e.value) ?? 0),
    );
    final fillRatio = (groupTotal / group.quantity).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date header ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Variety rows ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: selectedEntries.asMap().entries.map((e) {
                  final idx = e.key;
                  final varKey = e.value.key;
                  final qtyStr = e.value.value;
                  final qty = double.tryParse(qtyStr) ?? 0;
                  final label = varKey == PledgeGroupDraft.openVarietyKey
                      ? 'Any variety'
                      : varKey;
                  final isLast = idx == selectedEntries.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontStyle:
                                      varKey == PledgeGroupDraft.openVarietyKey
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                            Text(
                              '${_fmtQty(qty)} kg',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: cs.outline.withValues(alpha: 0.1),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),

            // ── Progress bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fillRatio,
                      minHeight: 5,
                      backgroundColor: cs.outline.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (estimatedEarnings > 0)
                        Text(
                          DuruhaFormatter.formatCurrency(estimatedEarnings),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Text(
                        '${_fmtQty(groupTotal)} / ${group.quantity.toInt()} kg',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }
}
