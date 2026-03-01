import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/manage/domain/order_details_model.dart';
import '../data/transaction_repository.dart';

class TransactionMessageScreen extends StatefulWidget {
  final PlaceOrderResult result;

  const TransactionMessageScreen({super.key, required this.result});

  @override
  State<TransactionMessageScreen> createState() =>
      _TransactionMessageScreenState();
}

class _TransactionMessageScreenState extends State<TransactionMessageScreen> {
  final _txRepository = TransactionRepository();
  bool _isFetching = false;

  Future<void> _viewOrderDetails() async {
    if (widget.result.orderId.isEmpty) return;

    setState(() => _isFetching = true);
    try {
      final match = await _txRepository.fetchSpecificOrder(
        widget.result.orderId,
      );
      if (mounted) {
        if (match != null) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/consumer/manage/order',
            arguments: {'match': match, 'action': 'new'},
            (route) => true,
          );
        } else {
          DuruhaSnackBar.showError(
            context,
            "Could not load order details. Please try again later.",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        DuruhaSnackBar.showError(context, "Error: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;

    return DuruhaScaffold(
      appBarTitle: "Order Outcome",
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            _buildStatusIcon(
              theme,
              result.success,
              result.matched,
              result.failed,
            ),
            const SizedBox(height: 24),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: result.success ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            if (result.orderId.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Order ID: ",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      result.orderId,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            _buildSummaryCard(theme, result),
            const SizedBox(height: 32),
            if (result.errors.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Unfulfilled Items",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...result.errors.map((e) => _buildErrorItem(theme, e)),
            ],
            const SizedBox(height: 48),

            // Navigation Buttons
            Column(
              children: [
                if (result.orderId.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFetching ? null : _viewOrderDetails,
                      icon: _isFetching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.receipt_long_outlined),
                      label: Text(
                        _isFetching ? "Loading..." : "View Order Details",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/consumer/shop',
                          (route) => false,
                        ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: theme.colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Return to Shop"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(
    ThemeData theme,
    bool success,
    int matched,
    int failed,
  ) {
    IconData icon;
    Color color;

    if (success && failed == 0) {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
    } else if (matched > 0) {
      icon = Icons.warning_amber_rounded;
      color = Colors.orange;
    } else {
      icon = Icons.cancel_rounded;
      color = theme.colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 80, color: color),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, PlaceOrderResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(theme, "Matched", result.matched.toString(), Colors.green),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outlineVariant,
          ),
          _buildStat(
            theme,
            "Failed",
            result.failed.toString(),
            result.failed > 0
                ? Colors.orange
                : theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildStat(ThemeData theme, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorItem(ThemeData theme, PlaceOrderError error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(
          (0.3 * 255).round(),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${error.form} Item",
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${error.unfulfilledQty} unfulfilled",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            error.reason,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Requested: ${error.requestedQty}",
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
