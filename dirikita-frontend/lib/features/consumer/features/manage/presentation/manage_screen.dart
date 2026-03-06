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
      body: ConsumerOrdersScreen(isPlanMode: _isPlanMode),
    );
  }
}
