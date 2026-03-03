import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/badge/duruha_delivery_status_badge.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/widgets/text/duruha_text_waiting.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.match != null) {
      _match = widget.match!;
      if (_isSummaryMatch(_match)) _fetchFullDetails(_match.offerOrderMatchId);
    } else if (widget.orderId != null) {
      _isLoading = true;
      _fetchFullDetails(widget.orderId!);
    } else {
      _hasError = true;
    }
  }

  bool _isSummaryMatch(ConsumerOrderMatch match) =>
      match.produceItems.isNotEmpty &&
      match.produceItems.every((item) => item.varieties.isEmpty);

  Future<void> _fetchFullDetails(String orderId) async {
    if (!_isLoading && mounted) setState(() => _isLoading = true);
    try {
      final fullMatch = await _repo.fetchOrderDetails(orderId);
      if (mounted) {
        setState(() {
          _match = fullMatch;
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
    if (vg.deliveryStatus == 'CANCELLED') return 0.0;
    double unitPrice = vg.variablePrice ?? 0.0;
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
      return Text(raw);
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

    return DuruhaScaffold(
      appBarTitle: "Order Details",
      appBarActions: [
        if (widget.action == 'new')
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.redAccent,
            onPressed: () => _handleDelete(context),
          ),
        // ── Cancel Order popup ──
        if (_match.isActive && _match.isCancellable)
          DuruhaPopupMenu<String>(
            items: const ['Cancel Order'],
            labelBuilder: (item) => item,
            itemIcons: const {'Cancel Order': Icons.cancel_outlined},
            tooltip: 'Order Actions',
            showLabel: false,
            showBackground: false,
            icon: Icon(Icons.more_vert, color: cs.error),
            iconColor: cs.error,
            onSelected: (item) {
              if (item == 'Cancel Order') _handleCancelOrder(context);
            },
          ),
        const SizedBox(width: 8),
      ],
      onBackPressed: () {
        if (widget.action == 'new') {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/consumer/manage', (r) => true);
        } else {
          Navigator.pop(context);
        }
      },
      floatingActionButton: widget.action == 'new'
          ? FloatingActionButton.extended(
              onPressed: () {
                // TODO: Navigate to payment/checkout flow
              },
              icon: const Icon(Icons.payment),
              label: const Text("Pay Now"),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          Text(_match.order.orderId),
          icon: Icons.confirmation_number_outlined,
          small: true,
        ),
        _row(
          t,
          "Date",
          _formatDateTime(_match.createdAt),
          icon: Icons.calendar_today,
        ),
        _row(
          t,
          "Status",
          _match.isActive
              ? Text(
                  "ACTIVE",
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                )
              : Text(
                  "INACTIVE",
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
          icon: Icons.info_outline,
        ),
        if (_match.note != null && _match.note!.isNotEmpty)
          _row(
            t,
            "Note",
            Text(_match.note!),
            icon: Icons.note_outlined,
            small: true,
          ),
        if (_match.paymentMethod.isNotEmpty)
          _row(
            t,
            "Payment",
            Text(_match.paymentMethod),
            icon: Icons.account_balance_wallet_outlined,
            small: true,
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
                    item.varieties.fold(0.0, (s, v) => s + v.quantity) > 0,
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
    int idx,
  ) {
    return Theme(
      data: t.copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(Icons.folder_open_outlined, color: cs.primary, size: 22),
        title: Text(
          item.produceDialectName,
          style: t.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        subtitle: Text(
          "${item.varieties.fold(0.0, (s, v) => s + v.quantity).toStringAsFixed(0)} kg total",
          style: t.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        children: [
          Container(
            padding: const EdgeInsets.only(left: 36, right: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: item.varieties.expand((group) {
                return group.varietyGroups.where((v) => v.quantity > 0).map((
                  v,
                ) {
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        v.name,
                                        style: t.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      Text(
                                        "${v.quantity.toStringAsFixed(0)} kg",
                                        style: t.textTheme.labelSmall?.copyWith(
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
                                      Opacity(
                                        opacity:
                                            (v.deliveryStatus == 'CANCELLED' &&
                                                !v.isPaid)
                                            ? 0.4
                                            : 1.0,
                                        child: _tag(
                                          t,
                                          v.isPaid ? 'PAID' : 'UNPAID',
                                          v.isPaid ? Colors.green : Colors.red,
                                          Colors.white,
                                          small: true,
                                          bold: true,
                                        ),
                                      ),
                                      if (v.deliveryStatus != null)
                                        _tag(
                                          t,
                                          v.deliveryStatus!,
                                          _statusColor(v.deliveryStatus, t),
                                          Colors.white,
                                          small: true,
                                          bold: true,
                                        )
                                      else
                                        _tag(
                                          t,
                                          "PENDING MATCH",
                                          Colors.orange,
                                          Colors.white,
                                          small: true,
                                          bold: true,
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
                });
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
    final double subtotal = total + item.effectiveQualityFee + delivery;
    final bool tentative = !item.isPriceFinalized;

    return Card(
      key: _produceKeys[idx],
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // produce name + quality badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.produceDialectName,
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                    DuruhaStatusBadge(
                      label: item.quality,
                      strikethrough: item.isCancelled,
                      color: cs.secondary,
                    ),
                  ],
                ),
                if (item.qualityFee > 0) ...[
                  const SizedBox(height: 4),
                  _row(
                    t,
                    "Quality Fee",
                    Text(
                      DuruhaFormatter.formatCurrency(item.effectiveQualityFee),
                      style: t.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onTertiary,
                        decoration: item.isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    small: true,
                  ),
                ],
                const SizedBox(height: 12),
                // variety groups
                ...item.varieties.asMap().entries.map(
                  (e) => _varGroupCard(ctx, t, cs, item, e.value, e.key),
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
                        "(${DuruhaFormatter.formatCurrency(total)} variety) + (${DuruhaFormatter.formatCurrency(delivery)} shipping) + (${DuruhaFormatter.formatCurrency(item.effectiveQualityFee)} quality)",
                        style: t.textTheme.labelSmall?.copyWith(
                          color: cs.onSecondary,
                          fontSize: 10,
                        ),
                      ),
                      if (tentative)
                        Text(
                          "Pending market updates",
                          style: t.textTheme.labelSmall?.copyWith(
                            color: Colors.orange[800],
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
  ) {
    final bool isPriceLock = group.isPriceLock;
    final bool isAny = group.isAny;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPriceLock
              ? cs.primary.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: isPriceLock ? 1.5 : 1,
        ),
        color: isPriceLock
            ? cs.primaryContainer.withValues(alpha: 0.04)
            : cs.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── group header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // form
                        if (group.form.isNotEmpty)
                          _tag(
                            t,
                            group.form,
                            cs.secondaryContainer,
                            cs.onSecondaryContainer,
                          ),
                        // price lock
                        if (isPriceLock)
                          _tag(
                            t,
                            "🔒 Price Lock",
                            cs.surface,
                            cs.onPrimary,
                            bold: true,
                          ),
                        // flexible
                        if (isAny)
                          _tag(t, "∞ Any Variety", cs.surface, cs.onTertiary),
                        // algo picked label
                        if (!isAny && !isPriceLock)
                          _tag(
                            t,
                            "⚙ Specific",
                            cs.surfaceContainerHighest,
                            cs.onSurface,
                          ),
                      ],
                    ),
                    Text(
                      "${idx + 1}",
                      style: t.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                // tag row
                const SizedBox(height: 8),
                // date needed (date only, no time)
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 13, color: cs.onSecondary),
                    const SizedBox(width: 5),
                    Text(
                      "Needed by ${DuruhaFormatter.formatDate(DateTime.parse(group.dateNeeded))}",
                      style: t.textTheme.labelSmall?.copyWith(
                        color: cs.onSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    final bool isPriceLock = group.isPriceLock;
    final bool hasDelivery = v.deliveryStatus != null;
    final bool finalized = v.finalPrice != null;

    final bool cancelled = v.deliveryStatus == 'CANCELLED';
    final bool cancellable =
        !cancelled &&
        !unchosen &&
        v.oomId != null &&
        v.deliveryStatus != null &&
        _cancellableStatuses.contains(v.deliveryStatus);

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.only(
        top: cancellable ? 20 : 10,
        left: 10,
        right: 10,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: unchosen
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: unchosen
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
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      DuruhaTextEmphasis(
                        text: v.name,
                        mainSize: 18,
                        mainColor: cs.onPrimary,
                        breaker: "()",
                        mainWeight: FontWeight.bold,
                        subSize: 10,
                        subColor: cs.onSecondary,
                      ),
                      if (unchosen) ...[
                        const SizedBox(width: 6),
                        _tag(
                          t,
                          "Not chosen",
                          cs.errorContainer,
                          cs.error,
                          small: true,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!unchosen)
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

          if (!unchosen) ...[
            const SizedBox(height: 6),

            // qty
            Opacity(
              opacity: cancelled ? 0.5 : 1.0,
              child: _row(
                t,
                "Allocated Qty",
                Text(
                  "${v.quantity.toStringAsFixed(0)} kg",
                  style: TextStyle(
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                small: true,
              ),
            ),
            const SizedBox(height: 6),
            // ── pricing block ──
            Opacity(
              opacity: cancelled ? 0.5 : 1.0,
              child: isPriceLock
                  ? _priceLockBlock(ctx, t, cs, group, v)
                  : finalized
                  ? _statusNote(
                      t,
                      Icons.check_circle_outline,
                      "Final: ${DuruhaFormatter.formatCurrency(v.finalPrice!)}",
                      Colors.green,
                      style: TextStyle(
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    )
                  : _statusNote(
                      t,
                      Icons.help_outline,
                      "Tentative: ${DuruhaFormatter.formatCurrency(v.variablePrice ?? 0)}",
                      Colors.orange,
                      style: TextStyle(
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
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
                Colors.orange,
              ),
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
                          color: Colors.green,
                          decoration: cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      )
                    : Text(
                        "UNPAID",
                        style: t.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
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
      opacity: unchosen ? 0.30 : 1.0,
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

  // ─── price lock block ─────────────────────────────────────────────────────

  Widget _priceLockBlock(
    BuildContext ctx,
    ThemeData t,
    ColorScheme cs,
    ProduceVariety group,
    VarietySelection v,
  ) {
    final bool isPriceLock = group.isPriceLock;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // price lock subscription link
          if (isPriceLock && group.cplsId != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DuruhaInkwell(
                  variation: InkwellVariation.subtle,
                  onTap: () => Navigator.pushNamed(
                    ctx,
                    '/consumer/subscriptions/pricelock_details',
                    arguments: group.cplsId,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock, size: 12, color: cs.onTertiary),
                      const SizedBox(width: 4),
                      Text(
                        "Price lock enabled →",
                        style: t.textTheme.labelSmall?.copyWith(
                          color: cs.onTertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 12),
          Row(
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
                    DuruhaFormatter.formatCurrency(v.variablePrice ?? 0),
                    style: t.textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: cs.onSecondary,
                    ),
                  ),
                ],
              ),

              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "Locked",
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
                  ? const Text('x')
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
                v.deliveryStatus == 'CANCELLED'
                    ? DuruhaFormatter.formatCurrency(0.0)
                    : DuruhaFormatter.formatCurrency(v.deliveryFee!),
                style: TextStyle(
                  decoration: v.deliveryStatus == 'CANCELLED'
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              small: true,
            ),
        ],
      ),
    );
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
                tentative ? "Tentative Total" : "Grand Total",
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
                ),
              ),
              if (tentative)
                Text(
                  "Awaiting final pricing",
                  style: t.textTheme.labelSmall?.copyWith(
                    color: Colors.orange[800],
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
      color: bg.withValues(alpha: 0.6),
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
              fontSize: small ? 12 : 14,
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
        ? Colors.green
        : (partial ? Colors.orange : cs.error);
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
                          Colors.green,
                        ),
                        const SizedBox(width: 16),
                        _miniStat(
                          t,
                          "${result.failed}",
                          "Failed",
                          result.failed > 0 ? Colors.orange : cs.onSecondary,
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
