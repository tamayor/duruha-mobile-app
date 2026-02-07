import 'dart:convert';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_button.dart';
import 'package:duruha/core/widgets/duruha_scaffold.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/core/widgets/duruha_selection_chip_group.dart';
import 'package:duruha/features/consumer/features/market/data/market_repository.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/features/consumer/features/market/presentation/market_state.dart';
import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  final MarketOrder order;
  final Map<String, dynamic> userData;
  final MarketState marketState;

  const PaymentScreen({
    super.key,
    required this.order,
    required this.userData,
    required this.marketState,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final MarketRepository _repository = MarketRepository();
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'gcash';

  // Supply Schedule State
  DeliveryFrequency _selectedFrequency = DeliveryFrequency.once;
  DateTime _preferredStartDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _preferredEndDate = DateTime.now().add(const Duration(days: 90));
  bool _isUntilCancelled = false;
  List<int> _preferredDaysOfWeek = [];

  Future<void> _handleConfirmPayment() async {
    setState(() {
      _isProcessing = true;
    });

    final schedule = SupplySchedule(
      preferredStartDate: _preferredStartDate,
      preferredEndDate: _isUntilCancelled ? null : _preferredEndDate,
      frequency: _selectedFrequency,
      preferredDaysOfWeek: _preferredDaysOfWeek,
    );

    // LOGGING: Console log the entire transaction data
    final transactionData = {
      'transactionId': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
      'userData': widget.userData,
      'order': {
        'id': widget.order.id,
        'subtotal': widget.order.subtotal,
        'minSubtotal': widget.order.minSubtotal,
        'amountDueNow': widget.order.totalDueNow,
        'remainingBalance': widget.order.remainingBalance,
        'items': widget.order.items
            .map(
              (item) => {
                'produceId': item.produce.id,
                'name': item.produce.nameEnglish,
                'varieties': item.selectedVarieties,
                'classes': item.selectedClasses.map((c) => c.code).toList(),
                'quantity': item.quantityKg,
                'unit': item.produce.unitOfMeasure,
                'priceAtOrder': item.totalPrice,
                'paymentOption': item.paymentOption.label,
              },
            )
            .toList(),
      },
      'payment': {
        'method': _selectedPaymentMethod,
        'status': 'pending_confirmation',
      },
      'supplySchedule': schedule.toJson(),
    };

    debugPrint('--- [API TRANSACTION DATA] ---');
    debugPrint(const JsonEncoder.withIndent('  ').convert(transactionData));
    debugPrint('------------------------------');

    try {
      // In a real app, we might update the order object with the schedule first
      final success = await _repository.submitPayment(widget.order);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (success) {
          // Clear the cart
          widget.marketState.clearSelections();

          // Show success dialog
          _showSuccessDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment failed. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing payment: $e')));
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Order Confirmed!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your pre-buy order has been successfully placed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order ID',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          widget.order.id,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for supporting local farmers! You\'ll be notified when your harvest is ready.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          DuruhaButton(
            text: 'View My Orders',
            onPressed: () {
              // Close dialog and navigate to orders
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/consumer/orders',
                (route) => route.isFirst,
                arguments: widget.userData,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScaffold(
      appBarTitle: 'Payment',
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DuruhaSectionContainer(
                    title: 'Order Summary',
                    children: [
                      ...widget.order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.produce.imageThumbnailUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: theme.colorScheme.surfaceContainer,
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item
                                              .produce
                                              .namesByDialect['hiligaynon'] ??
                                          item.produce.nameEnglish,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.selectedVarieties.join(', ')} • Grade ${item.selectedClasses.map((c) => c.code).join(', ')}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.quantityKg} ${item.produce.unitOfMeasure} × ${DuruhaFormatter.formatCurrency(item.produce.currentFairMarketGuideline)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            item.paymentOption ==
                                                PaymentOption.downPayment
                                            ? theme.colorScheme.primaryContainer
                                            : theme
                                                  .colorScheme
                                                  .secondaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.paymentOption.label,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                DuruhaFormatter.formatCurrency(item.totalPrice),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 16),

                  DuruhaSectionContainer(
                    backgroundColor: theme.colorScheme.surfaceContainer,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal:', style: theme.textTheme.bodyMedium),
                          Text(
                            DuruhaFormatter.formatCurrency(
                              widget.order.subtotal,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount Due Now',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              if (widget.order.remainingBalance > 0)
                                Text(
                                  'Balance due at harvest: ${DuruhaFormatter.formatCurrency(widget.order.remainingBalance)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            DuruhaFormatter.formatCurrency(
                              widget.order.totalDueNow,
                            ),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  DuruhaSectionContainer(
                    title: 'Supply Schedule',
                    children: [
                      DuruhaSelectionChipGroup(
                        title: 'Delivery Frequency',
                        options: DeliveryFrequency.values
                            .map((f) => f.label)
                            .toList(),
                        selectedValues: [_selectedFrequency.label],
                        onToggle: (label) {
                          setState(() {
                            _selectedFrequency = DeliveryFrequency.values
                                .firstWhere((f) => f.label == label);
                          });
                        },
                      ),
                      if (_selectedFrequency != DeliveryFrequency.once) ...[
                        const SizedBox(height: 16),
                        DuruhaSelectionChipGroup(
                          title: 'Preferred Delivery Days',
                          options: SupplySchedule.dayNames,
                          selectedValues: _preferredDaysOfWeek
                              .map((d) => SupplySchedule.dayNames[d - 1])
                              .toList(),
                          onToggle: (dayName) {
                            final dayNum =
                                SupplySchedule.dayNames.indexOf(dayName) + 1;
                            setState(() {
                              if (_preferredDaysOfWeek.contains(dayNum)) {
                                _preferredDaysOfWeek.remove(dayNum);
                              } else {
                                _preferredDaysOfWeek.add(dayNum);
                              }
                            });
                          },
                        ),
                      ],
                      const Divider(height: 24),
                      // Date Range Section
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Date',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _preferredStartDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _preferredStartDate = picked;
                                        _preferredEndDate = DateTime(
                                          picked.year,
                                          picked.month + 3,
                                          picked.day,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DuruhaFormatter.formatDate(
                                            _preferredStartDate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedFrequency != DeliveryFrequency.once) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Date',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: _isUntilCancelled
                                        ? null
                                        : () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  _preferredEndDate ??
                                                  _preferredStartDate.add(
                                                    const Duration(days: 90),
                                                  ),
                                              firstDate: _preferredStartDate,
                                              lastDate: _preferredStartDate.add(
                                                const Duration(days: 365 * 2),
                                              ),
                                            );
                                            if (picked != null) {
                                              setState(
                                                () =>
                                                    _preferredEndDate = picked,
                                              );
                                            }
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _isUntilCancelled
                                            ? theme.colorScheme.surfaceContainer
                                                  .withValues(alpha: 0.5)
                                            : theme
                                                  .colorScheme
                                                  .surfaceContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.event_note,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isUntilCancelled
                                                ? 'Infinity'
                                                : DuruhaFormatter.formatDate(
                                                    _preferredEndDate ??
                                                        _preferredStartDate.add(
                                                          const Duration(
                                                            days: 90,
                                                          ),
                                                        ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_selectedFrequency != DeliveryFrequency.once) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: _isUntilCancelled,
                              onChanged: (val) => setState(
                                () => _isUntilCancelled = val ?? false,
                              ),
                            ),
                            const Text('Until Cancelled (Infinity)'),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Calculated Deliveries:',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Builder(
                              builder: (context) {
                                final schedule = SupplySchedule(
                                  preferredStartDate: _preferredStartDate,
                                  preferredEndDate: _isUntilCancelled
                                      ? null
                                      : _preferredEndDate,
                                  frequency: _selectedFrequency,
                                  preferredDaysOfWeek: _preferredDaysOfWeek,
                                );
                                final count = schedule.occurrences;
                                return Text(
                                  count == -1 ? 'Ongoing' : '$count x',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  DuruhaSectionContainer(
                    title: 'Payment Method',
                    children: [
                      DuruhaSelectionChipGroup(
                        title: '',
                        layout: SelectionLayout.column,
                        options: const [
                          'GCash',
                          'Credit/Debit Card',
                          'Bank Transfer',
                        ],
                        selectedValues: [
                          if (_selectedPaymentMethod == 'gcash') 'GCash',
                          if (_selectedPaymentMethod == 'card')
                            'Credit/Debit Card',
                          if (_selectedPaymentMethod == 'bank') 'Bank Transfer',
                        ],
                        optionIcons: const {
                          'GCash': Icons.phone_android,
                          'Credit/Debit Card': Icons.credit_card,
                          'Bank Transfer': Icons.account_balance,
                        },
                        optionSubtitles: const {
                          'GCash': 'Fast & Secure Mobile Payment',
                          'Credit/Debit Card': 'Visa, Mastercard, JCB',
                          'Bank Transfer': 'Via InstaPay or PESONet',
                        },
                        onToggle: (label) {
                          setState(() {
                            if (label == 'GCash')
                              _selectedPaymentMethod = 'gcash';
                            if (label == 'Credit/Debit Card')
                              _selectedPaymentMethod = 'card';
                            if (label == 'Bank Transfer')
                              _selectedPaymentMethod = 'bank';
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Confirm payment button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(50),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: DuruhaButton(
                text: 'Confirm Payment',
                onPressed: _handleConfirmPayment,
                isLoading: _isProcessing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
