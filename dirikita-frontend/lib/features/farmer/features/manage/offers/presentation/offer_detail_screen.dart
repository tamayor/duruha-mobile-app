import 'package:duruha/core/constants/delivery_statuses.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/helpers/duruha_random_name_generator.dart';

import 'package:duruha/core/widgets/duruha_widgets.dart';

import 'package:duruha/core/widgets/text/duruha_icon_gliding.dart';
import 'package:duruha/features/farmer/features/manage/offers/data/manage_offer_repository.dart';
import 'package:duruha/features/farmer/features/manage/offers/domain/offer_model.dart';
import 'package:duruha/features/farmer/features/subscription/pricelock/presentation/farmer_price_lock_subscription_details_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout & UX improvements summary:
//
//  1. AppBar title simplified – show a cleaner "Offer • XXXXXXXX" format.
//  2. Status badge elevated to a prominent chip with colour-coded background.
//  3. Overview tab sections now separated by a consistent _SectionDivider +
//     labelled headers, making each group visually distinct at a glance.
//  4. Metric tiles use a subtle left-border accent for quick scanning.
//  5. Reservation progress block is tightened: percentage, labels, and bar are
//     all vertically aligned in a single card.
//  6. Availability timeline replaced by a two-column layout with a centred
//     progress pill and a coloured status badge (not just plain text).
//  7. Deactivate button moved below a clear divider so it doesn't feel
//     attached to the content above it.
//  8. Orders tab — "Order Overview" summary uses a consistent 3-column grid
//     with coloured dot indicators per quality tier.
//  9. Each order row now has a subtle card elevation + a numbered index badge
//     for fast identification in long lists.
// 10. Dispatch badge is wrapped in a small outlined pill so it always looks
//     tappable / actionable regardless of whether a date is set.
// 11. Status scroller has a wider tappable surface and a subtle arrow caret
//     to clarify it is interactive.
// 12. Bulk-action dialog and dispatch-date dialog: order list items now show
//     their index number (1-based) for unambiguous referencing.
// ─────────────────────────────────────────────────────────────────────────────

class OfferDetailScreen extends StatefulWidget {
  final HarvestOffer offer;
  final ProduceGroup produce;
  final bool isActive;

  const OfferDetailScreen({
    super.key,
    required this.offer,
    required this.produce,
    required this.isActive,
  });

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  final ManageOfferRepository _repository = ManageOfferRepository();
  late HarvestOffer _offer;
  late List<FarmerOfferOrder> _orders;
  Map<String, dynamic>? _summaryData;
  final Map<String, String> _originalStatuses = {};
  bool _isLoadingOrders = false;

  // ── Short offer ID helper ─────────────────────────────────────────────────
  String get _shortId {
    final id = _offer.offerId;
    return (id.length > 8 ? id.substring(0, 8) : id).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _offer = widget.offer;
    _orders = _offer.orders;
    _updateOriginalStatuses();
    _fetchOrders();
  }

  void _updateOriginalStatuses() {
    for (var o in _orders) {
      _originalStatuses[o.offerOrderMatchId] =
          o.deliveryStatus ?? DeliveryStatus.pending;
    }
  }

  Future<void> _fetchOrders({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoadingOrders = true);
    }
    final response = await _repository.fetchOrdersByOfferId(_offer.offerId);
    if (mounted) {
      setState(() {
        _orders = response.orders;
        _summaryData = response.summary;
        _updateOriginalStatuses();
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _refreshOfferData() async {
    // Refresh both offer details and orders
    final updatedOffer = await _repository.fetchOfferById(_offer.offerId);

    // We also want to refresh orders to get the latest summary/counts
    await _fetchOrders(showLoading: false);

    if (mounted && updatedOffer != null) {
      setState(() {
        _offer = updatedOffer;
      });
    }
  }

  Future<void> _showUpdateOfferDialog() async {
    final quantityController = TextEditingController();
    DateTime fromDate = _offer.availableFrom;
    DateTime toDate = _offer.availableTo;

    final confirmed = await DuruhaDialog.show(
      context: context,
      title: "Edit Offer",
      message: "Adjust quantity or update the harvest schedule.",
      confirmText: "UPDATE",
      icon: Icons.edit_calendar_rounded,
      extraContentBuilder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DuruhaTextField(
              label: "Quantity (e.g. +10 or -5)",
              icon: Icons.add_chart_rounded,
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              isRequired: false,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a quantity';
                }
                final n = double.tryParse(value);
                if (n == null) {
                  return 'Quantity must be a number';
                } else if (n == 0) {
                  return 'Quantity must not be zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              "Schedule",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("From: ${DuruhaFormatter.formatDate(fromDate)}"),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: fromDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setDialogState(() => fromDate = picked);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("To: ${DuruhaFormatter.formatDate(toDate)}"),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: toDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setDialogState(() => toDate = picked);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final delta = double.tryParse(quantityController.text) ?? 0;
      final updatePayload = <String, dynamic>{};
      if (delta != 0) updatePayload['quantity'] = delta;
      if (fromDate != _offer.availableFrom) {
        updatePayload['available_from'] = fromDate.toIso8601String();
      }
      if (toDate != _offer.availableTo) {
        updatePayload['available_to'] = toDate.toIso8601String();
      }

      if (updatePayload.isEmpty) return;

      final message = await _repository.updateOfferStatus(
        offerId: _offer.offerId,
        mode: 'update',
        update: updatePayload,
      );

      if (mounted) {
        if (message != null && !message.startsWith("Error:")) {
          DuruhaSnackBar.showSuccess(context, message);
          _refreshOfferData(); // Refresh both offer and orders
        } else {
          final errorMsg = message?.startsWith("Error:") == true
              ? message!.replaceFirst("Error:", "").trim()
              : message;
          DuruhaSnackBar.showError(
            context,
            errorMsg ?? "Failed to update offer",
          );
        }
      }
    }
  }

  Future<void> _handleOfferStatusChange(String mode) async {
    final theme = Theme.of(context);
    final isDeletable =
        _offer.remainingQuantity == _offer.quantity &&
        (_offer.totalPriceLockCredit == null ||
            _offer.remainingPriceLockCredit == _offer.totalPriceLockCredit);

    String actionText = mode == 'activate'
        ? "Reactivate"
        : (isDeletable ? "Delete" : "Deactivate");
    String warningMsg = "";

    if (mode == 'activate') {
      warningMsg =
          "This will make the offer visible to buyers again. It will use the remaining quantity (${_offer.remainingQuantity}).";
    } else {
      warningMsg = isDeletable
          ? "This will permanently remove the offer. Any price lock credits used will be returned to your subscription."
          : "This will hide the offer from the market.\n Reserved quantities will remain, but no new orders can be placed. \n\nPrice lock credits already utilized will NOT be returned. Reactivate later if you want to use the remaining credits.";
    }

    final confirmed = await DuruhaDialog.show(
      context: context,
      title: "$actionText Offer?",
      message: warningMsg,
      confirmText: actionText.toUpperCase(),
      isDanger: mode != 'activate',
      icon: mode == 'activate'
          ? Icons.play_circle_outline
          : (isDeletable ? Icons.delete_forever : Icons.warning_amber_rounded),
      confirmColor: mode == 'activate'
          ? theme.colorScheme.tertiary
          : Colors.red,
    );

    if (confirmed == true) {
      final message = await _repository.updateOfferStatus(
        offerId: _offer.offerId,
        mode: mode,
      );
      if (mounted) {
        if (message != null && !message.startsWith("Error:")) {
          DuruhaSnackBar.showSuccess(context, message);
          if (mode == 'delete' && isDeletable) {
            Navigator.pop(context, true);
          } else {
            _refreshOfferData();
          }
        } else {
          final errorMsg = message?.startsWith("Error:") == true
              ? message!.replaceFirst("Error:", "").trim()
              : message;
          DuruhaSnackBar.showError(
            context,
            errorMsg ?? "Failed to ${actionText.toLowerCase()} offer",
          );
        }
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeletable =
        _offer.remainingQuantity == _offer.quantity &&
        (_offer.totalPriceLockCredit == null ||
            _offer.remainingPriceLockCredit == _offer.totalPriceLockCredit);
    final actionText = isDeletable ? "Delete" : "Deactivate";

    final editableOrders = _orders
        .where(
          (o) => DeliveryStatus.farmerEditable.contains(
            o.deliveryStatus ?? DeliveryStatus.pending,
          ),
        )
        .toList();

    return DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: DuruhaScaffold(
        // ── Cleaner title: short ID clearly separated from the label
        appBarTitle: "Offer · $_shortId",
        appBarActions: [
          if (_offer.isActive)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: DuruhaPopupMenu<String>(
                items: [
                  'edit',
                  if (editableOrders.isNotEmpty) 'update_all_status',
                  if (_orders.isNotEmpty) 'set_dispatch_all',
                  if (_offer.isActive)
                    'deactivate'
                  else if (_offer.remainingQuantity > 0 &&
                      (_offer.isPriceLocked == false ||
                          _summaryData?['fpls_status'] == 'ACTIVE'))
                    'reactivate',
                ],
                tooltip: 'Actions',
                icon: const Icon(Icons.more_vert),
                showLabel: false,
                showBackground: false,
                selectedValue: 'edit',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showUpdateOfferDialog();
                      break;
                    case 'update_all_status':
                      _showBulkUpdateDialog(context, editableOrders);
                      break;
                    case 'set_dispatch_all':
                      _showSetDispatchDateDialog(context, _orders);
                      break;
                    case 'deactivate':
                      _handleOfferStatusChange('delete');
                      break;
                    case 'reactivate':
                      _handleOfferStatusChange('activate');
                      break;
                  }
                },
                labelBuilder: (value) => switch (value) {
                  'edit' => 'Edit Offer',
                  'update_all_status' => 'Update All Orders',
                  'set_dispatch_all' => 'Set Dispatch Date (All)',
                  'deactivate' => '$actionText Offer',
                  'reactivate' => 'Reactivate Offer',
                  _ => value,
                },
                itemIcons: {
                  'edit': Icons.edit_outlined,
                  'update_all_status': Icons.edit_note_rounded,
                  'set_dispatch_all': Icons.calendar_today_rounded,
                  'deactivate': isDeletable
                      ? Icons.delete_forever
                      : Icons.warning_amber_rounded,
                  'reactivate': Icons.play_circle_outline,
                },
              ),
            ),
          if (!_offer.isActive &&
              _offer.remainingQuantity > 0 &&
              (_offer.isPriceLocked == false ||
                  _summaryData?['fpls_status'] == 'ACTIVE'))
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                tooltip: 'Reactivate Offer',
                onPressed: () => _handleOfferStatusChange('activate'),
              ),
            ),
        ],
        body: DuruhaScrollHideWrapper(
          bar: DuruhaTabBar(
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: "OVERVIEW"),
              Tab(text: "ORDERS"),
            ],
          ),
          body: TabBarView(
            children: [_buildOverviewTab(theme), _buildOrdersTab(theme)],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, ThemeData theme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ── OVERVIEW TAB ──────────────────────────────────────────────────────────
  Widget _buildOverviewTab(ThemeData theme) {
    final isDeletable =
        _offer.remainingQuantity == _offer.quantity &&
        (_offer.totalPriceLockCredit == null ||
            _offer.remainingPriceLockCredit == _offer.totalPriceLockCredit);
    final now = DateTime.now();

    final totalDuration = _offer.availableTo
        .difference(_offer.availableFrom)
        .inHours;
    final elapsed = now.difference(_offer.availableFrom).inHours;
    final double timeProgress = totalDuration > 0
        ? (elapsed / totalDuration).clamp(0.0, 1.0)
        : 1.0;

    final double reserveProgress = _offer.quantity > 0
        ? (_offer.reservedQty / _offer.quantity).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Header band: status chip + offer ID ─────────────────────
          _buildOfferHeaderBand(theme),
          const SizedBox(height: 16),

          if (_summaryData != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DuruhaSectionContainer(
                title: "SUMMARY",
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryStat(
                        "Total Qty",
                        "${_summaryData!['quantity'] ?? 0} kg",
                        theme,
                      ),
                      _buildSummaryStat(
                        "Remaining",
                        "${_summaryData!['remaining_quantity'] ?? 0} kg",
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryStat(
                        "Active Value",
                        DuruhaFormatter.formatCurrency(
                          (_summaryData!['active_total'] as num?)?.toDouble() ??
                              0,
                        ),
                        theme,
                      ),
                      const Spacer(),
                    ],
                  ),
                  if (_summaryData!['is_price_locked'] == true) ...[
                    _buildPriceLockSection(theme),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 2. Produce identity ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _offer.varietyName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.produce.produceLocalName.isNotEmpty
                      ? widget.produce.produceLocalName
                      : widget.produce.produceEnglishName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                // Produce ID as a subtle monospace chip
                _buildIdChip(
                  theme,
                  label: "PRODUCE",
                  id: widget.produce.produceId,
                ),
              ],
            ),
          ),

          _SectionDivider(label: "RESERVATION PROGRESS", theme: theme),

          // ── 4. Reservation progress ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildReservationCard(theme, reserveProgress),
          ),

          _SectionDivider(label: "OFFER AVAILABILITY", theme: theme),

          // ── 5. Availability timeline ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildAvailabilityCard(theme, now, timeProgress),
          ),

          // ── 6. Status Action (visually separated) ──────────────────
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: theme.colorScheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _offer.isActive
                ? (isDeletable
                      ? DuruhaButton(
                          text: "Delete Offer",
                          backgroundColor: Colors.red,
                          onPressed: () => _handleOfferStatusChange('delete'),
                        )
                      : DuruhaButton(
                          text: "Deactivate Offer",
                          onPressed: () => _handleOfferStatusChange('delete'),
                          isOutline: true,
                        ))
                : (_offer.remainingQuantity > 0 &&
                          (_offer.isPriceLocked == false ||
                              _summaryData?['fpls_status'] == 'ACTIVE')
                      ? DuruhaButton(
                          text: "Reactivate Offer",
                          backgroundColor: theme.colorScheme.tertiary,
                          onPressed: () => _handleOfferStatusChange('activate'),
                        )
                      : const SizedBox.shrink()),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPriceLockSection(ThemeData theme) {
    final String status = "${_summaryData!['fpls_status']}".toUpperCase();
    final bool isActive = status == 'ACTIVE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 16),

        // Section Header with Status Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Price Lock Subscription",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            _buildStatusBadge(theme, status, isActive),
          ],
        ),
        const SizedBox(height: 12),

        // Subscription Content Card
        DuruhaInkwell(
          variation: InkwellVariation.brand, // Subtle surface variation
          borderRadius: 12,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FarmerPriceLockSubscriptionDetailsScreen(
                  fplsId: _summaryData!['fpls_id'],
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: IntrinsicHeight(
              // Allows the VerticalDivider to know its height
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryStat(
                      "Total Credit",
                      DuruhaFormatter.formatCurrency(
                        (_summaryData!['total_price_lock_credit'] as num?)
                                ?.toDouble() ??
                            0,
                      ),
                      theme,
                    ),
                  ),
                  VerticalDivider(
                    color: theme.colorScheme.outlineVariant,
                    thickness: 1,
                    indent: 4,
                    endIndent: 4,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryStat(
                      "Remaining",
                      DuruhaFormatter.formatCurrency(
                        (_summaryData!['remaining_price_lock_credit'] as num?)
                                ?.toDouble() ??
                            0,
                      ),
                      theme,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme, String status, bool isActive) {
    final color = isActive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Top coloured band showing active/expired status + offer ID.
  Widget _buildOfferHeaderBand(ThemeData theme) {
    final isActive = widget.isActive;
    final bandColor = isActive
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surfaceContainerHigh;
    final labelColor = isActive
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      color: bandColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status pill
          Row(
            children: [
              Icon(
                isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined,
                size: 16,
                color: labelColor,
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? "ACTIVE OFFER" : "OFFER EXPIRED",
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          // Offer ID chip
          _buildIdChip(theme, label: "OFFER", id: _offer.offerId),
        ],
      ),
    );
  }

  /// Small monospace ID chip used for both offer ID and produce ID.
  Widget _buildIdChip(
    ThemeData theme, {
    required String label,
    required String id,
  }) {
    final shortId = (id.length > 8 ? id.substring(0, 8) : id).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "$label · $shortId",
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Reservation progress card with aligned stats and progress bar.
  Widget _buildReservationCard(ThemeData theme, double reserveProgress) {
    final pct = (reserveProgress * 100).toInt();
    return DuruhaSectionContainer(
      children: [
        // Percentage + remaining label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$pct% Reserved",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${DuruhaFormatter.formatNumber(_offer.remainingQuantity)} kg remaining",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DuruhaProgressBar(
          value: reserveProgress,
          height: 10,
          backgroundColor: theme.colorScheme.onTertiary.withValues(alpha: 0.15),
          color: theme.colorScheme.onTertiary,
        ),
        const SizedBox(height: 10),
        // Target / reserved row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProgressLegendItem(
              theme,
              icon: Icons.inventory_2_outlined,
              label: "Target",
              value: "${DuruhaFormatter.formatNumber(_offer.quantity)} kg",
            ),
            _buildProgressLegendItem(
              theme,
              icon: Icons.bookmark_added_outlined,
              label: "Reserved",
              value: "${DuruhaFormatter.formatNumber(_offer.reservedQty)} kg",
              alignRight: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressLegendItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    bool alignRight = false,
  }) {
    return Row(
      children: [
        if (!alignRight) ...[
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
        ],
        Column(
          crossAxisAlignment: alignRight
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
        if (alignRight) ...[
          const SizedBox(width: 4),
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );
  }

  /// Availability card: dates, timeline bar, and coloured status badge.
  Widget _buildAvailabilityCard(
    ThemeData theme,
    DateTime now,
    double timeProgress,
  ) {
    final timelineStatus = _getTimelineStatus(_offer, now);
    // Colour based on urgency
    Color statusColor;
    if (timelineStatus.contains("expired")) {
      statusColor = theme.colorScheme.error;
    } else if (timelineStatus.contains("remaining") &&
        _offer.availableTo.difference(now).inDays <= 3) {
      statusColor = Colors.orange;
    } else {
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return DuruhaSectionContainer(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDateColumn(context, "Start Date", _offer.availableFrom),
            _buildDateColumn(
              context,
              "End Date",
              _offer.availableTo,
              isEnd: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        DuruhaProgressBar(
          value: timeProgress,
          height: 6,
          backgroundColor: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: 0.15,
          ),
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        // Coloured status badge centred below the bar
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              timelineStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── ORDERS TAB ────────────────────────────────────────────────────────────
  Widget _buildOrdersTab(ThemeData theme) {
    final pendingPaymentCount = _orders.where((o) {
      final isUnpaid = !o.farmerIsPaid;
      final status = o.deliveryStatus?.toUpperCase();
      final isPendingStatus = DeliveryStatus.farmerEditable.contains(status);
      return isUnpaid && isPendingStatus;
    }).length;

    // Quality totals
    double saverKg = 0, regularKg = 0, selectKg = 0;
    final Map<String, int> statusCounts = {};

    for (var o in _orders) {
      final q = o.quality?.toLowerCase() ?? '';
      if (q.contains('saver')) {
        saverKg += o.quantity;
      } else if (q.contains('select') || q.contains('premium')) {
        selectKg += o.quantity;
      } else {
        regularKg += o.quantity;
      }
      final s = (o.deliveryStatus ?? 'pending')
          .replaceAll('_', ' ')
          .toUpperCase();
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }

    // Quality tier colour dots
    const tierDots = {
      'Saver': Colors.green,
      'Regular': Colors.blue,
      'Select': Colors.amber,
    };

    Widget buildQualityStat(String label, double kg, Color dot) {
      return Expanded(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6, top: 2),
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    "${DuruhaFormatter.formatCompactNumber(kg)} kg",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Order Overview summary ───────────────────────────────────
          if (_orders.isNotEmpty) ...[
            DuruhaSectionContainer(
              title: "Order Overview",
              padding: const EdgeInsets.all(16),
              children: [
                // Quality breakdown with coloured dots
                Text(
                  "Quality Breakdown",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    buildQualityStat("Saver", saverKg, tierDots['Saver']!),
                    buildQualityStat(
                      "Regular",
                      regularKg,
                      tierDots['Regular']!,
                    ),
                    buildQualityStat("Select", selectKg, tierDots['Select']!),
                  ],
                ),

                const SizedBox(height: 20),

                // Status breakdown with coloured chips
                Text(
                  "Delivery Status",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: statusCounts.entries.map((e) {
                    final chipColor = DeliveryStatus.getStatusColor(
                      e.key.toLowerCase(),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: chipColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: chipColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            "${e.key}  ${e.value}",
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: chipColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // Pending payment warning
                if (pendingPaymentCount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.onErrorContainer,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$pendingPaymentCount order${pendingPaymentCount > 1 ? 's' : ''} pending payment",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ── Scheduled Orders list ────────────────────────────────────
          DuruhaSectionContainer(
            title: "Scheduled Orders",
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),

            children: [
              if (_isLoadingOrders)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_orders.isEmpty)
                _buildEmptyOrdersState(theme)
              else
                ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _orders.length,
                  separatorBuilder: (_, _) => Divider(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                    height: 20,
                  ),
                  itemBuilder: (context, index) =>
                      _buildOrderRow(context, _orders[index], index + 1),
                ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyOrdersState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        // Adding a very subtle dash-style border or light fill
        // makes the empty section feel intentional
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Enhanced Icon with a "background circle"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons
                  .calendar_today_outlined, // Changed to a slightly softer icon
              size: 32,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Primary Message
          Text(
            "No orders scheduled yet",
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // 3. Helpful Hint (Secondary Text)
          Text(
            "New orders will appear here once customers start reserving your produce.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  Future<void> _showBulkUpdateDialog(
    BuildContext context,
    List<FarmerOfferOrder> editableOrders,
  ) async {
    String selectedStatus = DeliveryStatus.pending;

    await DuruhaDialog.show(
      context: context,
      title: "Update ${editableOrders.length} Orders",
      message: "Set a new status for all editable orders in this offer.",
      confirmText: "UPDATE STATUS",
      icon: Icons.edit_note_rounded,
      extraContentBuilder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DuruhaSelectionChipGroup(
              title: "Delivery Status",
              options: DeliveryStatus.farmerEditable,
              selectedValues: [selectedStatus],
              onToggle: (status) =>
                  setDialogState(() => selectedStatus = status),
              optionTitles: {
                for (final s in DeliveryStatus.farmerEditable)
                  s: s.replaceAll('_', ' ').toUpperCase(),
              },
            ),
          ],
        ),
      ),
      confirmColor: Theme.of(context).colorScheme.primary,
    ).then((confirmed) async {
      if (confirmed == true) {
        setState(() => _isLoadingOrders = true);
        final orderIds = editableOrders
            .map((e) => e.offerOrderMatchId)
            .toList();
        final success = await _repository.updateOrdersDeliveryStatus(
          orderIds,
          selectedStatus,
          null,
        );
        if (!context.mounted) return;
        if (success) {
          DuruhaSnackBar.showSuccess(
            context,
            "Successfully updated ${orderIds.length} orders.",
          );
          setState(() => _isLoadingOrders = false);
          _fetchOrders(showLoading: false);
        } else {
          DuruhaSnackBar.showError(context, "Failed to update orders.");
          setState(() => _isLoadingOrders = false);
        }
      }
    });
  }

  Future<void> _showSetDispatchDateDialog(
    BuildContext context,
    List<FarmerOfferOrder> targetOrders,
  ) async {
    final theme = Theme.of(context);
    DateTime? selectedDispatchAt = targetOrders.length == 1
        ? targetOrders.first.dispatchAt
        : null;

    await DuruhaDialog.show(
      context: context,
      title: "Set Dispatch Date",
      message:
          "Update dispatch date for ${targetOrders.length == 1 ? 'this order' : '${targetOrders.length} orders'}:",
      confirmText: "SET DATE",
      icon: Icons.calendar_today_rounded,
      extraContentBuilder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: targetOrders.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final order = entry.value;
                    final displayName =
                        order.consumerName ??
                        "Reserved (${DuruhaRandomNameGenerator.generate(idSeed: idx.toString())})";
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "${idx + 1}",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              displayName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DuruhaInkwell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDispatchAt ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) {
                  setDialogState(() => selectedDispatchAt = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      selectedDispatchAt == null
                          ? "Select Date"
                          : DuruhaFormatter.formatDate(selectedDispatchAt!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((confirmed) async {
      if (confirmed == true && selectedDispatchAt != null) {
        setState(() => _isLoadingOrders = true);
        final orderIds = targetOrders.map((e) => e.offerOrderMatchId).toList();
        final success = await _repository.updateOrdersDeliveryStatus(
          orderIds,
          null,
          selectedDispatchAt,
        );
        if (!context.mounted) return;
        if (success) {
          DuruhaSnackBar.showSuccess(
            context,
            "Successfully set dispatch date for ${orderIds.length} orders.",
          );
          _fetchOrders(showLoading: false);
        } else {
          DuruhaSnackBar.showError(context, "Failed to set dispatch date.");
          setState(() => _isLoadingOrders = false);
        }
      }
    });
  }

  // ── Status update logic ───────────────────────────────────────────────────
  Future<void> _updateStatus(String orderId, String newStatus) async {
    final orderIndex = _orders.indexWhere(
      (o) => o.offerOrderMatchId == orderId,
    );
    if (orderIndex == -1) return;
    final oldOrder = _orders[orderIndex];

    setState(() {
      _orders[orderIndex] = oldOrder.copyWith(deliveryStatus: newStatus);
    });

    final success = await _repository.updateOrderDeliveryStatus(
      orderId,
      newStatus,
    );
    if (!mounted) return;

    if (success) {
      _originalStatuses[orderId] = newStatus;
      DuruhaSnackBar.showSuccess(
        context,
        "Status → ${newStatus.replaceAll('_', ' ')}",
      );
      _fetchOrders(showLoading: false);
    } else {
      setState(() {
        _orders[orderIndex] = oldOrder;
      });
      DuruhaSnackBar.showError(context, "Failed to update status");
    }
  }

  Future<void> _handleOrderDeliveryStatusChange(
    BuildContext context,
    FarmerOfferOrder order,
    String newStatus,
  ) async {
    if (newStatus == order.deliveryStatus) return;
    final confirmed = await DuruhaDialog.show(
      context: context,
      title: "Change Status?",
      message:
          "Update order to ${newStatus.replaceAll('_', ' ').toUpperCase()}?",
      confirmText: "UPDATE",
      confirmColor: DeliveryStatus.getStatusColor(newStatus),
    );
    if (confirmed != true) return;

    final orderId = order.offerOrderMatchId;
    final orderIndex = _orders.indexWhere(
      (o) => o.offerOrderMatchId == orderId,
    );
    if (orderIndex != -1) {
      setState(() {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          deliveryStatus: newStatus,
        );
      });
    }
    if (_originalStatuses[orderId] != newStatus) {
      await _updateStatus(orderId, newStatus);
    }
  }

  // ── Order row ─────────────────────────────────────────────────────────────
  /// [orderNumber] is 1-based for display (e.g. "#1", "#2").
  Widget _buildOrderRow(
    BuildContext context,
    FarmerOfferOrder order,
    int orderNumber,
  ) {
    final theme = Theme.of(context);

    final displayName =
        order.consumerName ??
        "Reserved (${DuruhaRandomNameGenerator.generate(idSeed: (orderNumber - 1).toString())})";

    String? dispatchStr;
    if (order.dispatchAt != null) {
      dispatchStr = order.dispatchAt!.difference(DateTime.now()).inDays >= 365
          ? "DISPATCH NOW"
          : DuruhaFormatter.formatDateTime(order.dispatchAt!);
    }

    final currentStatus = order.deliveryStatus ?? DeliveryStatus.pending;
    final statusColor = DeliveryStatus.getStatusColor(currentStatus);

    return Container(
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row header: date-needed centred + index badge ─────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Index badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "#$orderNumber - $displayName",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'Courier',
                  ),
                ),
              ),

              if (order.quality != null) ...[
                const SizedBox(height: 2),
                Text(
                  "${order.quality}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // ── Main content row: details | financials ────────────────────
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Vertically aligns Column and Badge
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize:
                    MainAxisSize.min, // Keeps column height tight to content
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Aligns text to the left
                children: [
                  Text(
                    "NEEDED BY",
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondary,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    DuruhaFormatter.formatDate(order.dateNeeded!).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiary,
                    ),
                  ),
                ],
              ),
              if (dispatchStr == "DISPATCH NOW") ...[
                SizedBox(
                  width:
                      130, // <--- Add this! It gives the animation a "track" to run on
                  child: DuruhaInkwell(
                    onTap: () => _showSetDispatchDateDialog(context, [order]),
                    variation: InkwellVariation.brand,
                    child: DuruhaGlidingIconBadge(
                      text: dispatchStr!,
                      icon: Icons.local_shipping_rounded,
                      baseColor: theme.colorScheme.onSecondary,
                      highlightColor: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ] else
                Column(
                  children: [
                    Text(
                      "DISPATCHED",
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondary,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      DuruhaFormatter.formatDate(
                        order.dispatchAt!,
                      ).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Status scroller ───────────────────────────────────────────
          _buildStatusScroller(context, order),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    DuruhaFormatter.formatCurrency(order.farmerPayout),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    "${order.quantity} kg @ ${DuruhaFormatter.formatCurrency(order.price)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              _buildPaymentChip(order.farmerIsPaid),
            ],
          ),
        ],
      ),
    );
  }

  // ── Small widgets ─────────────────────────────────────────────────────────

  Widget _buildPaymentChip(bool isPaid) {
    final color = isPaid ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.pending,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isPaid ? "PAID" : "INCOMING",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Status dropdown – wider hit area and proper inkwell effect.
  Widget _buildStatusScroller(BuildContext context, FarmerOfferOrder order) {
    final currentStatus = order.deliveryStatus ?? DeliveryStatus.pending;
    final statusColor = DeliveryStatus.getStatusColor(currentStatus);

    return Material(
      color: statusColor.withValues(alpha: 0.07),
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(8),
      child: DuruhaPopupMenu<String>(
        items: DeliveryStatus.farmerEditable,
        selectedValue: currentStatus,
        isTextOnly: true, // Bypass default internal styling
        onSelected: (newStatus) =>
            _handleOrderDeliveryStatusChange(context, order, newStatus),
        labelBuilder: (s) => s.replaceAll('_', ' ').toUpperCase(),
        customTrigger: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(_getStatusIcon(currentStatus), size: 16, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentStatus.replaceAll('_', ' ').toUpperCase(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Caret hint
              Icon(
                Icons.unfold_more_rounded,
                size: 16,
                color: statusColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Static helper widgets ─────────────────────────────────────────────────

  /// Metric tile with a coloured left-border accent for quick visual scanning.

  Widget _buildDateColumn(
    BuildContext context,
    String label,
    DateTime date, {
    bool isEnd = false,
  }) {
    final theme = Theme.of(context);
    final isInfinity = date.year >= 2100;
    return Column(
      crossAxisAlignment: isEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isInfinity ? "Supply Lasts" : DateFormat('MMM d, yyyy').format(date),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getTimelineStatus(HarvestOffer offer, DateTime now) {
    if (now.isBefore(offer.availableFrom)) {
      final days = offer.availableFrom.difference(now).inDays;
      return days == 0 ? "Starting tomorrow" : "Starting in $days days";
    }
    if (offer.availableTo.year >= 2100) return "Available until supply lasts";
    if (now.isAfter(offer.availableTo)) return "Offer has expired";
    final daysLeft = offer.availableTo.difference(now).inDays;
    return "$daysLeft day${daysLeft != 1 ? 's' : ''} remaining";
  }

  IconData _getStatusIcon(String status) => switch (status.toLowerCase()) {
    'pending' => Icons.hourglass_empty_rounded,
    'processing' => Icons.inventory_2_outlined,
    'shipped' || 'in_transit' => Icons.local_shipping_outlined,
    'delivered' => Icons.check_circle_outline_rounded,
    'cancelled' => Icons.cancel_outlined,
    _ => Icons.fire_truck,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionDivider
// A lightweight labelled horizontal rule used between overview sections.
// ─────────────────────────────────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _SectionDivider({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class DispatchNowBadge extends StatelessWidget {
  final VoidCallback onTap;

  const DispatchNowBadge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DuruhaInkwell(
      onTap: onTap,
      variation: InkwellVariation.brand,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const _GlidingIconBadge(
          text: "DISPATCH NOW",
          icon: Icons.electric_bolt,
        ),
      ),
    );
  }
}

class _GlidingIconBadge extends StatefulWidget {
  final String text;
  final IconData icon;

  const _GlidingIconBadge({required this.text, required this.icon});

  @override
  State<_GlidingIconBadge> createState() => _GlidingIconBadgeState();
}

class _GlidingIconBadgeState extends State<_GlidingIconBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Moves the icon from left to right (-0.5 to 1.5 to ensure it clears the edges)
    _positionAnimation = Tween<double>(
      begin: -0.2,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Fades the icon in the middle and out at the edges
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: ConstantTween(0.8), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 20),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // The Base Text
            Text(
              widget.text,
              style: const TextStyle(
                color: Colors.white24, // Faded so the icon "lights it up"
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            // The Animating Icon "Over" the text
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Positioned(
                  left: _positionAnimation.value * 100, // Moves across
                  child: FadeTransition(
                    opacity: _opacityAnimation,
                    child: Icon(
                      widget.icon,
                      color: Colors.yellowAccent,
                      size: 18,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
