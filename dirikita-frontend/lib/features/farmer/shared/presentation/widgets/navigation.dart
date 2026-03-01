import 'package:duruha/core/widgets/duruha_navigation.dart';
import 'package:flutter/material.dart';

class FarmerNavigation extends StatelessWidget {
  final String name;
  final String currentRoute;

  const FarmerNavigation({
    super.key,
    required this.name,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return DuruhaNavigation(
      currentRoute: currentRoute,
      defaultArguments: {'role': 'Farmer', 'name': name},
      items: const [
        DuruhaNavItem(
          label: 'Tanaw',
          route: '/farmer/main',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
        DuruhaNavItem(
          label: 'Benta',
          route: '/farmer/sales',
          icon: Icons.agriculture_outlined,
          selectedIcon: Icons.agriculture,
        ),
        DuruhaNavItem(
          label: 'Manage',
          route: '/farmer/manage',
          icon: Icons.manage_history_outlined,
          selectedIcon: Icons.manage_history,
        ),
        DuruhaNavItem(
          label: 'Biz',
          route: '/farmer/biz',
          icon: Icons.attach_money,
          selectedIcon: Icons.attach_money,
        ),
        DuruhaNavItem(
          label: 'Profile',
          route: '/profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
        ),
      ],
    );
  }
}
