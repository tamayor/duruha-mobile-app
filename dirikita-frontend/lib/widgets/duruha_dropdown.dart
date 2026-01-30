import 'package:flutter/material.dart';
import 'package:duruha/theme/duruha_styles.dart';

class DuruhaDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData prefixIcon;
  final List<T> items;
  final Map<T, IconData>? itemIcons; // Optional: Show icons next to choices
  final ValueChanged<T?> onChanged;

  final String Function(T)? labelBuilder;
  final FormFieldValidator<T>? validator;
  final bool isRequired;

  const DuruhaDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.prefixIcon,
    required this.items,
    required this.onChanged,
    this.itemIcons,
    this.labelBuilder,
    this.validator,
    this.isRequired = false,
  });

  // Helper to format labels, preserving old string logic as default
  String _getLabel(T item) {
    if (labelBuilder != null) {
      return labelBuilder!(item);
    }
    if (item is String) {
      if (item == 'Walk_In') return 'Walk-in Only (No Vehicle)';
      if (item == 'Truck') return '4-Wheel Truck Accessible';
      return item.replaceAll('_', ' ');
    }
    return item.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true, // Prevents text overflow
      decoration: DuruhaStyles.fieldDecoration(
        context,
        label: isRequired ? '$label *' : label,
        icon: prefixIcon,
      ),
      icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSecondary),
      dropdownColor: colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        fontSize: 16,
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Row(
            children: [
              if (itemIcons != null && itemIcons!.containsKey(item)) ...[
                Icon(
                  itemIcons![item],
                  size: 20,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(_getLabel(item), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
