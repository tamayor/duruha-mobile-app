import 'package:flutter/material.dart';

class DuruhaPopupMenu<T> extends StatelessWidget {
  final List<T> items;
  final T? selectedValue;
  final ValueChanged<T> onSelected;
  final String Function(T) labelBuilder;
  final Map<T, IconData>? itemIcons;
  final Widget? icon;
  final String? tooltip;
  final bool showLabel;

  const DuruhaPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    required this.labelBuilder,
    this.selectedValue,
    this.itemIcons,
    this.icon,
    this.tooltip,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use internal index to avoid issues with null values in PopupMenuButton
    // T might be nullable, so we map selection to indices.
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: PopupMenuButton<int>(
        tooltip: tooltip,
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
              child: Container(
                color: isSelected ? colorScheme.secondary : Colors.transparent,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (itemIcons != null && itemIcons!.containsKey(item)) ...[
                      Icon(
                        itemIcons![item],
                        size: 20,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        labelBuilder(item),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.onSecondary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // Use 'child' to create a custom trigger button
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Show Icon if current selection has one
              if (itemIcons != null &&
                  itemIcons!.containsKey(selectedValue)) ...[
                Icon(
                  itemIcons![selectedValue],
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                // const SizedBox(width: 8),
              ],
              // 2. Show Label
              if (showLabel)
                Flexible(
                  child: Text(
                    // Show "Select" only if selectedValue is not found (and not null-valid)
                    items.contains(selectedValue)
                        ? labelBuilder(selectedValue as T)
                        : (tooltip ?? 'Select'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // const SizedBox(width: 4),
              // Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
