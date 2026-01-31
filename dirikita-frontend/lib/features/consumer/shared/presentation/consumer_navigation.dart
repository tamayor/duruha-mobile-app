import 'package:flutter/material.dart';

class ConsumerNavigation extends StatelessWidget {
  final String name;
  final String currentRoute;

  const ConsumerNavigation({
    super.key,
    required this.name,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _getConsumerItems();

    // Find the index of the current route
    int currentIndex = items.indexWhere((item) => item.route == currentRoute);
    if (currentIndex == -1) {
      currentIndex = 0; // Default to first item if not found
    }

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        final destination = items[index];
        if (destination.route != currentRoute) {
          if (destination.route == '/home') {
            Navigator.of(context).pushNamedAndRemoveUntil(
              destination.route,
              (route) => false,
              arguments: {'role': 'Consumer', 'name': name},
            );
          } else {
            Navigator.of(context).pushNamed(
              destination.route,
              arguments: {'role': 'Consumer', 'name': name},
            );
          }
        }
      },
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
          )
          .toList(),
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: theme.colorScheme.primaryContainer,
    );
  }

  List<_NavItem> _getConsumerItems() {
    return [
      _NavItem(
        label: 'Market',
        route: '/home',
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
      ),
      _NavItem(
        label: 'Cart',
        route: '/cart',
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart,
      ),
      _NavItem(
        label: 'Orders',
        route: '/orders',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      _NavItem(
        label: 'Profile',
        route: '/profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
    ];
  }
}

class _NavItem {
  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  _NavItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });
}
