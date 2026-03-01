import 'package:duruha/core/widgets/duruha_navigation.dart';
import 'package:flutter/material.dart';

class ConsumerNavigation extends StatelessWidget {
  final String currentRoute;

  const ConsumerNavigation({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return DuruhaNavigation(
      currentRoute: currentRoute,
      defaultArguments: {'role': 'Consumer'},
      items: const [
        DuruhaNavItem(
          label: 'Bili',
          route: '/consumer/shop',
          icon: Icons.shop_2_outlined,
          selectedIcon: Icons.shop_2,
        ),
        DuruhaNavItem(
          label: 'Manage',
          route: '/consumer/manage',
          icon: Icons.shopping_bag_outlined,
          selectedIcon: Icons.shopping_bag,
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
