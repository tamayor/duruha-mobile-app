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
    final theme = Theme.of(context);
    final items = _getFarmerItems();

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
          if (destination.route == '/home' ||
              destination.route == '/farmer/farm') {
            Navigator.of(context).pushNamedAndRemoveUntil(
              destination.route,
              (route) => false,
              arguments: {'role': 'Farmer', 'name': name},
            );
          } else {
            Navigator.of(context).pushNamed(
              destination.route,
              arguments: {'role': 'Farmer', 'name': name},
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

  List<_NavItem> _getFarmerItems() {
    return [
      _NavItem(
        label: 'Farm',
        route: '/farmer/farm',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      _NavItem(
        label: 'My Crops',
        route: '/farmer/crops',
        icon: Icons.agriculture_outlined,
        selectedIcon: Icons.agriculture,
      ),
      _NavItem(
        label: 'Biz',
        route: '/farmer/biz',
        icon: Icons.list_alt_outlined,
        selectedIcon: Icons.list_alt,
      ),
      _NavItem(
        label: 'Monitor',
        route: '/farmer/monitor',
        icon: Icons.monitor_outlined,
        selectedIcon: Icons.monitor,
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
