import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duruha/core/theme/duruha_styles.dart';

class DuruhaDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData? prefixIcon;
  final List<T> items;
  final Map<T, IconData>? itemIcons;
  final ValueChanged<T?> onChanged;
  final String Function(T)? labelBuilder;
  final FormFieldValidator<T>? validator;
  final bool isRequired;

  const DuruhaDropdown({
    super.key,
    required this.value,
    required this.label,
    this.prefixIcon,
    required this.items,
    required this.onChanged,
    this.itemIcons,
    this.labelBuilder,
    this.validator,
    this.isRequired = false,
  });

  String _getLabel(T item) {
    if (labelBuilder != null) {
      final label = labelBuilder!(item);
      // ignore: unnecessary_null_comparison
      if (label != null) return label;
    }
    if (item is String) return item.replaceAll('_', ' ');
    return item.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use onPrimary for the selected text and icons if the field is colored
    final Color contentColor = colorScheme.onPrimary;

    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      // We assume your decoration here uses the Primary color as the 'fillColor'
      decoration:
          DuruhaStyles.fieldDecoration(
            context,
            label: isRequired ? '$label *' : label,
            icon: prefixIcon,
          ).copyWith(
            filled: true,
            fillColor: colorScheme
                .primary, // The background is now the Primary brand color
            // Label text needs to be visible on Primary
            labelStyle: TextStyle(color: contentColor.withValues(alpha: 0.8)),
            floatingLabelStyle: TextStyle(color: contentColor),
            // Icon color in the decoration
            prefixIconColor: contentColor,
          ),
      // Arrow color set to onPrimary
      icon: Icon(Icons.arrow_drop_down_rounded, color: contentColor, size: 20),

      // Selected value text style
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: contentColor, // This is your onPrimary text
      ),

      // The Menu (The part that pops up)
      // Usually, the popup menu should stay white/surface for readability
      dropdownColor: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),

      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Row(
            children: [
              if (itemIcons != null && itemIcons!.containsKey(item)) ...[
                Icon(
                  itemIcons![item],
                  size: 20,
                  color: colorScheme
                      .onSecondary, // Use primary inside the white menu
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  _getLabel(item),
                  style: TextStyle(
                    // Inside the white dropdown, we go back to onSurface (dark)
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) {
        HapticFeedback.selectionClick();
        onChanged(val);
      },
      validator: validator,
    );
  }
}
