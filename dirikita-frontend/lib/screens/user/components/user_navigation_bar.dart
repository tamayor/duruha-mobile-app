import 'package:flutter/material.dart';

class UserNavigationBar extends StatelessWidget {
  final String role;
  final String name;
  final String currentRoute;

  const UserNavigationBar({
    super.key,
    required this.role,
    required this.name,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFarmer = role == 'Farmer';

    // Define navigation items based on role
    final items = isFarmer ? _getFarmerItems() : _getConsumerItems();

    // Find the index of the current route
    int currentIndex = items.indexWhere((item) => item.route == currentRoute);
    if (currentIndex == -1)
      currentIndex = 0; // Default to first item if not found

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        final destination = items[index];
        if (destination.route != currentRoute) {
          // Navigate to the new route
          // Using pushReplacement to avoid building up a huge stack
          // or pushNamed if you want back button support (but mostly nav bars are top level)
          if (destination.route == '/home') {
            // Pass back the arguments if needed, for now assuming simpler nav
            // In a real app, we might use a shell route or state management
            // But for this simple requirement:
            Navigator.of(context).pushNamedAndRemoveUntil(
              destination.route,
              (route) => false,
              arguments: {
                'role': role,
                'name': name,
              }, // Ideally passed from parent
            );
          } else {
            Navigator.of(context).pushNamed(
              destination.route,
              arguments: {'role': role, 'name': name},
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
        route: '/farmer/dashboard',
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
