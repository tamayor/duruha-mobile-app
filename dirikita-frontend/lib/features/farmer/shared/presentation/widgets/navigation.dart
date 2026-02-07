import 'package:duruha/core/widgets/duruha_inkwell.dart';
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
    // Check for exact match first, then check if current route starts with nav route
    int currentIndex = items.indexWhere((item) => currentRoute == item.route);
    if (currentIndex == -1) {
      // Try to find a match where current route starts with the nav item route
      currentIndex = items.indexWhere(
        (item) => currentRoute.startsWith('${item.route}/'),
      );
    }
    // Check if this is the root route (no selection)
    final isRootRoute = currentRoute == "/";

    return Container(
      height: 110,
      alignment: Alignment.topCenter,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(50),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          // Only show selection styling if NOT on root route
          final isSelected = !isRootRoute && (index == currentIndex);

          return Expanded(
            child: DuruhaInkwell(
              onTap: () {
                if (item.route != currentRoute) {
                  if (item.route == '/home' || item.route == '/farmer/farm') {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      item.route,
                      (route) => false,
                      arguments: {'role': 'Farmer', 'name': name},
                    );
                  } else {
                    Navigator.of(context).pushNamed(
                      item.route,
                      arguments: {'role': 'Farmer', 'name': name},
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: isSelected
                    ? BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withAlpha(
                          100,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      )
                    : null,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      size: 24,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<_NavItem> _getFarmerItems() {
    return [
      _NavItem(
        label: 'Tanaw',
        route: '/farmer/main',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      _NavItem(
        label: 'Benta',
        route: '/farmer/sales',
        icon: Icons.agriculture_outlined,
        selectedIcon: Icons.agriculture,
      ),
      _NavItem(
        label: 'Manage',
        route: '/farmer/manage',
        icon: Icons.manage_history_outlined,
        selectedIcon: Icons.manage_history,
      ),
      _NavItem(
        label: 'Biz',
        route: '/farmer/biz',
        icon: Icons.attach_money,
        selectedIcon: Icons.attach_money,
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
