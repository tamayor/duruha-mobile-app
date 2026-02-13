import 'package:flutter/material.dart';

class DuruhaTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> tabs;
  final TabController? controller;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final bool isGlass;

  const DuruhaTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final activeLabelColor = labelColor ?? colorScheme.onPrimaryContainer;
    final inactiveLabelColor = unselectedLabelColor ?? colorScheme.onSecondary;
    final activeIndicatorColor = indicatorColor ?? colorScheme.onSecondary;

    return Container(
      decoration: isGlass
          ? BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            )
          : null,
      child: TabBar(
        controller: controller,
        tabs: tabs,
        labelColor: activeLabelColor,
        unselectedLabelColor: inactiveLabelColor,
        labelStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.normal,
        ),
        indicatorColor: activeIndicatorColor,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        dividerColor: colorScheme.outline.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}
