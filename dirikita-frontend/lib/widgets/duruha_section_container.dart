import 'package:flutter/material.dart';

enum DuruhaContainerStyle { filled, outlined }

class DuruhaSectionContainer extends StatelessWidget {
  final String? title;
  final Widget? action;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;
  final Color? backgroundColor;

  // Style properties
  final DuruhaContainerStyle style;
  final bool borderTop;
  final bool borderBottom;
  final bool borderLeft;
  final bool borderRight;

  const DuruhaSectionContainer({
    super.key,
    this.title,
    this.action,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.backgroundColor,
    this.style = DuruhaContainerStyle.filled,
    this.borderTop = true,
    this.borderBottom = true,
    this.borderLeft = true,
    this.borderRight = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine Background Color
    final Color? effectiveBgColor = style == DuruhaContainerStyle.filled
        ? (backgroundColor ?? colorScheme.surfaceContainerLow.withOpacity(0.5))
        : null;

    // Determine Border
    Border? border;
    if (style == DuruhaContainerStyle.outlined) {
      final Color borderColor = colorScheme.outline.withOpacity(0.2);
      border = Border(
        top: borderTop ? BorderSide(color: borderColor) : BorderSide.none,
        bottom: borderBottom ? BorderSide(color: borderColor) : BorderSide.none,
        left: borderLeft ? BorderSide(color: borderColor) : BorderSide.none,
        right: borderRight ? BorderSide(color: borderColor) : BorderSide.none,
      );
    } else {
      // Preserving previous 'filled' behavior which had a subtle border:
      border = Border.all(
        color: colorScheme.outline.withOpacity(0.2),
        width: 1,
      );
    }

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || action != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }
}
