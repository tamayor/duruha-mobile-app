import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_navigation.dart';

class AdminNavigation extends StatelessWidget {
  final String currentRoute;

  const AdminNavigation({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return DuruhaNavigation(
      currentRoute: currentRoute,
      items: const [
        DuruhaNavItem(
          label: 'Dashboard',
          route:
              '/admin/dashboard', // Assuming we'll map '/admin/dashboard' to AdminMainScreen or AdminDashboardScreen
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
        ),
        DuruhaNavItem(
          label: 'Produce',
          route: '/admin/produce',
          icon: Icons.eco_outlined,
          selectedIcon: Icons.eco_rounded,
        ),
        DuruhaNavItem(
          label: 'Calculator',
          route: '/admin/calculator',
          icon: Icons.calculate_outlined,
          selectedIcon: Icons.calculate_rounded,
        ),
        DuruhaNavItem(
          label: 'Settings',
          route: '/admin/settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
        ),
      ],
    );
  }
}
