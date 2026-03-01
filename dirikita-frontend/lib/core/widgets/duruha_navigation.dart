import 'package:duruha/core/widgets/duruha_inkwell.dart';
import 'package:flutter/material.dart';

class DuruhaNavItem {
  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final Map<String, dynamic>? arguments;

  const DuruhaNavItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    this.arguments,
  });
}

class DuruhaNavigation extends StatelessWidget {
  final List<DuruhaNavItem> items;
  final String currentRoute;
  final Function(DuruhaNavItem)? onNavigate;
  final Map<String, dynamic>? defaultArguments;

  const DuruhaNavigation({
    super.key,
    required this.items,
    required this.currentRoute,
    this.onNavigate,
    this.defaultArguments,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final currentIndex = _resolveCurrentIndex(items);
    final isRootRoute = currentRoute == "/";

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = !isRootRoute && index == currentIndex;

          return Expanded(
            child: DuruhaInkwell(
              borderRadius: 16,
              onTap: () => _handleNavigation(context, item),
              backgroundColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.fromLTRB(6, 6, 6, 20),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primaryContainer.withValues(alpha: 0.35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      size: 24,
                      color: isSelected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
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

  int _resolveCurrentIndex(List<DuruhaNavItem> items) {
    int index = items.indexWhere((item) => currentRoute == item.route);

    if (index == -1) {
      index = items.indexWhere(
        (item) => currentRoute.startsWith('${item.route}/'),
      );
    }

    return index;
  }

  void _handleNavigation(BuildContext context, DuruhaNavItem item) {
    if (onNavigate != null) {
      onNavigate!(item);
      return;
    }

    if (item.route == currentRoute) return;

    final args = item.arguments ?? defaultArguments;

    // Logic to reset stack if navigating to home, specific to Duruha app flow
    if (item.route == '/home' ||
        item.route == '/farmer/farm' ||
        item.route == '/consumer/shop') {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(item.route, (route) => false, arguments: args);
    } else {
      Navigator.of(context).pushNamed(item.route, arguments: args);
    }
  }
}
