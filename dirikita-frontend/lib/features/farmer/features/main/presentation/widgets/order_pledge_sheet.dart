import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_button.dart';
import 'package:duruha/core/widgets/duruha_snackbar.dart';
import 'package:duruha/features/farmer/features/main/data/pledge_draft_repository.dart';
import 'package:duruha/features/farmer/features/main/domain/find_orders_model.dart';
import 'package:duruha/features/farmer/features/main/presentation/widgets/order_pledge_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Bottom-sheet content shown when a farmer taps the "Pledge" button.
///
/// Rules
/// ─────
/// • Farmer must select 1–2 varieties per group.
/// • Total qty pledged per group must not exceed group.quantity.
/// • "Apply to all" copies a group's qty to all other selected groups.
class OrderPledgeSheet extends StatefulWidget {
  final FindOrderItem order;
  final List<VarietyGroup> selectedGroups;

  /// Shared controllers from the card (covgId → varKey → controller)
  final Map<String, Map<String, TextEditingController>> controllers;

  /// Shared selected-state from the card (covgId → varKey → bool)
  final Map<String, Map<String, bool>> varietySelected;

  final VoidCallback onChanged;
  final void Function(String orderId, List<Map<String, dynamic>> pledges)
  onConfirmed;

  const OrderPledgeSheet({
    super.key,
    required this.order,
    required this.selectedGroups,
    required this.controllers,
    required this.varietySelected,
    required this.onChanged,
    required this.onConfirmed,
  });

  @override
  State<OrderPledgeSheet> createState() => _OrderPledgeSheetState();
}

class _OrderPledgeSheetState extends State<OrderPledgeSheet> {
  bool _showingReview = false;

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Total qty entered across selected varieties of a group.
  double _groupTotalSelected(VarietyGroup g) {
    final selMap = widget.varietySelected[g.covgId]!;
    final ctrlMap = widget.controllers[g.covgId]!;
    double total = 0;
    for (final entry in ctrlMap.entries) {
      if (selMap[entry.key] == true) {
        total += double.tryParse(entry.value.text.trim()) ?? 0;
      }
    }
    return total;
  }

  /// Group is valid when:
  ///   1. 1–2 varieties are selected
  ///   2. Total qty ≥ 50% of group.quantity
  ///   3. Total qty ≤ group.quantity
  bool _groupValid(VarietyGroup g) {
    final selMap = widget.varietySelected[g.covgId]!;
    final selectedCount = selMap.values.where((v) => v).length;
    if (selectedCount < 1 || selectedCount > 2) return false;
    final total = _groupTotalSelected(g);
    final minQty = g.quantity * 0.5;
    return total >= minQty && total <= g.quantity;
  }

  bool get _canContinue => widget.selectedGroups.every((g) => _groupValid(g));

  String? _groupBlockingReason(VarietyGroup g) {
    final selMap = widget.varietySelected[g.covgId]!;
    final selectedCount = selMap.values.where((v) => v).length;
    if (selectedCount < 1) return 'Select 1 or 2 varieties';
    if (selectedCount > 2) return 'Select at most 2 varieties';
    final total = _groupTotalSelected(g);
    final minQty = g.quantity * 0.5;
    if (total < minQty) {
      return 'Min pledge is ${minQty % 1 == 0 ? minQty.toInt() : minQty.toStringAsFixed(1)} kg (50% of ${g.quantity.toInt()} kg)';
    }
    if (total > g.quantity) {
      return 'Total qty ${total.toStringAsFixed(1)} kg exceeds max ${g.quantity.toInt()} kg';
    }
    return null;
  }

  // ── Variety toggle (max-2 guard) ───────────────────────────────────────────

  void _onToggleVariety(String covgId, String varKey, bool newVal) {
    final selMap = widget.varietySelected[covgId]!;
    final currentCount = selMap.values.where((v) => v).length;
    if (newVal && currentCount >= 2) {
      if (mounted) {
        DuruhaSnackBar.showWarning(
          context,
          'You can select at most 2 varieties per date.',
          title: 'Max 2 varieties',
        );
      }
      return;
    }
    selMap[varKey] = newVal;
    setState(() {});
    widget.onChanged();
  }

  // ── Apply-to-all ──────────────────────────────────────────────────────────

  /// Copy the qty + variety selection from [sourceGroup] to all other groups.
  /// Only copies varieties that exist by the same key in the target group.
  void _applyToAllGroups(VarietyGroup sourceGroup) {
    final srcCtrl = widget.controllers[sourceGroup.covgId]!;
    final srcSel = widget.varietySelected[sourceGroup.covgId]!;

    for (final g in widget.selectedGroups) {
      if (g.covgId == sourceGroup.covgId) continue;
      final tgtCtrl = widget.controllers[g.covgId]!;
      final tgtSel = widget.varietySelected[g.covgId]!;

      for (final key in tgtCtrl.keys) {
        final srcQty = srcCtrl[key]?.text ?? '';
        final srcIsSelected = srcSel[key] ?? false;

        // Check max-2 constraint before applying
        final currentlySelected = tgtSel.values.where((v) => v).length;
        if (srcIsSelected && !(tgtSel[key] ?? false)) {
          if (currentlySelected >= 2) continue; // skip; would exceed max
        }

        tgtCtrl[key]?.text = srcQty;
        tgtSel[key] = srcIsSelected;
      }
    }

    setState(() {});
    widget.onChanged();
  }

  // ── Snapshot for review ────────────────────────────────────────────────────

  /// Build a qty snapshot (covgId → varKey → text) from current controllers.
  Map<String, Map<String, String>> _buildQtySnapshot() {
    return {
      for (final g in widget.selectedGroups)
        g.covgId: {
          for (final e in widget.controllers[g.covgId]!.entries)
            e.key: e.value.text,
        },
    };
  }

  /// Deep-copy of varietySelected for the review (so edits don't mutate it).
  Map<String, Map<String, bool>> _buildSelSnapshot() {
    return {
      for (final g in widget.selectedGroups)
        g.covgId: Map.of(widget.varietySelected[g.covgId]!),
    };
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_showingReview) {
      return OrderPledgeReview(
        order: widget.order,
        selectedGroups: widget.selectedGroups,
        qtys: _buildQtySnapshot(),
        varietySelected: _buildSelSnapshot(),
        onBack: () => setState(() => _showingReview = false),
        onSubmit: widget.onConfirmed,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrderSummaryHeader(order: widget.order, cs: cs, theme: theme),
        const SizedBox(height: 4),
        Divider(color: cs.outline.withValues(alpha: 0.15)),
        const SizedBox(height: 8),

        ...widget.selectedGroups.map(
          (g) => _GroupPledgeBlock(
            group: g,
            controllers: widget.controllers[g.covgId]!,
            varietySelected: widget.varietySelected[g.covgId]!,
            blockingReason: _groupBlockingReason(g),
            groupTotal: _groupTotalSelected(g),
            showApplyToAll: widget.selectedGroups.length > 1,
            cs: cs,
            theme: theme,
            onChanged: () {
              setState(() {});
              widget.onChanged();
            },
            onToggleVariety: (varKey, newVal) =>
                _onToggleVariety(g.covgId, varKey, newVal),
            onApplyToAll: () => _applyToAllGroups(g),
          ),
        ),

        const SizedBox(height: 16),

        if (!_canContinue)
          _ValidationBanner(
            reason: widget.selectedGroups
                .map((g) => _groupBlockingReason(g))
                .firstWhere((r) => r != null, orElse: () => null),
            cs: cs,
            theme: theme,
          ),

        const SizedBox(height: 12),

        DuruhaButton(
          text: 'Review Pledge',
          onPressed: _canContinue
              ? () {
                  HapticFeedback.mediumImpact();
                  setState(() => _showingReview = true);
                }
              : null,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order summary header
// ─────────────────────────────────────────────────────────────────────────────

class _OrderSummaryHeader extends StatelessWidget {
  final FindOrderItem order;
  final ColorScheme cs;
  final ThemeData theme;

  const _OrderSummaryHeader({
    required this.order,
    required this.cs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              order.produceEnglishName.isNotEmpty
                  ? order.produceEnglishName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.produceEnglishName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (order.produceForm != null)
                  Text(
                    order.produceForm!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One group's pledge block
// ─────────────────────────────────────────────────────────────────────────────

class _GroupPledgeBlock extends StatelessWidget {
  final VarietyGroup group;
  final Map<String, TextEditingController> controllers;
  final Map<String, bool> varietySelected;
  final String? blockingReason;
  final double groupTotal;
  final bool showApplyToAll;
  final ColorScheme cs;
  final ThemeData theme;
  final VoidCallback onChanged;

  /// Called when a variety checkbox is toggled. Caller enforces max-2.
  final void Function(String varKey, bool newVal) onToggleVariety;

  /// Called to apply this group's qty to all other selected groups.
  final VoidCallback onApplyToAll;

  const _GroupPledgeBlock({
    required this.group,
    required this.controllers,
    required this.varietySelected,
    required this.blockingReason,
    required this.groupTotal,
    required this.showApplyToAll,
    required this.cs,
    required this.theme,
    required this.onChanged,
    required this.onToggleVariety,
    required this.onApplyToAll,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d yyyy').format(group.dateNeeded);
    final qtyStr = group.quantity == group.quantity.truncateToDouble()
        ? '${group.quantity.toInt()} kg'
        : '${group.quantity.toStringAsFixed(1)} kg';
    final isValid = blockingReason == null;
    final selectedCount = varietySelected.values.where((v) => v).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isValid
                ? cs.onPrimaryContainer.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: 0.2),
            width: isValid ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Group header ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Need $qtyStr',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Criteria hint ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Select 1–2 varieties · ${(group.quantity * 0.5) % 1 == 0 ? (group.quantity * 0.5).toInt() : (group.quantity * 0.5).toStringAsFixed(1)}–${group.quantity.toInt()} kg'
                      '${controllers.length > 1 ? ' ($selectedCount/${controllers.length} selected)' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Variety rows ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                children: controllers.keys.toList().asMap().entries.map((e) {
                  final idx = e.key;
                  final key = e.value;
                  final isLast = idx == controllers.length - 1;
                  final variety = group.varieties.isNotEmpty
                      ? group.varieties.firstWhere(
                          (v) =>
                              (v.varietyName ??
                                  PledgeGroupDraft.openVarietyKey) ==
                              key,
                          orElse: () => VarietyOption(),
                        )
                      : VarietyOption();

                  return _SheetVarietyRow(
                    key: ValueKey('${group.covgId}_$key'),
                    varKey: key,
                    varietyName: key == PledgeGroupDraft.openVarietyKey
                        ? null
                        : key,
                    ftdPrice: variety.ftdPrice,
                    group: group,
                    controller: controllers[key]!,
                    isSelected: varietySelected[key] ?? false,
                    groupTotal: groupTotal,
                    isLast: isLast,
                    cs: cs,
                    theme: theme,
                    onToggle: (val) => onToggleVariety(key, val),
                    onQtyChanged: onChanged,
                  );
                }).toList(),
              ),
            ),

            // ── Progress bar ─────────────────────────────────────────
            if (groupTotal > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (groupTotal / group.quantity).clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: cs.outline.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          groupTotal > group.quantity
                              ? cs.error
                              : cs.onSecondary.withValues(alpha: .5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (showApplyToAll && isValid)
                          GestureDetector(
                            onTap: onApplyToAll,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_all_rounded,
                                  size: 12,
                                  color: cs.onPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Apply to all dates',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Text(
                          '${groupTotal.toStringAsFixed(1)} / ${group.quantity.toInt()} kg pledged',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: groupTotal > group.quantity
                                ? cs.error
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Blocking reason banner ───────────────────────────────
            if (blockingReason != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(13),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: cs.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        blockingReason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Variety row inside the pledge sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SheetVarietyRow extends StatefulWidget {
  final String varKey;
  final String? varietyName;
  final double? ftdPrice;
  final VarietyGroup group;
  final TextEditingController controller;
  final bool isSelected;
  final double groupTotal;
  final bool isLast;
  final ColorScheme cs;
  final ThemeData theme;
  final void Function(bool) onToggle;
  final VoidCallback onQtyChanged;

  const _SheetVarietyRow({
    super.key,
    required this.varKey,
    required this.varietyName,
    required this.ftdPrice,
    required this.group,
    required this.controller,
    required this.isSelected,
    required this.groupTotal,
    required this.isLast,
    required this.cs,
    required this.theme,
    required this.onToggle,
    required this.onQtyChanged,
  });

  @override
  State<_SheetVarietyRow> createState() => _SheetVarietyRowState();
}

class _SheetVarietyRowState extends State<_SheetVarietyRow> {
  static const List<double> _percentOptions = [0.50, 0.75, 1.00];

  double get _myQty => double.tryParse(widget.controller.text.trim()) ?? 0;

  double? get _selectedPercent {
    final qty = _myQty;
    if (qty == 0) return null;
    for (final pct in _percentOptions) {
      if ((qty - widget.group.quantity * pct).abs() < 0.01) return pct;
    }
    return null;
  }

  void _selectPercent(double pct) {
    final qty = widget.group.quantity * pct;
    final text = qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
    widget.onQtyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.varKey == PledgeGroupDraft.openVarietyKey
        ? 'Any variety'
        : (widget.varietyName ?? widget.varKey);
    final cs = widget.cs;
    final theme = widget.theme;
    final selected = _selectedPercent;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => widget.onToggle(!widget.isSelected),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? cs.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.isSelected
                              ? cs.primary
                              : cs.outline.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: widget.isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: cs.onPrimary,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: widget.isSelected
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                            fontStyle:
                                widget.varKey == PledgeGroupDraft.openVarietyKey
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        if (widget.isSelected && widget.ftdPrice != null)
                          Text(
                            DuruhaFormatter.formatCurrency(widget.ftdPrice!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: cs.onTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.isSelected) ...[
                const SizedBox(height: 8),
                Row(
                  children: _percentOptions.map((pct) {
                    final isActive = selected == pct;
                    final qty = widget.group.quantity * pct;
                    final qtyStr = qty == qty.truncateToDouble()
                        ? '${qty.toInt()} kg'
                        : '${qty.toStringAsFixed(1)} kg';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => _selectPercent(pct),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? cs.primary
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.5,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive
                                    ? cs.primary
                                    : cs.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${(pct * 100).toInt()}%',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? cs.onPrimary
                                        : cs.onSurface,
                                  ),
                                ),
                                Text(
                                  qtyStr,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: isActive
                                        ? cs.onPrimary.withValues(alpha: 0.8)
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        if (!widget.isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outline.withValues(alpha: 0.1),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Validation banner
// ─────────────────────────────────────────────────────────────────────────────

class _ValidationBanner extends StatelessWidget {
  final String? reason;
  final ColorScheme cs;
  final ThemeData theme;

  const _ValidationBanner({
    required this.reason,
    required this.cs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: cs.error),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cannot confirm yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason ??
                        'Select 1–2 varieties and pledge at least 50% of the required quantity for each group.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onErrorContainer.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
