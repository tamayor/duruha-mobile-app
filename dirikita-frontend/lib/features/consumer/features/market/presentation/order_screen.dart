import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_button.dart';
import 'package:duruha/core/widgets/duruha_scaffold.dart';
import 'package:duruha/core/widgets/duruha_selection_chip_group.dart';
import 'package:duruha/features/consumer/features/market/data/market_repository.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/features/consumer/features/market/presentation/market_state.dart';
import 'package:duruha/features/consumer/features/market/presentation/widgets/educational_note_card.dart';
import 'package:duruha/features/consumer/features/market/presentation/widgets/order_item_card.dart';
import 'package:flutter/material.dart';

class OrderScreen extends StatefulWidget {
  final MarketState marketState;
  final Map<String, dynamic> userData;

  const OrderScreen({
    super.key,
    required this.marketState,
    required this.userData,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final MarketRepository _repository = MarketRepository();
  bool _isProcessing = false;
  PaymentOption _selectedPaymentOption = PaymentOption.fullPayment;

  @override
  void initState() {
    super.initState();
    widget.marketState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.marketState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {}); // Rebuild when state changes
    }
  }

  Future<void> _handlePreBuy() async {
    if (!widget.marketState.allItemsComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all order items before proceeding.'),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final orderItems = widget.marketState.buildOrderItems(
        _selectedPaymentOption,
      );
      final order = await _repository.createOrder(orderItems);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Navigate to payment screen
        Navigator.of(context).pushNamed(
          '/consumer/market/order/pay',
          arguments: {
            'order': order,
            'userData': widget.userData,
            'marketState': widget.marketState,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating order: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderItems = widget.marketState.orderItems;
    final canProceed = widget.marketState.allItemsComplete;

    return DuruhaScaffold(
      appBarTitle:
          'Configure (${widget.marketState.marketMode == MarketMode.plan ? 'Plan' : 'Order'})',
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Educational note - only show in Plan mode
                  if (widget.marketState.marketMode == MarketMode.plan)
                    const EducationalNoteCard(),

                  // Order items - using OrderItemCard for comprehensive summary and actions
                  ...orderItems.entries.map((entry) {
                    final produceId = entry.key;
                    final builder = entry.value;

                    return OrderItemCard(
                      key: ValueKey(produceId),
                      builder: builder,
                      onUpdate: (updatedBuilder) {
                        widget.marketState.updateOrderItem(
                          produceId,
                          updatedBuilder,
                        );
                      },
                      onRemove: () {
                        widget.marketState.removeFromSelection(produceId);
                      },
                      isOrderMode:
                          widget.marketState.marketMode == MarketMode.order,
                    );
                  }),

                  const SizedBox(height: 16),

                  // Order summary
                  if (widget.marketState.estimatedTotal > 0)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withAlpha(
                            100,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Order Summary',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Items:',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                '${orderItems.length}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal Range:',
                                style: theme.textTheme.bodyMedium,
                              ),
                              () {
                                final min =
                                    widget.marketState.estimatedMinSubtotal;
                                final max =
                                    widget.marketState.estimatedMaxSubtotal;
                                if (min == max) {
                                  return Text(
                                    DuruhaFormatter.formatCurrency(max),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return Text(
                                  "${DuruhaFormatter.formatCurrency(min)} - ${DuruhaFormatter.formatCurrency(max)}",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }(),
                            ],
                          ),
                          const Divider(height: 16),

                          // Global Payment Option Selection
                          Text(
                            'Payment Option',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DuruhaSelectionChipGroup(
                            title: '', // Empty because we have title above
                            options: PaymentOption.values
                                .map((o) => o.label)
                                .toList(),
                            selectedValues: [_selectedPaymentOption.label],
                            onToggle: (label) {
                              setState(() {
                                _selectedPaymentOption = PaymentOption.values
                                    .firstWhere((o) => o.label == label);
                              });
                            },
                          ),

                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Due Now:',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF4CAF50),
                                        ),
                                  ),
                                  if (_selectedPaymentOption ==
                                      PaymentOption.downPayment)
                                    Text(
                                      '(20% of Min Subtotal)',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    )
                                  else if (widget
                                          .marketState
                                          .estimatedMinSubtotal !=
                                      widget.marketState.estimatedMaxSubtotal)
                                    Text(
                                      '(Estimated Full Payment)',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                              () {
                                double amount;
                                if (_selectedPaymentOption ==
                                    PaymentOption.downPayment) {
                                  // As requested: 20% of the MINIMUM payment
                                  amount =
                                      widget.marketState.estimatedMinSubtotal *
                                      0.20;
                                } else {
                                  // Full payment: usually pay everything (using max to cover potential spread)
                                  amount =
                                      widget.marketState.estimatedMaxSubtotal;
                                }

                                return Text(
                                  DuruhaFormatter.formatCurrency(amount),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                );
                              }(),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Pre-buy button
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
                text: 'Pre Buy',
                onPressed: canProceed ? _handlePreBuy : null,
                isLoading: _isProcessing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
