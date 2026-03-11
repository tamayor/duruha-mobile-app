import 'package:duruha/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:duruha/core/widgets/badge/duruha_delivery_status_badge.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/widgets/text/duruha_text_waiting.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/services/hitpay_service.dart';
import '../data/orders_repository.dart';
import '../domain/order_details_model.dart';
import '../../../../../core/constants/delivery_statuses.dart';

class OrderDetailsScreen extends StatefulWidget {
  final ConsumerOrderMatch? match;
  final String? orderId;
  final String? action;
  final PlaceOrderResult? placeOrderResult;

  const OrderDetailsScreen({
    super.key,
    this.match,
    this.orderId,
    this.action,
    this.placeOrderResult,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late ConsumerOrderMatch _match;
  bool _isLoading = false;
  bool _hasError = false;
  final _repo = OrdersRepository();

  bool _compactProduce = true;
  bool _compactGroup = true;
  final Set<int> _produceManualToggles = {};
  final Set<String> _groupManualToggles = {};

  // Tracks the mutable note JSON string for in-screen edits.
  late String _currentNote;

  // Tracks per-produce notes (cop.note) keyed by copId, populated from SQL.
  final Map<String, String> _produceNotes = {};

  @override
  void initState() {
    super.initState();
    // HitPayService listener is now initialized globally in main.dart
    if (widget.match != null) {
      _match = widget.match!;
      _currentNote = _match.note ?? '';
      _populateProduceNotes(_match);
      if (_isSummaryMatch(_match)) _fetchFullDetails(_match.offerOrderMatchId);
    } else if (widget.orderId != null) {
      _isLoading = true;
      _currentNote = '';
      _fetchFullDetails(widget.orderId!);
    } else {
      _hasError = true;
      _currentNote = '';
    }
  }

  void _populateProduceNotes(ConsumerOrderMatch match) {
    for (final item in match.produceItems) {
      final key = item.copId ?? 'produce-${item.itemIndex}';
      _produceNotes[key] = item.note ?? '';
    }
  }

  bool _isSummaryMatch(ConsumerOrderMatch match) =>
      match.produceItems.isEmpty ||
      match.produceItems.every((item) => item.varieties.isEmpty);

  Future<void> _fetchFullDetails(String orderId) async {
    if (!_isLoading && mounted) setState(() => _isLoading = true);
    try {
      final fullMatch = await _repo.fetchOrderDetails(orderId);
      if (mounted) {
        setState(() {
          _match = fullMatch;
          _currentNote = fullMatch.note ?? '';
          _populateProduceNotes(fullMatch);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [FETCH DETAILS ERROR]: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  double _selectionSubtotal(VarietySelection vg, bool isPriceLock) {
    double unitPrice = vg.dtcPrice ?? 0.0;
    if (vg.finalPrice != null && vg.finalPrice! > 0) {
      unitPrice = vg.finalPrice!;
    } else if (isPriceLock && vg.priceLock != null) {
      unitPrice = vg.priceLock!;
    }
    return vg.quantity * unitPrice;
  }

  /// A variety was NOT chosen if quantity==0 AND no dispatch/carrier info
  bool _isUnchosenVariety(VarietySelection v) =>
      (v.quantity == 0) && v.dispatchDate == null && v.carrierName == null;

  Widget _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return Text('N/A');
    try {
      final date = DateTime.parse(raw);
      if (date.difference(DateTime.now()).inDays >= 365) {
        return DuruhaWaitingText();
      }
      return Text(DateFormat('MMM dd, yyyy').format(date));
    } catch (_) {
      return Text(raw);
    }
  }

  Widget _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return Text('N/A');
    try {
      final date = DateTime.parse(raw);
      if (date.difference(DateTime.now()).inDays >= 365) {
        return DuruhaWaitingText();
      }
      return Text(DateFormat('MMM dd, yyyy • hh:mm a').format(date));
    } catch (_) {
      return Text(raw.toString());
    }
  }

  Color _statusColor(String? status, ThemeData t) {
    if (status == null || status.isEmpty) return t.colorScheme.onSurface;
    if (status.toUpperCase() == 'IN TRANSIT') return Colors.blue;
    return DeliveryStatus.getStatusColor(status);
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isLoading) {
      return const DuruhaScaffold(
        appBarTitle: "Order Details",
        body: ConsumerLoadingScreen(),
      );
    }

    if (_hasError) {
      return DuruhaScaffold(
        appBarTitle: "Order Details",
        body: const Center(child: Text("Failed to load order details.")),
        onBackPressed: () => Navigator.pop(context),
      );
    }

    return PopScope(
      canPop:
          widget.action != 'new' ||
          _match.paymentMethod.toLowerCase() == 'cash',
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Navigation is disabled for new orders
      },
      child: DuruhaScaffold(
        appBarTitle: "Order Details",
        showBackButton: true,
        appBarActions: [
          if (widget.action == 'new' &&
              _match.paymentMethod.toLowerCase() != 'cash')
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: cs.error,
              onPressed: () => _handleDelete(context),
            ),
          // ── Cancel Order popup ──
          if (_match.isActive && _match.isCancellable && widget.action != 'new')
            DuruhaPopupMenu<String>(
              items: const ['Cancel Order'],
              labelBuilder: (item) => item,
              itemIcons: const {'Cancel Order': Icons.cancel_outlined},
              tooltip: 'Order Actions',
              showLabel: false,
              showBackground: false,
              icon: Icon(Icons.more_vert, color: cs.onError),
              iconColor: cs.error,
              onSelected: (item) {
                if (item == 'Cancel Order') _handleCancelOrder(context);
              },
            ),
          DuruhaPopupMenu<String>(
            items: const ['Compact Produce', 'Compact Groups'],
            labelBuilder: (item) => item,
            itemIcons: {
              'Compact Produce': _compactProduce
                  ? Icons.layers
                  : Icons.layers_outlined,
              'Compact Groups': _compactGroup
                  ? Icons.group_work
                  : Icons.group_work_outlined,
            },
            tooltip: 'View Options',
            showLabel: false,
            showBackground: false,
            icon: Icon(Icons.tune, color: cs.onPrimary),
            onSelected: (item) {
              setState(() {
                if (item == 'Compact Produce') {
                  _compactProduce = !_compactProduce;
                  _produceManualToggles.clear();
                } else if (item == 'Compact Groups') {
                  _compactGroup = !_compactGroup;
                  _groupManualToggles.clear();
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
        onBackPressed: () => Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/consumer/manage', (route) => false),
        floatingActionButton:
            (widget.action == 'new' && _match.paymentMethod.isEmpty ||
                _match.paymentMethod.toLowerCase() == 'not paid' &&
                    _match.isActive)
            ? FloatingActionButton.extended(
                onPressed: () => _showPaymentSelectionDialog(),
                label: const Text("Pay Now"),
                icon: const Icon(Icons.payment),
              )
            : null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Payment Success Banner ───────────────────────────────────────
              if (widget.action == 'payment-success')
                _paymentSuccessBanner(theme, cs),
              const SizedBox(height: 24),
              // ── Order Fulfillment Details (shown only for new orders) ──────────
              if (widget.placeOrderResult != null) ...[
                _fulfillmentBanner(theme, cs, widget.placeOrderResult!),
                const SizedBox(height: 24),
              ],
              _sectionHeader(theme, "Information", cs.onPrimary),
              _infoCard(theme, cs),
              const SizedBox(height: 24),
              _sectionHeader(theme, "Order Summary", cs.onPrimary),
              _orderSummaryFolder(theme, cs),
              const SizedBox(height: 24),
              _sectionHeader(theme, "Produce Items", cs.onPrimary),
              ..._match.produceItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                return _produceCard(context, theme, cs, p, idx);
              }),
              const SizedBox(height: 24),
              _grandTotal(theme, cs),
              const SizedBox(height: 80), // Extra space for FAB
            ],
          ),
        ),
      ),
    );
  }

  // ─── info card ────────────────────────────────────────────────────────────

  Widget _infoCard(ThemeData t, ColorScheme cs) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
    ),
    child: Column(
      children: [
        _row(
          t,
          "Order ID",
          Text(
            _match.order.orderId.toString(),
            style: t.textTheme.bodyMedium?.copyWith(
              color: cs.onSecondary,
              fontSize: 10,
            ),
          ),
          icon: Icons.confirmation_number_outlined,
          small: true,
        ),
        _row(
          t,
          "Date",
          _formatDateTime(_match.createdAt),
          icon: Icons.calendar_today,
          small: true,
        ),
        _row(
          t,
          "Status",
          _match.isActive
              ? Text(
                  "ACTIVE",
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DuruhaColorHelper.completedLight,
                  ),
                )
              : Text(
                  "INACTIVE",
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.error,
                  ),
                ),
          icon: Icons.info_outline,
        ),
        if (_match.isPlan)
          _row(
            t,
            "Mode",
            _tag(
              t,
              "📅 PLAN ORDER",
              cs.secondaryContainer,
              cs.onSecondaryContainer,
              bold: true,
            ),
            icon: Icons.auto_awesome_outlined,
          ),
        if (_match.stats != null) ...[
          const Divider(height: 20),
          _row(
            t,
            "Linked Items",
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tag(
                  t,
                  "${_match.stats!.paidCount} Paid",
                  DuruhaColorHelper.completedLight,
                  Colors.white,
                  small: true,
                  bold: true,
                ),
                const SizedBox(width: 4),
                _tag(
                  t,
                  "${_match.stats!.unpaidCount} Unpaid",
                  cs.error,
                  Colors.white,
                  small: true,
                  bold: true,
                ),
              ],
            ),
            icon: Icons.check_circle_outline,
            small: true,
          ),
          if (_match.stats!.statusCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _match.stats!.statusCounts.entries.map((e) {
                  return _tag(
                    t,
                    "${e.value} ${e.key}",
                    _statusColor(e.key, t),
                    Colors.white,
                    small: true,
                    bold: true,
                  );
                }).toList(),
              ),
            ),
        ],
        const Divider(height: 16),
        InkWell(
          onTap: () => _match.isActive ? _editOrderNote(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note_outlined, size: 15, color: cs.onPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: _currentNote.isNotEmpty
                      ? Text(
                          _currentNote,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          'Add order note...',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
                Icon(
                  _match.isActive ? Icons.edit_outlined : Icons.lock_outlined,
                  size: 13,
                  color: _match.isActive ? cs.onSecondary : cs.error,
                ),
              ],
            ),
          ),
        ),
        if (_match.paymentMethod.isNotEmpty)
          _row(
            t,
            "Payment",
            Text(_match.paymentMethod),
            icon: Icons.account_balance_wallet_outlined,
            small: true,
          ),
        if (_match.cpsId != null)
          InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              '/consumer/subscriptions/plan_details',
              arguments: _match.cpsId,
            ),
            child: _row(
              t,
              "Subscription Plan",
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "View Plan",
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: cs.onSecondaryContainer,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: cs.onSecondaryContainer,
                  ),
                ],
              ),
              icon: Icons.card_membership_outlined,
              small: true,
            ),
          ),
      ],
    ),
  );

  // ─── produce card ─────────────────────────────────────────────────────────

  // ─── order summary folder ─────────────────────────────────────────────────

  Widget _orderSummaryFolder(ThemeData t, ColorScheme cs) {
    if (_match.produceItems.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: t.copyWith(dividerColor: Colors.transparent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _match.produceItems
              .where(
                (item) =>
                    _match.isPlan ||
                    item.varieties.fold(
                          0.0,
                          (s, v) => s + v.allocatedQuantity,
                        ) >
                        0 ||
                    item.varieties.isNotEmpty,
              )
              .toList()
              .asMap()
              .entries
              .map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isLast = item == _match.produceItems.last;
                return _buildProduceFolderNode(t, cs, item, isLast, idx);
              })
              .toList(),
        ),
      ),
    );
  }

  // Added global keys for scrolling
  final Map<int, GlobalKey> _produceKeys = {};

  Widget _buildProduceFolderNode(
    ThemeData t,
    ColorScheme cs,
    ProduceItem item,
    bool isLastItem,
    int idx, // filtered list position (for display only)
  ) {
    return Theme(
      data: t.copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "#${item.itemIndex + 1}",
              style: t.textTheme.labelSmall?.copyWith(
                color: item.isDone
                    ? DuruhaColorHelper.completedLight
                    : cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.folder_open_outlined, color: cs.onSecondary, size: 22),
          ],
        ),
        title: Text(
          item.produceDialectName,
          style: t.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        subtitle: _match.isActive
            ? Row(
                children: [
                  Builder(
                    builder: (context) {
                      final requested = item.varieties.fold(
                        0.0,
                        (s, v) => s + v.quantity,
                      );
                      final allocated = item.varieties.fold(
                        0.0,
                        (s, v) => s + v.allocatedQuantity,
                      );
                      final isPending = allocated == 0 && !_match.isPlan;
                      return Text(
                        isPending
                            ? "${requested.toStringAsFixed(0)} kg (pending)"
                            : allocated < requested
                            ? "${allocated.toStringAsFixed(0)}/${requested.toStringAsFixed(0)} kg"
                            : "${requested.toStringAsFixed(0)} kg",
                        style: t.textTheme.labelSmall?.copyWith(
                          color: isPending
                              ? DuruhaColorHelper.pendingLight
                              : cs.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                  if (item.isDone) ...[
                    const SizedBox(width: 8),
                    _tag(
                      t,
                      "DONE",
                      DuruhaColorHelper.getColor(context, "COMPLETED"),
                      Colors.white,
                      small: true,
                      bold: true,
                    ),
                  ],
                ],
              )
            : Text(
                "Archived",
                style: t.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
        children: [
          Container(
            padding: const EdgeInsets.only(left: 36, right: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: item.varieties.map((group) {
                // ── Group header ─────────────────────────────────────────────
                final groupHeader = Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_work,
                        size: 14,
                        color: cs.onSecondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "#${group.index + 1}",
                        style: t.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Price label badge from SQL
                      _priceLabelTag(t, cs, group.priceLabel ?? "-"),
                    ],
                  ),
                );

                // ── Any-variety group with no allocations yet (pending) ──────
                // varietyGroups is empty only when all cov rows were OPEN (filtered by SQL)
                if (group.isAny && group.varietyGroups.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      groupHeader,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right,
                              size: 16,
                              color: cs.outline,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '∞ Any Variety',
                              style: t.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${group.quantity.toStringAsFixed(0)} kg',
                              style: t.textTheme.labelSmall?.copyWith(
                                color: DuruhaColorHelper.pendingLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }

                // ── Specific or partially-matched any-variety group ──────────
                // varietyGroups contains only non-OPEN rows (MATCHED/PLEDGED/DENIED/SKIPPED)
                final displayItems = group.varietyGroups;
                if (displayItems.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    groupHeader,
                    // Items in this group
                    ...displayItems.map((v) {
                      final String selType = v.selectionType.toUpperCase();
                      final bool isMatched = selType == 'MATCHED';
                      final bool isPledged = selType == 'PLEDGED';
                      final bool isSkipped = selType == 'SKIPPED';
                      final bool isDenied = selType == 'DENIED';
                      final bool lowOpacity = isSkipped || isDenied;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            final key = _produceKeys[idx];
                            if (key != null && key.currentContext != null) {
                              Scrollable.ensureVisible(
                                key.currentContext!,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.subdirectory_arrow_right,
                                  size: 16,
                                  color: cs.outline,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Opacity(
                                            opacity: lowOpacity ? 0.4 : 1.0,
                                            child: Text(
                                              v.name ??
                                                  (group.isAny
                                                      ? 'Any Variety'
                                                      : 'Any'),
                                              style: t.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: cs.onSurface,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            (isMatched || isPledged)
                                                ? "${v.quantity.toStringAsFixed(0)} kg"
                                                : "—",
                                            style: t.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (isMatched) ...[
                                            Opacity(
                                              opacity:
                                                  (v.deliveryStatus ==
                                                          'CANCELLED' &&
                                                      !v.isPaid)
                                                  ? 0.4
                                                  : 1.0,
                                              child: _tag(
                                                t,
                                                v.isPaid ? 'PAID' : 'UNPAID',
                                                v.isPaid
                                                    ? DuruhaColorHelper
                                                          .completedLight
                                                    : cs.errorContainer,
                                                Colors.white,
                                                small: true,
                                                bold: true,
                                              ),
                                            ),
                                            if (v.deliveryStatus != null)
                                              _tag(
                                                t,
                                                v.deliveryStatus!,
                                                _statusColor(
                                                  v.deliveryStatus,
                                                  t,
                                                ),
                                                Colors.white,
                                                small: true,
                                                bold: true,
                                              )
                                            else
                                              _tag(
                                                t,
                                                "PENDING MATCH",
                                                DuruhaColorHelper.pendingLight,
                                                Colors.white,
                                                small: true,
                                                bold: true,
                                              ),
                                          ] else
                                            _selectionTypeTag(
                                              t,
                                              cs,
                                              v.selectionType,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              }).toList(),
            ),
          ),
          if (!isLastItem)
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  Widget _produceCard(
    BuildContext ctx,
    ThemeData t,
    ColorScheme cs,
    ProduceItem item,
    int idx,
  ) {
    _produceKeys[idx] ??= GlobalKey();

    final double total = item.varieties.fold(
      0.0,
      (s, v) => s + v.varietySubtotal(item.isPriceLock),
    );
    final double delivery = item.varieties.fold(
      0.0,
      (s, v) =>
          s +
          v.varietyGroups.fold(0.0, (gs, vg) {
            if (vg.deliveryStatus == 'CANCELLED') return gs;
            return gs + (vg.deliveryFee ?? 0);
          }),
    );
    final double subtotal = total + delivery;
    final bool tentative = !item.isPriceFinalized;

    final bool isProduceCollapsed =
        _compactProduce ^ _produceManualToggles.contains(idx);

    return Card(
      key: _produceKeys[idx],
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () {
              setState(() {
                if (_produceManualToggles.contains(idx)) {
                  _produceManualToggles.remove(idx);
                } else {
                  _produceManualToggles.add(idx);
                }
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "#${item.itemIndex + 1}",
                            style: t.textTheme.labelSmall?.copyWith(
                              color: item.isDone
                                  ? DuruhaColorHelper.completedLight
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.produceImageUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(item.produceImageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.produceEnglishName,
                                  style: t.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                if (item.produceLocalName != null)
                                  Text(
                                    item.produceLocalName!,
                                    style: t.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.isDone)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _tag(
                                t,
                                "DONE",
                                DuruhaColorHelper.completedLight,
                                Colors.white,
                                small: true,
                                bold: true,
                              ),
                            ),
                          DuruhaStatusBadge(
                            label: item.quality,
                            strikethrough: item.isCancelled,
                            color: DuruhaColorHelper.getColor(
                              context,
                              item.quality,
                            ),
                            isOutlined: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: -10,
                  top: -10,
                  child: Center(
                    child: Icon(
                      isProduceCollapsed
                          ? Icons.expand_more
                          : Icons.expand_less,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Per-produce note ──
          _produceNoteRow(ctx, t, cs, item),
          if (!isProduceCollapsed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // variety groups
                  ...item.varieties.asMap().entries.map(
                    (e) => _varGroupCard(
                      ctx,
                      t,
                      cs,
                      item,
                      e.value,
                      e.key,
                      item.itemIndex,
                      item.copId,
                    ),
                  ),
                ],
              ),
            ),
            // subtotal footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Produce Subtotal",
                          style: t.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "(${DuruhaFormatter.formatCurrency(total)} variety) + (${DuruhaFormatter.formatCurrency(delivery)} shipping)",
                          style: t.textTheme.labelSmall?.copyWith(
                            color: cs.onSecondary,
                            fontSize: 10,
                          ),
                        ),
                        if (tentative)
                          Text(
                            "Pending market updates",
                            style: t.textTheme.labelSmall?.copyWith(
                              color: DuruhaColorHelper.pendingLight,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DuruhaFormatter.formatCurrency(subtotal),
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── per-produce note row ─────────────────────────────────────────────────

  Widget _produceNoteRow(
    BuildContext ctx,
    ThemeData t,
    ColorScheme cs,
    ProduceItem item,
  ) {
    final noteKey = item.copId ?? 'produce-${item.itemIndex}';
    final existingNote = _produceNotes[noteKey] ?? '';

    return InkWell(
      onTap: () => _match.isActive
          ? _editProduceNote(ctx, item, noteKey, existingNote)
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.edit_note_rounded, size: 14, color: cs.onSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: existingNote.isNotEmpty
                  ? Text(
                      existingNote,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Text(
                      'Add note...',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),
            Icon(
              _match.isActive ? Icons.edit_outlined : Icons.lock_outlined,
              size: 13,
              color: _match.isActive ? cs.onSecondary : cs.error,
            ),
          ],
        ),
      ),
    );
  }

  // ─── variety group card ───────────────────────────────────────────────────
  // Each covg becomes its own bordered card with metadata tags at the top

  Widget _varGroupCard(
    BuildContext ctx,
    ThemeData t,
    ColorScheme cs,
    ProduceItem item,
    ProduceVariety group,
    int idx,
    int produceIdx,
    String? copId,
  ) {
    final bool isPriceLock =
        group.isPriceLock || group.varietyGroups.any((v) => v.isPriceLock);
    final bool isAny = group.isAny;
    final bool isPlan = _match.isPlan;
    final double subtotal = group.varietySubtotal(item.isPriceLock);

    final String groupKey = '${produceIdx}_$idx';
    final bool isGroupExpanded =
        !(_compactGroup ^ _groupManualToggles.contains(groupKey));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlan
              ? cs.secondary.withValues(alpha: 0.35)
              : isPriceLock
              ? cs.primary.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: isPlan || isPriceLock ? 1.5 : 1,
        ),
        color: isPlan
            ? cs.secondaryContainer.withValues(alpha: 0.08)
            : isPriceLock
            ? cs.primaryContainer.withValues(alpha: 0.04)
            : cs.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── group header ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    if (_groupManualToggles.contains(groupKey)) {
                      _groupManualToggles.remove(groupKey);
                    } else {
                      _groupManualToggles.add(groupKey);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              // quantity
                              _tag(
                                t,
                                '${DuruhaFormatter.formatCompactNumber(group.quantity)} kg',
                                cs.tertiaryContainer,
                                cs.onTertiaryContainer,
                                bold: true,
                              ),
                              const SizedBox(width: 6),
                              // form
                              if (group.form.isNotEmpty)
                                _tag(
                                  t,
                                  group.form,
                                  cs.secondaryContainer,
                                  cs.onSecondaryContainer,
                                ),
                              // plan badge
                              if (isPlan)
                                _tag(
                                  t,
                                  '📅 Plan',
                                  cs.secondaryContainer,
                                  cs.onSecondaryContainer,
                                  bold: true,
                                )
                              // price lock
                              else if (isPriceLock)
                                _tag(
                                  t,
                                  "🔒 Price Lock",
                                  cs.surface,
                                  cs.onPrimary,
                                  bold: true,
                                ),
                              // flexible
                              if (isAny)
                                Builder(
                                  builder: (context) {
                                    final matchedNames = group.varietyGroups
                                        .where(
                                          (v) =>
                                              v.selectionType.toUpperCase() ==
                                                  'MATCHED' ||
                                              v.selectionType.toUpperCase() ==
                                                  'PLEDGED',
                                        )
                                        .map((v) => v.name ?? 'Any Variety')
                                        .toSet()
                                        .join(', ');

                                    return _tag(
                                      t,
                                      matchedNames.isNotEmpty
                                          ? "∞ $matchedNames"
                                          : "∞ Any Variety",
                                      cs.surface,
                                      cs.onTertiary,
                                    );
                                  },
                                ),
                              // algo picked label
                              if (!isAny && !isPriceLock && !isPlan)
                                _tag(
                                  t,
                                  "⚙ Specific",
                                  cs.surfaceContainerHighest,
                                  cs.onSurface,
                                ),
                            ],
                          ),
                        ],
                      ),
                      // tag row
                      const SizedBox(height: 8),
                      // date needed (date only, no time)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 13,
                                color: cs.onSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "Needed by ${DuruhaFormatter.formatDate(DateTime.parse(group.dateNeeded))}",
                                style: t.textTheme.labelSmall?.copyWith(
                                  color: cs.onSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (subtotal > 0)
                            Text(
                              "${isPlan ? '~' : ''}${DuruhaFormatter.formatCurrency(subtotal)}",
                              style: t.textTheme.labelSmall?.copyWith(
                                color: cs.onSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: -16,
                top: -13,
                child: Column(
                  children: [
                    Icon(
                      isGroupExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    Text(
                      "${idx + 1}",
                      style: t.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            group.varietyGroups.isNotEmpty &&
                                group.varietyGroups.every((v) => v.isPaid)
                            ? DuruhaColorHelper.completedLight
                            : cs.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isGroupExpanded) ...[
            const Divider(height: 1, thickness: 0.5),
            // ── varieties ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: group.varietyGroups.map((v) {
                  final bool unchosen = _isUnchosenVariety(v);
                  return _varietyRow(ctx, t, cs, item, group, v, unchosen);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── single variety row ───────────────────────────────────────────────────

  Widget _varietyRow(
    BuildContext ctx,
    ThemeData t,
    ColorScheme cs,
    ProduceItem item,
    ProduceVariety group,
    VarietySelection v,
    bool unchosen,
  ) {
    final bool isPriceLock = group.isPriceLock || v.isPriceLock;
    final bool hasDelivery = v.deliveryStatus != null;
    final bool isPlan = _match.isPlan;

    final bool cancelled = v.deliveryStatus == 'CANCELLED';
    final String selType = v.selectionType.toUpperCase();
    final bool skipped = selType == 'SKIPPED';
    final bool denied = selType == 'DENIED';
    final bool cancellable =
        !cancelled &&
        !unchosen &&
        v.oomId != null &&
        v.deliveryStatus != null &&
        _cancellableStatuses.contains(v.deliveryStatus);

    // Display name: null name on a plan row = Any Variety (assigned later)
    final String displayName = v.name ?? (isPlan ? 'Any Variety' : 'Any');

    final bool showUnitPrice = !isPlan && v.isPriceLock && v.finalPrice != null;

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.only(
        top: cancellable ? 20 : 10,
        left: 10,
        right: 10,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: (unchosen || skipped)
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (unchosen || skipped)
              ? cs.outlineVariant.withValues(alpha: 0.2)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // name + subtotal
          Opacity(
            opacity: cancelled ? 0.5 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Opacity(
                      opacity: (skipped || denied) ? 0.4 : 1.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DuruhaTextEmphasis(
                                text: displayName,
                                mainSize: 18,
                                mainColor: cs.onPrimary,
                                breaker: "()",
                                mainWeight: FontWeight.bold,
                                subSize: 10,
                                subColor: cs.onSecondary,
                              ),
                            ],
                          ),
                          if (showUnitPrice)
                            Text(
                              "Price Locked @ ${DuruhaFormatter.formatCurrency(v.finalPrice!)}",
                              style: t.textTheme.labelSmall?.copyWith(
                                color: cs.onSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (unchosen && !isPlan) ...[
                      const SizedBox(width: 6),
                      _tag(
                        t,
                        "Not chosen",
                        cs.errorContainer,
                        cs.error,
                        small: true,
                      ),
                    ] else ...[
                      const SizedBox(width: 6),
                      _selectionTypeTag(t, cs, v.selectionType),
                    ],
                  ],
                ),
                // Price total: hide for plan rows (price determined at fulfillment)
                const SizedBox(height: 6),
                if (!unchosen && !isPlan)
                  Text(
                    DuruhaFormatter.formatCurrency(
                      _selectionSubtotal(v, isPriceLock),
                    ),
                    style: t.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onTertiary,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
              ],
            ),
          ),

          if (!unchosen && !skipped && !denied) ...[
            const SizedBox(height: 6),

            // qty
            Opacity(
              opacity: cancelled ? 0.5 : 1.0,
              child: _row(
                t,
                "Quantity",
                Text(
                  "${v.quantity.toStringAsFixed(0)} kg",
                  style: TextStyle(
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                small: true,
              ),
            ),

            // ── pricing block — driven by SQL price_label ──
            ...[
              const SizedBox(height: 6),
              Opacity(
                opacity: cancelled ? 0.5 : 1.0,
                child: _pricingNote(ctx, t, cs, group, v, cancelled),
              ),

              // ── delivery block ──
              if (hasDelivery) ...[
                const SizedBox(height: 8),
                _deliveryBlock(ctx, t, cs, v),
              ] else ...[
                const SizedBox(height: 6),
                _statusNote(
                  t,
                  Icons.search,
                  "Searching for match...",
                  DuruhaColorHelper.pendingLight,
                ),
              ],
            ],

            const SizedBox(height: 6),
            Opacity(
              opacity: cancelled ? 0.5 : 1.0,
              child: _row(
                t,
                "Paid?",
                v.isPaid
                    ? Text(
                        "PAID",
                        style: t.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DuruhaColorHelper.completedLight,
                          decoration: cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      )
                    : Text(
                        "UNPAID",
                        style: t.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.error,
                          decoration: cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                icon: v.isPaid
                    ? Icons.check_circle_outline
                    : Icons.pending_outlined,
                small: true,
              ),
            ),

            const SizedBox(height: 6),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: (unchosen || skipped) ? 0.30 : 1.0,
      child: cancellable
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                cardContent,
                // ── macOS-style red close dot ──
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleCancelItem(ctx, v.oomId!),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5F57),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.close, size: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : cardContent,
    );
  }

  // ─── pricing note — driven by SQL price_label ─────────────────────────────

  Widget _pricingNote(
    BuildContext ctx,
    ThemeData t,
    ColorScheme cs,
    ProduceVariety group,
    VarietySelection v,
    bool cancelled,
  ) {
    final TextDecoration? strikethrough = cancelled
        ? TextDecoration.lineThrough
        : null;

    switch (v.priceLabel?.toLowerCase()) {
      case 'plan':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusNote(
              t,
              Icons.event_repeat_rounded,
              'Price determined at fulfillment',
              cs.onSurfaceVariant,
            ),
            if (v.deliveryStatus != null) ...[
              const SizedBox(height: 8),
              _deliveryBlock(ctx, t, cs, v),
            ],
          ],
        );

      case 'price_lock':
      case 'final' when (group.isPriceLock || v.isPriceLock):
        // Price-lock block: market price struck through, locked price highlighted
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Market",
                    style: t.textTheme.labelSmall?.copyWith(
                      color: cs.onSecondary,
                    ),
                  ),
                  Text(
                    DuruhaFormatter.formatCurrency(v.dtcPrice ?? 0),
                    style: t.textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: cs.onSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "🔒 Locked",
                    style: t.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onPrimary,
                    ),
                  ),
                  Text(
                    DuruhaFormatter.formatCurrency(
                      v.finalPrice ?? v.priceLock ?? 0,
                    ),
                    style: t.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onPrimary,
                      decoration: strikethrough,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 'final':
        return _statusNote(
          t,
          Icons.check_circle_outline,
          "Final: ${DuruhaFormatter.formatCurrency(v.finalPrice ?? 0)}",
          DuruhaColorHelper.completedLight,
          style: TextStyle(decoration: strikethrough),
        );

      case 'tentative':
        return _statusNote(
          t,
          Icons.help_outline,
          "Tentative: ${DuruhaFormatter.formatCurrency(v.dtcPrice ?? 0)}",
          DuruhaColorHelper.pendingLight,
          style: TextStyle(decoration: strikethrough),
        );

      case 'pending':
      default:
        return _statusNote(
          t,
          Icons.search,
          "Searching for match...",
          DuruhaColorHelper.pendingLight,
        );
    }
  }

  // ─── delivery block ───────────────────────────────────────────────────────

  Widget _deliveryBlock(
    BuildContext ctx,
    ThemeData t,
    ColorScheme cs,
    VarietySelection v,
  ) {
    final color = _statusColor(v.deliveryStatus, t);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  v.carrierName ?? "Carrier assigned",
                  style: t.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimary,
                  ),
                ),
              ),
              // status pill
              DuruhaStatusBadge(
                status: v.deliveryStatus,
                size: BadgeSize.small,
              ),
            ],
          ),
          if (v.dispatchDate != null) ...[
            const SizedBox(height: 6),
            _row(
              t,
              "Dispatch",
              v.deliveryStatus == 'CANCELLED'
                  ? Text(
                      'Not included',
                      style: t.textTheme.labelSmall?.copyWith(
                        color: cs.onSecondary,
                      ),
                    )
                  : _formatDate(v.dispatchDate),
              icon: Icons.schedule,
              small: true,
            ),
          ],
          if (v.deliveryFee != null && v.deliveryFee! > 0)
            _row(
              t,
              "Delivery Fee",
              Text(
                DuruhaFormatter.formatCurrency(v.deliveryFee ?? 0.0),
                style: TextStyle(
                  decoration: v.deliveryStatus == 'CANCELLED'
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              small: true,
            ),
          if (v.farmerLocation != null || v.consumerLocation != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),
            _locationRow(
              t,
              cs,
              icon: Icons.agriculture_outlined,
              label: "From (Farmer)",
              address: v.farmerLocation,
            ),
            if (v.consumerLocation != null) const SizedBox(height: 6),
            // _locationRow(
            //   t,
            //   cs,
            //   icon: Icons.home_outlined,
            //   label: "To (You)",
            //   address: v.consumerLocation,
            // ),
          ],
        ],
      ),
    );
  }

  Widget _locationRow(
    ThemeData t,
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required DeliveryAddress? address,
  }) {
    if (address == null) return const SizedBox.shrink();
    final line = address.displayLine;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
              Text(
                line.isNotEmpty ? line : '—',
                style: t.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (address.landmark != null && address.landmark!.isNotEmpty)
                Text(
                  'Near: ${address.landmark}',
                  style: t.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectionTypeTag(ThemeData t, ColorScheme cs, String type) {
    Color bg;
    Color fg;
    String label;

    switch (type.toUpperCase()) {
      case 'MATCHED':
        bg = cs.tertiary;
        fg = cs.onTertiary;
        label = "MATCHED";
        break;
      case 'PLEDGED':
        bg = DuruhaColorHelper.completedLight;
        fg = Colors.white;
        label = "PLEDGED";
        break;
      case 'SKIPPED':
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        label = "SKIPPED";
        break;
      case 'DENIED':
        bg = cs.error;
        fg = cs.onError;
        label = "DENIED";
        break;
      case 'CANCELLED':
        bg = cs.error;
        fg = cs.onError;
        label = "CANCELLED";
        break;
      case 'OPEN':
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        label = "OPEN";
    }

    return _tag(t, label, bg, fg, small: true, bold: true);
  }

  /// Badge for the SQL-computed price_label on a variety group.
  Widget _priceLabelTag(ThemeData t, ColorScheme cs, String label) {
    switch (label.toLowerCase()) {
      case 'final':
        return _tag(
          t,
          'FINAL',
          DuruhaColorHelper.completedLight,
          Colors.white,
          small: true,
          bold: true,
        );
      case 'price_lock':
        return _tag(
          t,
          '🔒 LOCKED',
          cs.primaryContainer,
          cs.onPrimaryContainer,
          small: true,
          bold: true,
        );
      case 'tentative':
        return _tag(
          t,
          'TENTATIVE',
          DuruhaColorHelper.pendingLight,
          Colors.white,
          small: true,
          bold: true,
        );
      case 'plan':
        return _tag(
          t,
          '📅 PLAN',
          cs.secondaryContainer,
          cs.onSecondaryContainer,
          small: true,
          bold: true,
        );
      case 'pending':
      default:
        return _tag(
          t,
          'PENDING',
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
          small: true,
          bold: true,
        );
    }
  }

  // ─── grand total ──────────────────────────────────────────────────────────

  Widget _grandTotal(ThemeData t, ColorScheme cs) {
    final bool tentative = !_match.isPriceFinalized;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tentative ? "Tentative" : "Grand Total",
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
                ),
              ),
              if (tentative)
                Text(
                  "Awaiting final pricing",
                  style: t.textTheme.labelSmall?.copyWith(
                    color: DuruhaColorHelper.pendingLight,
                  ),
                ),
            ],
          ),
          Text(
            DuruhaFormatter.formatCurrency(_match.totalAmount),
            style: t.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── reusable atoms ───────────────────────────────────────────────────────

  Widget _sectionHeader(ThemeData t, String title, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Align(
      alignment: Alignment.center,
      child: Text(
        title.toUpperCase(),
        style: t.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    ),
  );

  Widget _tag(
    ThemeData t,
    String label,
    Color bg,
    Color fg, {
    bool bold = false,
    bool small = false,
  }) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: small ? 6 : 8,
      vertical: small ? 1 : 3,
    ),
    decoration: BoxDecoration(
      color: bg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: t.textTheme.labelSmall?.copyWith(
        fontSize: small ? 9 : 11,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: fg,
      ),
    ),
  );

  Widget _statusNote(
    ThemeData t,
    IconData icon,
    String text,
    Color color, {
    TextStyle? style,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: t.textTheme.labelSmall
                ?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                )
                .merge(style),
          ),
        ),
      ],
    ),
  );

  Widget _row(
    ThemeData t,
    String label,
    Widget value, {
    IconData? icon,
    bool small = false,
  }) {
    final cs = t.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: cs.onPrimary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: t.textTheme.bodyMedium?.copyWith(
              color: cs.onSecondary,
              fontSize: small ? 10 : 14,
            ),
          ),
          const Spacer(),
          value,
        ],
      ),
    );
  }

  // ─── fulfillment banner (shown for new orders) ────────────────────────────

  Widget _fulfillmentBanner(
    ThemeData t,
    ColorScheme cs,
    PlaceOrderResult result,
  ) {
    final bool fullSuccess = result.success && result.failed == 0;
    final bool partial = result.matched > 0 && result.failed > 0;
    final Color bannerColor = fullSuccess
        ? DuruhaColorHelper.completedLight
        : (partial ? DuruhaColorHelper.pendingLight : cs.error);
    final IconData bannerIcon = fullSuccess
        ? Icons.check_circle_rounded
        : (partial ? Icons.warning_amber_rounded : Icons.cancel_rounded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bannerColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(bannerIcon, size: 36, color: bannerColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.message,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: bannerColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _miniStat(
                          t,
                          "${result.matched}",
                          "Matched",
                          DuruhaColorHelper.completedLight,
                        ),
                        const SizedBox(width: 16),
                        _miniStat(
                          t,
                          "${result.failed}",
                          "Failed",
                          result.failed > 0
                              ? DuruhaColorHelper.pendingLight
                              : cs.onSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Fulfillment Details ────────────────────────────────────────────
        if (result.selections.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            "FULFILLMENT DETAILS",
            style: t.textTheme.labelMedium?.copyWith(
              color: cs.onSecondary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ...result.selections.map((s) => _selectionTile(t, cs, s)),
        ],

        // ── Unfulfilled Items ───────────────────────────────────────────────
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            "UNFULFILLED ITEMS",
            style: t.textTheme.labelMedium?.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ...result.errors.map((e) => _errorTile(t, cs, e)),
        ],
      ],
    );
  }

  // ─── payment success banner ───────────────────────────────────────────────

  Widget _paymentSuccessBanner(ThemeData t, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DuruhaColorHelper.completedLight.withValues(alpha: 0.1),
            cs.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DuruhaColorHelper.completedLight.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DuruhaColorHelper.completedLight.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: DuruhaColorHelper.completedLight,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Thank you for supporting",
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DuruhaColorHelper.completedLight,
                  ),
                ),
                Text(
                  "the mission!",
                  style: t.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DuruhaColorHelper.completedLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _match.paymentMethod.toLowerCase() == 'cash'
                      ? "We'll collect payment upon delivery.\nSee you with the harvest! 🌾"
                      : "Your payment has been received.\nSee you with the harvest! 🌾",
                  style: t.textTheme.bodySmall?.copyWith(
                    color: DuruhaColorHelper.completedLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(ThemeData t, String value, String label, Color color) => Row(
    children: [
      Text(
        value,
        style: t.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: t.textTheme.labelSmall?.copyWith(color: color)),
    ],
  );

  Widget _selectionTile(
    ThemeData t,
    ColorScheme cs,
    OrderSelection s,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: s.chosen
          ? cs.primaryContainer.withValues(alpha: 0.2)
          : cs.surfaceContainerHighest.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: s.chosen ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.varietyName,
                style: t.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: s.chosen
                    ? cs.primary.withValues(alpha: 0.15)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.chosen ? "Selected" : "Skipped",
                style: t.textTheme.labelSmall?.copyWith(
                  color: s.chosen ? cs.primary : cs.onSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          s.reason,
          style: t.textTheme.bodySmall?.copyWith(color: cs.onSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 12, color: cs.onSecondary),
            const SizedBox(width: 4),
            Text(
              "${s.allocatedQty.toStringAsFixed(0)} kg",
              style: t.textTheme.labelSmall?.copyWith(color: cs.onSecondary),
            ),
            const SizedBox(width: 12),
            Icon(Icons.location_on_outlined, size: 12, color: cs.onSecondary),
            const SizedBox(width: 4),
            Text(
              "${s.distanceKm} km",
              style: t.textTheme.labelSmall?.copyWith(color: cs.onSecondary),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _errorTile(
    ThemeData t,
    ColorScheme cs,
    PlaceOrderError e,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: cs.errorContainer.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cs.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_outlined, size: 18, color: cs.error),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${e.form} — ${e.unfulfilledQty.toStringAsFixed(0)} kg unfulfilled",
                style: t.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.error,
                ),
              ),
              Text(
                e.reason,
                style: t.textTheme.labelSmall?.copyWith(color: cs.onSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ─── status pill (tappable for cancellable items) ───────────────────────

  static const _cancellableStatuses = [
    'PENDING',
    'ACCEPTED',
    'PREPARING',
    'READY_FOR_QC',
  ];

  // ─── note editing ─────────────────────────────────────────────────────────

  Future<void> _editOrderNote(BuildContext context) async {
    final controller = TextEditingController(text: _currentNote);

    final confirmed = await DuruhaDialog.show(
      context: context,
      title: 'Order Note',
      message: 'Add delivery instructions or special requests for this order.',
      icon: Icons.note_outlined,
      confirmText: 'Save',
      extraContentBuilder: (_) => TextField(
        controller: controller,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Delivery instructions, gift message…',
          border: OutlineInputBorder(),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final newNote = controller.text.trim();

    try {
      await _repo.updateOrderNote(_match.order.orderId, newNote);
      if (mounted) {
        setState(() => _currentNote = newNote);
        DuruhaSnackBar.showSuccess(context, 'Note updated');
      }
    } catch (e) {
      if (mounted) {
        DuruhaSnackBar.showError(context, 'Failed to update note: $e');
      }
    }
  }

  Future<void> _editProduceNote(
    BuildContext context,
    ProduceItem item,
    String noteKey,
    String currentNoteText,
  ) async {
    if (item.copId == null) return;
    final controller = TextEditingController(text: currentNoteText);

    final confirmed = await DuruhaDialog.show(
      context: context,
      title: 'Note for ${item.produceEnglishName}',
      message: 'Add a special request or note for this produce item.',
      icon: Icons.edit_note_rounded,
      confirmText: 'Save',
      extraContentBuilder: (_) => TextField(
        controller: controller,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Special requests for this item…',
          border: OutlineInputBorder(),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final newText = controller.text.trim();

    try {
      await _repo.updateOrderItemNote(
        _match.order.orderId,
        item.copId!,
        newText,
      );
      if (mounted) {
        setState(() => _produceNotes[noteKey] = newText);
        DuruhaSnackBar.showSuccess(context, 'Note updated');
      }
    } catch (e) {
      if (mounted) {
        DuruhaSnackBar.showError(context, 'Failed to update note: $e');
      }
    }
  }

  // ─── actions ──────────────────────────────────────────────────────────────

  Future<void> _handleCancelOrder(BuildContext context) async {
    final confirmed = await DuruhaDialog.show(
      context: context,
      title: "Cancel Order",
      message:
          "Are you sure you want to cancel this entire order? All active items will be cancelled. This action cannot be undone.",
      confirmText: "Cancel Order",
      isDanger: true,
    );
    if (confirmed == true && context.mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ConsumerLoadingScreen(),
        );
        await _repo.cancelOrderMatch(_match.orderId);
        if (context.mounted) {
          Navigator.of(context).pop(); // pop loading screen
          DuruhaSnackBar.showSuccess(context, "Order cancelled successfully!");
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/consumer/manage', (r) => true);
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          final msg = e is PostgrestException ? e.message : e.toString();
          DuruhaSnackBar.showError(context, "Failed to cancel order: $msg");
        }
      }
    }
  }

  // ─── delete ───────────────────────────────────────────────────────────────

  Future<void> _handleCancelItem(BuildContext context, String oomId) async {
    final confirmed = await DuruhaDialog.show(
      context: context,
      title: "Cancel Item",
      message:
          "Are you sure you want to cancel this specific item? This action will refund your stock and credits if applicable. This action cannot be undone.",
      confirmText: "Cancel Item",
      isDanger: true,
    );
    if (confirmed == true && context.mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ConsumerLoadingScreen(),
        );
        await _repo.cancelSingleOrderMatchItem(_match.orderId, oomId);
        if (context.mounted) {
          Navigator.of(context).pop(); // pop loading screen
          DuruhaSnackBar.showSuccess(context, "Item cancelled successfully!");
          _fetchFullDetails(_match.orderId); // refresh data
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          final msg = e is PostgrestException ? e.message : e.toString();
          DuruhaSnackBar.showError(context, "Failed to cancel item: $msg");
        }
      }
    }
  }

  Future<void> _showPaymentSelectionDialog() async {
    String selectedMethod = 'Cash on Delivery';
    final paymentOptions = ['Cash on Delivery', 'Pay Now', 'None of the Above'];
    final Map<String, IconData> paymentIcons = {
      'Pay on Delivery': Icons.local_shipping_outlined,
      'Pay Now': Icons.credit_card,
      'None of the Above': Icons.block,
    };

    final proceed = await DuruhaDialog.show(
      context: context,
      title: 'Payment Method',
      message: 'Choose how you want to pay for this order.',
      icon: Icons.payments_outlined,
      confirmText: 'Proceed',
      extraContentBuilder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              child: DuruhaDropdown<String>(
                value: selectedMethod,
                label: 'Payment Method',
                items: paymentOptions,
                itemIcons: paymentIcons,
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedMethod = val);
                },
              ),
            );
          },
        );
      },
    );

    if (proceed == true && mounted) {
      if (selectedMethod == 'Cash on Delivery') {
        // Update payment method in database
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ConsumerLoadingScreen(),
        );

        try {
          await supabase.rpc(
            'update_consumer_payments',
            params: {
              'p_order_id': _match.order.orderId,
              'p_payment_method': 'cash',
            },
          );

          if (mounted) {
            Navigator.of(context).pop(); // pop loading screen
            DuruhaSnackBar.showSuccess(
              context,
              'Payment method updated to Cash on Delivery',
            );
            // Refresh the order details
            await _fetchFullDetails(_match.order.orderId);
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();
            final msg = e is PostgrestException ? e.message : e.toString();
            DuruhaSnackBar.showError(
              context,
              'Failed to update payment method: $msg',
            );
          }
        }
      } else if (selectedMethod == 'Pay Now') {
        // Handle HitPay payment
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ConsumerLoadingScreen(),
        );

        try {
          await HitPayService().pay(
            amount: 200, //_match.totalAmount,
            referenceNumber: _match.order.orderId,
            currency: 'PHP',
            orderId: _match.order.orderId,
            action: 'payment-success',
          );
        } catch (e) {
          if (mounted) {
            DuruhaSnackBar.showError(
              context,
              'Payment error: ${e.toString().replaceAll('Exception: ', '')}',
            );
          }
        }

        if (mounted) {
          Navigator.of(context).pop(); // pop loading screen
        }
      } else if (selectedMethod == 'None of the Above') {
        // Handle "None of the Above" - just go back to manage
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/consumer/manage', (r) => false);
      }
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await DuruhaDialog.show(
      context: context,
      title: "Delete Order",
      message:
          "Are you sure you want to delete this order? This action cannot be undone.",
      confirmText: "Delete",
      isDanger: true,
    );
    if (confirmed == true && context.mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ConsumerLoadingScreen(),
        );
        await _repo.deleteOrderMatch(_match.offerOrderMatchId);
        if (context.mounted) {
          Navigator.of(context).pop();
          DuruhaSnackBar.showSuccess(context, "Order deleted successfully!");
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/consumer/manage', (r) => true);
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          final msg = e is PostgrestException ? e.message : e.toString();
          DuruhaSnackBar.showError(context, "Failed to delete: $msg");
        }
      }
    }
  }
}
