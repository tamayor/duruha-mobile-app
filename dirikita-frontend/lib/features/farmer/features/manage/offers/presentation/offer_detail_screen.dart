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
import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:intl/intl.dart';

class OfferDetailScreen extends StatefulWidget {
  final HarvestOffer offer;
  final ProduceOfferGroup produce;
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

  // Single source of truth for all offer data (offer + orders + summary).
  OfferDetail? _detail;
  final Map<String, String> _originalStatuses = {};
  bool _isLoading = false;
  bool _hasChanges = false;

  // ── Helpers ───────────────────────────────────────────────────────────────
  HarvestOffer get _offer => _detail?.offer ?? widget.offer;
  List<FarmerOfferOrder> get _orders => _detail?.orders ?? widget.offer.orders;

  String get _shortId {
    final id = _offer.offerId;
    return (id.length > 8 ? id.substring(0, 8) : id).toUpperCase();
  }

  void _updateOriginalStatuses() {
    for (final o in _orders) {
      _originalStatuses[o.offerOrderMatchId] =
          o.deliveryStatus ?? DeliveryStatus.pending;
    }
  }

  @override
  void initState() {
    super.initState();
    _updateOriginalStatuses();
    _fetchDetail();
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchDetail({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);

    final result = await _repository.fetchOfferDetail(_offer.offerId);

    if (mounted) {
      setState(() {
        if (result != null) {
          _detail = result;
          _hasChanges = true;
          _updateOriginalStatuses();
        }
        _isLoading = false;
      });
    }
  }

  // ── Dialogs / actions ─────────────────────────────────────────────────────

  Future<void> _showUpdateOfferDialog() async {
    final quantityController = TextEditingController();
    DateTime fromDate = _offer.availableFrom;
    DateTime toDate = _offer.availableTo;

    final confirmed = await DuruhaDialog.show(
      context: context,
      title: 'Edit Offer',
      message: 'Adjust quantity or update the harvest schedule.',
      confirmText: 'UPDATE',
      icon: Icons.edit_calendar_rounded,
      extraContentBuilder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DuruhaTextField(
              label: 'Quantity (e.g. +10 or -5)',
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
                if (n == null) return 'Quantity must be a number';
                if (n == 0) return 'Quantity must not be zero';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('From: ${DuruhaFormatter.formatDate(fromDate)}'),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: () async {
                final now = DateTime.now();
                final bool isFar = fromDate.difference(now).inDays > 365;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: isFar
                      ? now.add(const Duration(days: 30))
                      : fromDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setDialogState(() => fromDate = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('To: ${DuruhaFormatter.formatDate(toDate)}'),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: () async {
                final now = DateTime.now();
                final bool isFar = toDate.difference(now).inDays > 365;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: isFar
                      ? now.add(const Duration(days: 30))
                      : toDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setDialogState(() => toDate = picked);
              },
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
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

      if (!mounted) return;
      if (message != null && !message.startsWith('Error:')) {
        DuruhaSnackBar.showSuccess(context, message);
        _fetchDetail(showLoading: false);
      } else {
        DuruhaSnackBar.showError(
          context,
          message?.startsWith('Error:') == true
              ? message!.replaceFirst('Error:', '').trim()
              : message ?? 'Failed to update offer',
        );
      }
    }
  }

  Future<void> _handleOfferStatusChange(String mode) async {
    final theme = Theme.of(context);
    final isDeletable =
        _offer.remainingQuantity == _offer.quantity &&
        (_offer.totalPriceLockCredit == null ||
            _offer.remainingPriceLockCredit == _offer.totalPriceLockCredit);

    final String actionText = mode == 'activate'
        ? 'Reactivate'
        : (isDeletable ? 'Delete' : 'Deactivate');

    final String warningMsg = mode == 'activate'
        ? 'This will make the offer visible to buyers again with ${_offer.remainingQuantity} units available.'
        : isDeletable
        ? 'This will permanently remove the offer. Any price lock credits used will be returned to your subscription.'
        : 'This will hide the offer from the market.\n Reserved quantities will remain, but no new orders can be placed. \n\nPrice lock credits already utilized will NOT be returned. Reactivate later if you want to use the remaining credits.';

    final confirmed = await DuruhaDialog.show(
      context: context,
      title: '$actionText Offer?',
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
      if (!mounted) return;
      final message = await _repository.updateOfferStatus(
        offerId: _offer.offerId,
        mode: mode,
      );
      if (!mounted) return;
      if (message != null && !message.startsWith('Error:')) {
        DuruhaSnackBar.showSuccess(context, message);
        if (mode == 'delete' && isDeletable) {
          Navigator.pop(context, true);
        } else {
          _fetchDetail(showLoading: false);
        }
      } else {
        DuruhaSnackBar.showError(
          context,
          message?.startsWith('Error:') == true
              ? message!.replaceFirst('Error:', '').trim()
              : message ?? 'Failed to ${actionText.toLowerCase()} offer',
        );
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
    final actionText = isDeletable ? 'Delete' : 'Deactivate';

    final editableOrders = _orders
        .where(
          (o) => DeliveryStatus.farmerEditable.contains(
            o.deliveryStatus ?? DeliveryStatus.pending,
          ),
        )
        .toList();

    final canReactivate =
        !_offer.isActive &&
        _offer.remainingQuantity == _offer.quantity &&
        _offer.remainingQuantity > 0 &&
        (_offer.isPriceLocked == false ||
            _detail?.fpsStatus?.toUpperCase() == 'ACTIVE');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanges);
      },
      child: DefaultTabController(
        length: 2,
        initialIndex: 1,
        child: DuruhaScaffold(
          onBackPressed: () => Navigator.pop(context, _hasChanges),
          appBarTitle: 'Offer · $_shortId',
          appBarActions: [
            if (_offer.isActive)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: DuruhaPopupMenu<String>(
                  items: [
                    'edit',
                    if (editableOrders.isNotEmpty) 'update_all_status',
                    if (_orders.isNotEmpty) 'set_dispatch_all',
                    'deactivate',
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
                      case 'update_all_status':
                        _showBulkUpdateDialog(context, editableOrders);
                      case 'set_dispatch_all':
                        _showSetDispatchDateDialog(context, _orders);
                      case 'deactivate':
                        _handleOfferStatusChange('delete');
                    }
                  },
                  labelBuilder: (value) => switch (value) {
                    'edit' => 'Edit Offer',
                    'update_all_status' => 'Update All Orders',
                    'set_dispatch_all' => 'Set Dispatch Date (All)',
                    'deactivate' => '$actionText Offer',
                    _ => value,
                  },
                  itemIcons: {
                    'edit': Icons.edit_outlined,
                    'update_all_status': Icons.edit_note_rounded,
                    'set_dispatch_all': Icons.calendar_today_rounded,
                    'deactivate': isDeletable
                        ? Icons.delete_forever
                        : Icons.warning_amber_rounded,
                  },
                ),
              ),
            if (canReactivate)
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
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'ORDERS'),
              ],
            ),
            body: TabBarView(
              children: [_buildOverviewTab(theme), _buildOrdersTab(theme)],
            ),
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

    final canReactivate =
        _offer.remainingQuantity > 0 &&
        (_offer.isPriceLocked == false ||
            _detail?.fpsStatus?.toUpperCase() == 'ACTIVE');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOfferHeaderBand(theme),
          const SizedBox(height: 16),

          if (_detail != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DuruhaSectionContainer(
                title: 'SUMMARY',
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _buildSummaryStat(
                        'Total Qty',
                        '${_offer.quantity} kg',
                        theme,
                      ),
                      _buildSummaryStat(
                        'Remaining',
                        '${_offer.remainingQuantity} kg',
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSummaryStat(
                        'Active Value',
                        DuruhaFormatter.formatCurrency(_detail!.activeTotal),
                        theme,
                      ),
                      const Spacer(),
                    ],
                  ),
                  if (_offer.isPriceLocked) ...[_buildPriceLockSection(theme)],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
                _buildIdChip(
                  theme,
                  label: 'PRODUCE',
                  id: widget.produce.produceId,
                ),
              ],
            ),
          ),

          _SectionDivider(label: 'RESERVATION PROGRESS', theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildReservationCard(theme, reserveProgress),
          ),

          _SectionDivider(label: 'OFFER AVAILABILITY', theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildAvailabilityCard(theme, now, timeProgress),
          ),

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
                          text: 'Delete Offer',
                          backgroundColor: Colors.red,
                          onPressed: () => _handleOfferStatusChange('delete'),
                        )
                      : DuruhaButton(
                          text: 'Deactivate Offer',
                          onPressed: () => _handleOfferStatusChange('delete'),
                          isOutline: true,
                        ))
                : (canReactivate
                      ? DuruhaButton(
                          text: 'Reactivate Offer',
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
    final String status = (_detail?.fpsStatus ?? '').toUpperCase();
    final bool isActive = status == 'ACTIVE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Price Lock Subscription',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            _buildStatusBadge(
              theme,
              status.isEmpty ? 'UNKNOWN' : status,
              isActive,
            ),
          ],
        ),
        const SizedBox(height: 12),
        DuruhaInkwell(
          variation: InkwellVariation.brand,
          onTap: () {
            if (_detail?.fpsId == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FarmerPriceLockSubscriptionDetailsScreen(
                  fplsId: _detail!.fpsId!,
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
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryStat(
                      'Total Credit',
                      DuruhaFormatter.formatCurrency(
                        _offer.totalPriceLockCredit ?? 0,
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
                      'Remaining',
                      DuruhaFormatter.formatCurrency(
                        _offer.remainingPriceLockCredit ?? 0,
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

  Widget _buildOfferHeaderBand(ThemeData theme) {
    final isActive = _offer.isActive;
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
                isActive ? 'ACTIVE OFFER' : 'OFFER EXPIRED',
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          _buildIdChip(theme, label: 'OFFER', id: _offer.offerId),
        ],
      ),
    );
  }

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
        '$label · $shortId',
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

  Widget _buildReservationCard(ThemeData theme, double reserveProgress) {
    final pct = (reserveProgress * 100).toInt();
    return DuruhaSectionContainer(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$pct% Reserved',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${DuruhaFormatter.formatNumber(_offer.remainingQuantity)} kg remaining',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProgressLegendItem(
              theme,
              icon: Icons.inventory_2_outlined,
              label: 'Target',
              value: '${DuruhaFormatter.formatNumber(_offer.quantity)} kg',
            ),
            _buildProgressLegendItem(
              theme,
              icon: Icons.bookmark_added_outlined,
              label: 'Reserved',
              value: '${DuruhaFormatter.formatNumber(_offer.reservedQty)} kg',
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

  Widget _buildAvailabilityCard(
    ThemeData theme,
    DateTime now,
    double timeProgress,
  ) {
    final timelineStatus = _getTimelineStatus(_offer, now);
    Color statusColor;
    if (timelineStatus.contains('expired')) {
      statusColor = theme.colorScheme.error;
    } else if (timelineStatus.contains('remaining') &&
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
            _buildDateColumn(context, 'Start Date', _offer.availableFrom),
            _buildDateColumn(
              context,
              'End Date',
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
      return isUnpaid && DeliveryStatus.farmerEditable.contains(status);
    }).length;

    final needsDispatchOrders = _orders.where((o) {
      final isCancelled =
          (o.deliveryStatus ?? '').toUpperCase() == DeliveryStatus.cancelled;
      return o.needsDispatchSetup && !isCancelled;
    }).toList();

    double saverKg = 0, regularKg = 0, selectKg = 0;
    final Map<String, int> statusCounts = {};

    for (final o in _orders) {
      if ((o.deliveryStatus ?? '').toUpperCase() == DeliveryStatus.cancelled) {
        continue;
      }
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
                    '${DuruhaFormatter.formatCompactNumber(kg)} kg',
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Dispatch Alert Banner ───────────────────────────────────────
          if (needsDispatchOrders.isNotEmpty) ...[
            DuruhaInkwell(
              onTap: () =>
                  _showSetDispatchDateDialog(context, needsDispatchOrders),
              variation: InkwellVariation.brand,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${needsDispatchOrders.length} order${needsDispatchOrders.length > 1 ? 's' : ''} need dispatch date',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 160,
                            child: DuruhaGlidingIconBadge(
                              text: 'SET DISPATCH DATE',
                              icon: Icons.local_shipping_rounded,
                              baseColor: Colors.white38,
                              highlightColor: Colors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Order Overview ──────────────────────────────────────────────
          if (_orders.isNotEmpty) ...[
            DuruhaSectionContainer(
              title: 'Overview',
              padding: const EdgeInsets.all(14),
              children: [
                Row(
                  children: [
                    buildQualityStat(
                      'Saver',
                      saverKg,
                      DuruhaColorHelper.getColor(context, 'saver'),
                    ),
                    buildQualityStat(
                      'Regular',
                      regularKg,
                      DuruhaColorHelper.getColor(context, 'regular'),
                    ),
                    buildQualityStat(
                      'Select',
                      selectKg,
                      DuruhaColorHelper.getColor(context, 'select'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: statusCounts.entries.map((e) {
                    final chipColor = DeliveryStatus.getStatusColor(
                      e.key.toLowerCase(),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
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
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: chipColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            '${e.key}  ${e.value}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: chipColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (pendingPaymentCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.onErrorContainer,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$pendingPaymentCount order${pendingPaymentCount > 1 ? 's' : ''} pending payment',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
          ],

          // ── Financials summary ──────────────────────────────────────────
          if (_detail != null) ...[
            DuruhaSectionContainer(
              title: 'Financials',
              padding: const EdgeInsets.all(14),
              children: [
                Row(
                  children: [
                    _buildSummaryStat(
                      'Active Value',
                      DuruhaFormatter.formatCurrency(_detail!.activeTotal),
                      theme,
                    ),
                    _buildSummaryStat(
                      'Total Earnings',
                      DuruhaFormatter.formatCurrency(
                        _detail!.farmerTotalEarnings,
                      ),
                      theme,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // ── Orders list ─────────────────────────────────────────────────
          DuruhaSectionContainer(
            title: 'Scheduled Orders',
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: [
              if (_isLoading)
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
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders scheduled yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New orders will appear here once customers start reserving your produce.',
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
      title: 'Update ${editableOrders.length} Orders',
      message: 'Set a new status for all editable orders in this offer.',
      confirmText: 'UPDATE STATUS',
      icon: Icons.edit_note_rounded,
      extraContentBuilder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DuruhaSelectionChipGroup(
              title: 'Delivery Status',
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
    ).then((confirmed) async {
      if (confirmed == true) {
        if (!mounted) return;
        setState(() => _isLoading = true);
        final orderIds = editableOrders
            .map((e) => e.offerOrderMatchId)
            .toList();
        final result = await _repository.updateOfferOrders(
          offerId: _offer.offerId,
          orderIds: orderIds,
          deliveryStatus: selectedStatus,
        );
        if (!mounted || !context.mounted) return;
        final isError = result == null || result.startsWith('Error');
        if (!isError) {
          DuruhaSnackBar.showSuccess(
            context,
            'Successfully updated ${orderIds.length} orders.',
          );
          _fetchDetail(showLoading: false);
        } else {
          DuruhaSnackBar.showError(
            context,
            result ?? 'Failed to update orders.',
          );
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _showSetDispatchDateDialog(
    BuildContext context,
    List<FarmerOfferOrder> targetOrders,
  ) async {
    final theme = Theme.of(context);
    DateTime? initialDateRaw = targetOrders.length == 1
        ? targetOrders.first.dispatchAt
        : null;
    if (initialDateRaw != null && initialDateRaw.year >= 2100) {
      initialDateRaw = null;
    }
    DateTime? selectedDispatchAt = initialDateRaw;

    await DuruhaDialog.show(
      context: context,
      title: 'Set Dispatch Date',
      message:
          'Update dispatch date for ${targetOrders.length == 1 ? 'this order' : '${targetOrders.length} orders'}:',
      confirmText: 'SET DATE',
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
                        'Reserved (${DuruhaRandomNameGenerator.generate(idSeed: idx.toString())})';
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
                              '${idx + 1}',
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
                          ? 'Select Date'
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
        if (!mounted) return;
        setState(() => _isLoading = true);
        final orderIds = targetOrders.map((e) => e.offerOrderMatchId).toList();
        final result = await _repository.updateOfferOrders(
          offerId: _offer.offerId,
          orderIds: orderIds,
          dispatchAt: selectedDispatchAt,
        );
        if (!mounted || !context.mounted) return;
        final isError = result == null || result.startsWith('Error');
        if (!isError) {
          DuruhaSnackBar.showSuccess(
            context,
            'Successfully set dispatch date for ${orderIds.length} orders.',
          );
          _fetchDetail(showLoading: false);
        } else {
          DuruhaSnackBar.showError(
            context,
            result ?? 'Failed to set dispatch date.',
          );
          setState(() => _isLoading = false);
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

    // Optimistic update
    setState(() {
      final updated = List<FarmerOfferOrder>.from(_orders);
      updated[orderIndex] = oldOrder.copyWith(deliveryStatus: newStatus);
      _detail = _detail?.copyWithOrders(orders: updated);
    });

    final result = await _repository.updateOfferOrders(
      offerId: _offer.offerId,
      orderIds: [orderId],
      deliveryStatus: newStatus,
    );
    if (!mounted) return;

    final isError = result == null || result.startsWith('Error');
    if (!isError) {
      _originalStatuses[orderId] = newStatus;
      DuruhaSnackBar.showSuccess(
        context,
        'Status → ${newStatus.replaceAll('_', ' ')}',
      );
      _fetchDetail(showLoading: false);
    } else {
      // Revert optimistic update
      final currentIndex = _orders.indexWhere(
        (o) => o.offerOrderMatchId == orderId,
      );
      if (currentIndex != -1) {
        setState(() {
          final reverted = List<FarmerOfferOrder>.from(_orders);
          reverted[currentIndex] = oldOrder;
          _detail = _detail?.copyWithOrders(orders: reverted);
        });
      }
      DuruhaSnackBar.showError(context, result ?? 'Failed to update status');
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
      title: 'Change Status?',
      message:
          'Update order to ${newStatus.replaceAll('_', ' ').toUpperCase()}?',
      confirmText: 'UPDATE',
      confirmColor: DeliveryStatus.getStatusColor(newStatus),
    );
    if (confirmed != true) return;

    final orderId = order.offerOrderMatchId;
    if (_originalStatuses[orderId] != newStatus) {
      await _updateStatus(orderId, newStatus);
    }
  }

  // ── Order row ─────────────────────────────────────────────────────────────
  Widget _buildOrderRow(
    BuildContext context,
    FarmerOfferOrder order,
    int orderNumber,
  ) {
    final theme = Theme.of(context);
    final currentStatus = order.deliveryStatus ?? DeliveryStatus.pending;
    final statusColor = DeliveryStatus.getStatusColor(currentStatus);
    final displayName =
        order.consumerName ??
        'Reserved (${DuruhaRandomNameGenerator.generate(idSeed: (orderNumber - 1).toString())})';

    final bool isCancelled =
        currentStatus.toUpperCase() == DeliveryStatus.cancelled;

    final card = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCancelled
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
              : statusColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: index + name + quality
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$orderNumber',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order.quality != null)
                  _buildMiniChip(
                    theme,
                    order.quality!,
                    _qualityColor(order.quality!),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dates row
                Row(
                  children: [
                    _buildCompactDateTile(
                      theme,
                      label: 'NEEDED BY',
                      date: order.dateNeeded ?? order.createdAt,
                      icon: Icons.event_available_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isCancelled
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.block_flipped,
                                    size: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 5),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'DISPATCH',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        'NOT INCLUDED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : order.needsDispatchSetup
                          ? DuruhaInkwell(
                              onTap: () =>
                                  _showSetDispatchDateDialog(context, [order]),
                              variation: InkwellVariation.brand,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DuruhaGlidingIconBadge(
                                  text: 'SET DISPATCH',
                                  icon: Icons.local_shipping_rounded,
                                  baseColor: Colors.white38,
                                  highlightColor: Colors.amberAccent,
                                ),
                              ),
                            )
                          : _buildCompactDateTile(
                              theme,
                              label: 'DISPATCH',
                              date: order.dispatchAt!,
                              icon: Icons.local_shipping_outlined,
                              onTap: () =>
                                  _showSetDispatchDateDialog(context, [order]),
                            ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Please Dispatch by ${order.dateNeeded?.difference(DateTime.now().add(const Duration(days: 2))).inDays} days",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatusScroller(context, order),
                const SizedBox(height: 10),

                // Financials row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DuruhaFormatter.formatCurrency(
                            order.farmerPayout * order.quantity,
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${DuruhaFormatter.formatNumber(order.quantity)} kg'
                          '${order.price > 0 ? ' @ ${DuruhaFormatter.formatCurrency(order.price)}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    _buildPaymentChip(order.farmerIsPaid),
                  ],
                ),

                if (order.carrierName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.carrierName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],

                if (order.consumerAddress != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (order.consumerAddress!.addressLine1 != null &&
                                  order.consumerAddress!.addressLine2 != null)
                                Text(
                                  '${order.consumerAddress!.addressLine1} ${order.consumerAddress!.addressLine2}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              Text(
                                [
                                      order.consumerAddress!.city,
                                      order.consumerAddress!.province,
                                      order.consumerAddress!.postalCode,
                                    ]
                                    .where((p) => p != null && p.isNotEmpty)
                                    .join(', '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              if (order.consumerAddress!.landmark != null &&
                                  order.consumerAddress!.landmark!.isNotEmpty)
                                Text(
                                  'Near: ${order.consumerAddress!.landmark}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (order.produceNote != null &&
                    order.produceNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.produceNote!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (isCancelled) {
      return Opacity(
        opacity: 0.75,
        child: AbsorbPointer(absorbing: true, child: card),
      );
    }
    return card;
  }

  Widget _buildCompactDateTile(
    ThemeData theme, {
    required String label,
    required DateTime date,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                DuruhaFormatter.formatDate(date).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap != null) return DuruhaInkwell(onTap: onTap, child: tile);
    return tile;
  }

  Color _qualityColor(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('saver')) {
      return DuruhaColorHelper.getColor(context, 'saver');
    }
    if (q.contains('select') || q.contains('premium')) {
      return DuruhaColorHelper.getColor(context, 'select');
    }
    return DuruhaColorHelper.getColor(context, 'regular');
  }

  Widget _buildMiniChip(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

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
            isPaid ? 'PAID' : 'INCOMING',
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

  Widget _buildStatusScroller(BuildContext context, FarmerOfferOrder order) {
    final theme = Theme.of(context);
    final currentStatus = order.deliveryStatus ?? DeliveryStatus.pending;
    final statusColor = DeliveryStatus.getStatusColor(currentStatus);
    final bool isCancelled =
        currentStatus.toUpperCase() == DeliveryStatus.cancelled;

    return Material(
      color: isCancelled
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : statusColor.withValues(alpha: 0.07),
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(8),
      child: DuruhaPopupMenu<String>(
        items: isCancelled ? [] : DeliveryStatus.farmerEditable,
        selectedValue: currentStatus,
        isTextOnly: true,
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
              if (!isCancelled)
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
          isInfinity ? 'Supply Lasts' : DateFormat('MMM d, yyyy').format(date),
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
      return days == 0 ? 'Starting tomorrow' : 'Starting in $days days';
    }
    if (offer.availableTo.year >= 2100) return 'Available until supply lasts';
    if (now.isAfter(offer.availableTo)) return 'Offer has expired';
    final daysLeft = offer.availableTo.difference(now).inDays;
    return '$daysLeft day${daysLeft != 1 ? 's' : ''} remaining';
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
