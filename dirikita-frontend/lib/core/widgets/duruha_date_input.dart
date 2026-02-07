import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DuruhaDateInput extends StatelessWidget {
  final String? label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? placeholder;
  final IconData? icon;

  const DuruhaDateInput({
    super.key,
    this.label,
    this.value,
    required this.onTap,
    this.placeholder,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon ?? Icons.calendar_today_rounded,
                    size: 18,
                    color: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value != null
                          ? DateFormat('MMM dd, yyyy').format(value!)
                          : (placeholder ?? 'Select'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: value != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
