import 'package:flutter/material.dart';

class DuruhaPopupMenu<T> extends StatelessWidget {
  final List<T> items;
  final T? selectedValue;
  final ValueChanged<T> onSelected;
  final String Function(T) labelBuilder;
  final Map<T, IconData>? itemIcons;
  final Widget? icon; // retained for backward compatibility
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? tooltip;
  final bool showLabel;
  final bool showBackground;

  // New appearance properties
  final bool isTextOnly;
  final Color? textColor;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final Widget? customTrigger;

  const DuruhaPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    required this.labelBuilder,
    this.selectedValue,
    this.itemIcons,
    this.icon,
    this.prefixIcon,
    this.suffixIcon,
    this.tooltip,
    this.showLabel = true,
    this.showBackground = true,
    this.isTextOnly = false,
    this.textColor,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.customTrigger,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Resolve colors
    final resolvedBgColor = isTextOnly
        ? Colors.transparent
        : (backgroundColor ??
              (showBackground
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Colors.transparent));

    final resolvedBorderColor = isTextOnly
        ? Colors.transparent
        : (borderColor ??
              (showBackground
                  ? colorScheme.outline.withValues(alpha: 0.3)
                  : Colors.transparent));

    final resolvedTextColor = textColor ?? colorScheme.onTertiary;
    final resolvedIconColor = iconColor ?? colorScheme.onTertiary;

    const double borderRadiusValue = 12.0;

    return Container(
      decoration: BoxDecoration(
        color: resolvedBgColor,
        borderRadius: BorderRadius.circular(borderRadiusValue),
        border: resolvedBorderColor != Colors.transparent
            ? Border.all(color: resolvedBorderColor)
            : null,
      ),
      // 1. ADD MATERIAL HERE
      child: Material(
        color: Colors.transparent, // Let the Container handle the background
        clipBehavior: Clip
            .antiAlias, // This forces the splash to be clipped to the radius
        borderRadius: BorderRadius.circular(borderRadiusValue),
        child: PopupMenuButton<int>(
          tooltip: tooltip,
          // 2. SET SPLASH RADIUS
          splashRadius: 24,
          onSelected: (int index) {
            if (index >= 0 && index < items.length) {
              onSelected(items[index]);
            }
          },
          itemBuilder: (BuildContext context) {
            return items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = selectedValue == item;

              return PopupMenuItem<int>(
                value: index,
                padding: EdgeInsets.zero,
                child: _buildPopupItem(context, item, isSelected),
              );
            }).toList();
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          child:
              customTrigger ??
              _buildDefaultTrigger(resolvedTextColor, resolvedIconColor, theme),
        ),
      ),
    );
  }

  // Helper to keep the build method clean
  Widget _buildDefaultTrigger(
    Color textColor,
    Color iconColor,
    ThemeData theme,
  ) {
    return Padding(
      padding: isTextOnly
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefixIcon != null || icon != null)
            (prefixIcon ?? icon)!
          else if (itemIcons != null && itemIcons!.containsKey(selectedValue))
            Icon(itemIcons![selectedValue], size: 20, color: iconColor),

          if ((prefixIcon != null ||
                  icon != null ||
                  (itemIcons != null &&
                      itemIcons!.containsKey(selectedValue))) &&
              showLabel)
            const SizedBox(width: 8),

          if (showLabel)
            Flexible(
              child: Text(
                items.contains(selectedValue)
                    ? labelBuilder(selectedValue as T)
                    : (tooltip ?? 'Select'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          if (suffixIcon != null) ...[
            const SizedBox(width: 4),
            suffixIcon!,
          ] else if (prefixIcon == null &&
              icon == null &&
              (itemIcons == null ||
                  !itemIcons!.containsKey(selectedValue))) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: iconColor),
          ],
        ],
      ),
    );
  }

  Widget _buildPopupItem(BuildContext context, T item, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      color: isSelected ? colorScheme.secondary : Colors.transparent,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (itemIcons != null && itemIcons!.containsKey(item)) ...[
            Icon(
              itemIcons![item],
              size: 20,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSecondary,
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              labelBuilder(item),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
