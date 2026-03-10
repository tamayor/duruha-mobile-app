import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_bottom_sheet.dart';
import 'package:duruha/core/widgets/duruha_button.dart';
import 'package:duruha/core/widgets/duruha_inkwell.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/core/widgets/duruha_snackbar.dart';
import 'package:duruha/features/farmer/features/main/data/find_orders_repository.dart';
import 'package:duruha/features/farmer/features/main/data/pledge_draft_repository.dart';
import 'package:duruha/features/farmer/features/main/domain/find_orders_model.dart';
import 'package:duruha/features/farmer/features/main/presentation/widgets/order_pledge_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

enum OrderCompactLevel {
  /// Header only (produce info + date count summary)
  produce,

  /// Expanded (everything visible)
  full,
}

class OrderBoardCard extends StatefulWidget {
  final FindOrderItem order;
  final OrderCompactLevel level;
  final bool isFavourite;
  final bool isOpen;
  final VoidCallback? onToggle;

  const OrderBoardCard({
    super.key,
    required this.order,
    this.level = OrderCompactLevel.produce,
    this.isFavourite = false,
    this.isOpen = false,
    this.onToggle,
  });

  @override
  State<OrderBoardCard> createState() => _OrderBoardCardState();
}

class _OrderBoardCardState extends State<OrderBoardCard> {
  // ── Group selection ───────────────────────────────────────────────────────
  final Set<String> _selectedGroupIds = {};
  late final DragSelectGridViewController _dragController;

  // ── Pledge form state  (covgId → variety key → qty) ──────────────────────
  // Variety key = varietyName ?? PledgeGroupDraft.openVarietyKey
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  final Map<String, Map<String, bool>> _varietySelected = {};

  @override
  void initState() {
    super.initState();
    _dragController = DragSelectGridViewController();
    _dragController.addListener(_onDragSelectionChanged);
    _initControllers();
    _loadDraft();
  }

  void _onDragSelectionChanged() {
    final selection = _dragController.value;
    final groups = widget.order.varietyGroup;
    setState(() {
      _selectedGroupIds.clear();
      for (final index in selection.selectedIndexes) {
        if (index >= 0 && index < groups.length) {
          _selectedGroupIds.add(groups[index].covgId);
        }
      }
    });
  }

  void _initControllers() {
    for (final g in widget.order.varietyGroup) {
      final varKeys = g.varieties.isEmpty
          ? [PledgeGroupDraft.openVarietyKey]
          : g.varieties
                .map((v) => v.varietyName ?? PledgeGroupDraft.openVarietyKey)
                .toList();
      _controllers[g.covgId] = {
        for (final k in varKeys) k: TextEditingController(),
      };
      _varietySelected[g.covgId] = {for (final k in varKeys) k: false};
    }
  }

  Future<void> _loadDraft() async {
    final draft = await PledgeDraftRepository.getDraft(widget.order.copId);
    if (draft == null || !mounted) return;
    setState(() {
      final groups = widget.order.varietyGroup;
      final selectedIndices = <int>{};
      for (final g in groups) {
        final gDraft = draft.groups[g.covgId];
        if (gDraft == null) continue;

        final varMap = _controllers[g.covgId]!;
        final selMap = _varietySelected[g.covgId]!;
        bool hasVarSelected = false;

        for (final key in varMap.keys) {
          final qty = gDraft.quantities[key];
          if (qty != null) varMap[key]!.text = _fmtQty(qty);
          final isSelected = gDraft.selectedVarieties.contains(key);
          selMap[key] = isSelected;
          if (isSelected) hasVarSelected = true;
        }

        if (hasVarSelected) {
          _selectedGroupIds.add(g.covgId);
          selectedIndices.add(groups.indexOf(g));
        }
      }

      _dragController.removeListener(_onDragSelectionChanged);
      _dragController.value = Selection(selectedIndices);
      _dragController.addListener(_onDragSelectionChanged);
    });
  }

  Future<void> _persistDraft() async {
    final groups = <String, PledgeGroupDraft>{};
    for (final g in widget.order.varietyGroup) {
      final varMap = _controllers[g.covgId]!;
      final selMap = _varietySelected[g.covgId]!;
      final qtys = <String, double>{};
      final selected = <String>{};
      for (final entry in varMap.entries) {
        final qty = double.tryParse(entry.value.text.trim()) ?? 0;
        if (qty > 0) qtys[entry.key] = qty;
        if (selMap[entry.key] == true) selected.add(entry.key);
      }
      groups[g.covgId] = PledgeGroupDraft(
        quantities: qtys,
        selectedVarieties: selected,
      );
    }
    await PledgeDraftRepository.saveDraft(
      widget.order.copId,
      PledgeDraft(groups: groups),
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    for (final m in _controllers.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _toggleGroup(String covgId) {
    HapticFeedback.selectionClick();
    final groups = widget.order.varietyGroup;
    final index = groups.indexWhere((g) => g.covgId == covgId);
    if (index == -1) return;

    final currentSelection = _dragController.value.selectedIndexes;
    final newSelection = Set<int>.from(currentSelection);

    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
    }

    _dragController.value = Selection(newSelection);
  }

  void _selectAllGroups() {
    HapticFeedback.heavyImpact();
    final count = widget.order.varietyGroup.length;
    _dragController.value = Selection({for (int i = 0; i < count; i++) i});
  }

  void _clearAllGroups() {
    HapticFeedback.lightImpact();
    _dragController.value = Selection.empty();
  }

  List<VarietyGroup> get _selectedGroups => widget.order.varietyGroup
      .where((g) => _selectedGroupIds.contains(g.covgId))
      .toList();

  // ── 50 % group-selection check ────────────────────────────────────────────
  bool get _hasEnoughGroupsSelected {
    final total = widget.order.varietyGroup.length;
    if (total == 0) return false;
    final needed = (total / 2).ceil();
    return _selectedGroupIds.length >= needed;
  }

  void _onPledgeTapped() {
    if (!_hasEnoughGroupsSelected) {
      final total = widget.order.varietyGroup.length;
      final needed = (total / 2).ceil();
      DuruhaSnackBar.showWarning(
        context,
        'Select at least $needed of $total delivery date${needed > 1 ? 's' : ''} to pledge.',
        title: 'Select dates first',
      );
      return;
    }
    HapticFeedback.mediumImpact();
    _openPledgeSheet();
  }

  void _openPledgeSheet() {
    DuruhaBottomSheet.show(
      context: context,
      title: widget.order.produceLocalName,
      subtitle: 'Review & confirm your pledge',
      icon: Icons.handshake_rounded,
      heightFactor: 0.95,
      child: OrderPledgeSheet(
        order: widget.order,
        selectedGroups: _selectedGroups,
        controllers: _controllers,
        varietySelected: _varietySelected,
        onChanged: () {
          setState(() {});
          _persistDraft();
        },
        onConfirmed: (orderId, pledges) async {
          final success = await FindOrdersRepository().submitPledges(
            orderId: orderId,
            pledges: pledges,
          );
          if (!success) {
            if (mounted) {
              DuruhaSnackBar.showError(
                context,
                'Failed to submit pledge. Please try again.',
                title: 'Submission Error',
              );
            }
            return;
          }

          if (mounted) {
            setState(() => _selectedGroupIds.clear());
            PledgeDraftRepository.clearDraft(widget.order.copId);
            Navigator.pop(context);

            DuruhaSnackBar.showSuccess(
              context,
              'Your pledge has been submitted successfully.',
              title: 'Pledge Submitted',
            );
          }
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final order = widget.order;
    final earliest = order.earliestDateNeeded;
    final daysUntil = earliest?.difference(DateTime.now()).inDays;
    final hasSelection = _selectedGroupIds.isNotEmpty;

    return SliverMainAxisGroup(
      slivers: [
        DuruhaSliverSectionContainer(
          isShrinkable: true,
          shrinkOverride: !widget.isOpen,
          customHeaderHeight: 86,
          customHeader: (toggle, isShrunk) => DuruhaInkwell(
            onTap: widget.onToggle ?? toggle,
            variation: InkwellVariation.subtle,
            padding: const EdgeInsets.all(16),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _ProduceAvatar(
                      name: order.produceLocalName,
                      imageUrl: order.produceImageUrl,
                      isFavourite: order.isFavouriteProduce,
                      hasSelection: hasSelection,
                      selectionCount: _selectedGroupIds.length,
                      cs: cs,
                    ),
                    if (order.isFavouriteProduce)
                      Positioned(
                        top: -5,
                        left: -5,
                        child: Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: cs.onTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  order.produceLocalName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '@order_${order.orderId.substring(0, 8).toUpperCase()}…',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                if (order.produceForm != null)
                                  Flexible(
                                    child: _Chip(
                                      label: order.produceForm!,
                                      color: cs.secondaryContainer,
                                      textColor: cs.onSecondaryContainer,
                                    ),
                                  ),
                                const SizedBox(width: 5),
                                if (isShrunk && order.varietyGroup.isNotEmpty)
                                  _Chip(
                                    icon: Icons.calendar_today_rounded,
                                    label: order.varietyGroup.length.toString(),
                                    color: cs.primaryContainer,
                                    textColor: cs.onPrimaryContainer,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              if (daysUntil != null)
                                _UrgencyBadge(daysUntil: daysUntil, cs: cs),
                              const SizedBox(width: 6),
                              Text(
                                '${_fmtQty(order.totalQuantity)} kg',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: [_buildBody(cs, theme, hasSelection)],
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }

  Widget _buildBody(ColorScheme cs, ThemeData theme, bool hasSelection) {
    final order = widget.order;

    return Column(
      children: [
        if (order.uniqueVarieties.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 6,
            runSpacing: 6,
            children: order.uniqueVarieties
                .map(
                  (v) => _Chip(
                    label: v,
                    color: cs.primaryContainer,
                    textColor: cs.onPrimaryContainer,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          spacing: 6,
          children: [
            if (order.quality != null)
              _Chip(
                label: order.quality!,
                icon: Icons.workspace_premium_rounded,
                color: cs.tertiaryContainer,
                textColor: cs.onTertiaryContainer,
              ),
            if (order.distanceKm != null)
              _Chip(
                icon: Icons.near_me_rounded,
                label: '${order.distanceKm!.toStringAsFixed(1)} km',
                color: cs.surface,
                textColor: cs.onSurface,
              ),
            if (order.consumerLocation != null)
              _Chip(
                icon: Icons.location_on_rounded,
                label: order.consumerLocation!.displayAddress,
                color: cs.secondaryContainer,
                textColor: cs.onSecondaryContainer,
              ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.note != null && order.note!.isNotEmpty) ...[
                _NoteBlock(note: order.note!, cs: cs, theme: theme),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select dates to pledge (${order.varietyGroup.length} available)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (order.varietyGroup.length > 1) ...[
                    if (_selectedGroupIds.length < order.varietyGroup.length)
                      TextButton.icon(
                        onPressed: _selectAllGroups,
                        icon: const Icon(Icons.done_all_rounded, size: 14),
                        label: const Text('All'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: cs.onPrimary,
                          textStyle: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: _clearAllGroups,
                        icon: const Icon(Icons.close_rounded, size: 14),
                        label: const Text('None'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: cs.onSurfaceVariant,
                          textStyle: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ],
              ),

              // Selectable variety-group cards unit DragSelectGridView
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: order.varietyGroup.length > 4
                      ? 400
                      : double.infinity,
                ),
                child: DragSelectGridView(
                  gridController: _dragController,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisExtent: 72,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: order.varietyGroup.length,
                  itemBuilder: (context, index, isSelected) {
                    final group = order.varietyGroup[index];
                    return _SelectableVarietyGroupBlock(
                      group: group,
                      isSelected: isSelected,
                      cs: cs,
                      theme: theme,
                      onTap: () => _toggleGroup(group.covgId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ── PLEDGE BUTTON ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DuruhaButton(
            text: hasSelection
                ? 'Pledge — ${_selectedGroupIds.length} date${_selectedGroupIds.length > 1 ? 's' : ''}'
                : 'Select dates to pledge',
            onPressed: _onPledgeTapped,
            icon: Icon(
              hasSelection
                  ? Icons.arrow_forward_rounded
                  : Icons.handshake_rounded,
              color: hasSelection ? cs.onPrimary : cs.onSurfaceVariant,
              size: 20,
            ),
            backgroundColor: hasSelection
                ? cs.primary
                : cs.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selectable Variety Group Block
// ─────────────────────────────────────────────────────────────────────────────

class _SelectableVarietyGroupBlock extends StatelessWidget {
  final VarietyGroup group;
  final bool isSelected;
  final ColorScheme cs;
  final ThemeData theme;
  final VoidCallback onTap;

  const _SelectableVarietyGroupBlock({
    required this.group,
    required this.isSelected,
    required this.cs,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayStr = DateFormat('E').format(group.dateNeeded);
    final dateStr = DuruhaFormatter.formatDate(group.dateNeeded);
    final qtyStr = group.quantity == group.quantity.truncateToDouble()
        ? '${group.quantity.toInt()}kg'
        : '${group.quantity.toStringAsFixed(1)}kg';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withValues(alpha: 0.02) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? cs.onPrimary.withValues(alpha: 0.6)
                : cs.outline.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.25)
                : cs.surfaceContainerLow.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayStr,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
              Text(
                dateStr,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                qtyStr,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Produce Avatar with selection badge
// ─────────────────────────────────────────────────────────────────────────────

class _ProduceAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isFavourite;
  final bool hasSelection;
  final int selectionCount;
  final ColorScheme cs;

  const _ProduceAvatar({
    required this.name,
    this.imageUrl,
    required this.isFavourite,
    required this.hasSelection,
    required this.selectionCount,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: (hasSelection || isFavourite)
                ? cs.primaryContainer
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: (hasSelection || isFavourite)
                ? Border.all(color: cs.primary.withValues(alpha: 0.4))
                : null,
          ),
          alignment: Alignment.center,
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.network(
                    imageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: (hasSelection || isFavourite)
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: (hasSelection || isFavourite)
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                  ),
                ),
        ),
        if (hasSelection)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$selectionCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color textColor;

  const _Chip({
    required this.label,
    this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final int daysUntil;
  final ColorScheme cs;

  const _UrgencyBadge({required this.daysUntil, required this.cs});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (daysUntil <= 3) {
      color = Colors.red;
      label = daysUntil <= 0 ? 'Overdue' : 'In $daysUntil d';
    } else if (daysUntil <= 7) {
      color = Colors.orange;
      label = 'in $daysUntil d';
    } else {
      color = Colors.green;
      label = 'in $daysUntil d';
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      // decoration: BoxDecoration(
      //   color: color.withValues(alpha: 0.12),
      //   borderRadius: BorderRadius.circular(6),
      //   border: Border.all(color: color.withValues(alpha: 0.3)),
      // ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final String note;
  final ColorScheme cs;
  final ThemeData theme;

  const _NoteBlock({required this.note, required this.cs, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
