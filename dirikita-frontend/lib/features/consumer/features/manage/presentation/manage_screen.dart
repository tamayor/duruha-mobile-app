import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';
import 'manage_order_screen.dart';

class ConsumerManageScreen extends StatefulWidget {
  const ConsumerManageScreen({super.key});

  @override
  State<ConsumerManageScreen> createState() => _ConsumerManageScreenState();
}

class _ConsumerManageScreenState extends State<ConsumerManageScreen> {
  // Order mode is the default. Plan mode is coming soon and cannot be activated.
  bool _isPlanMode = false;

  void _toggleMode(bool isPlan) {
    // Plan mode is coming soon — tapping Plan shows the placeholder only.
    setState(() => _isPlanMode = isPlan);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DuruhaScaffold(
      appBarTitle: _isPlanMode ? 'My Plans' : 'My Orders',
      showBackButton: false,
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(2),
          child: Tooltip(
            message: _isPlanMode ? 'Coming soon' : 'Plan mode — coming soon',
            child: DuruhaToggleButton(
              value: _isPlanMode,
              onChanged: _toggleMode,
              iconTrue: Icons.calendar_today_rounded,
              iconFalse: Icons.shopping_bag_rounded,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
      bottomNavigationBar: const ConsumerNavigation(
        currentRoute: '/consumer/manage',
      ),
      body: _isPlanMode
          ? _buildComingSoon(theme, scheme)
          : const ConsumerOrdersScreen(),
    );
  }

  Widget _buildComingSoon(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 72,
              color: scheme.outline,
            ),
            const SizedBox(height: 20),
            Text(
              'Plan Mode — Coming Soon',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Pre-ordering for future harvest is on the way.\nStay tuned!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => setState(() => _isPlanMode = false),
              child: const Text('Back to Orders'),
            ),
          ],
        ),
      ),
    );
  }
}
