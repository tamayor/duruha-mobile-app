import 'package:flutter/material.dart';

/// A reusable modal bottom sheet widget with consistent Duruha styling.
///
/// Features:
/// - Transparent background with rounded top corners
/// - Drag handle indicator
/// - Optional title with icon and close button
/// - Scrollable content area
/// - Fixed height (85% of screen by default)
class DuruhaModalBottomSheet extends StatelessWidget {
  /// Title text displayed at the top of the modal
  final String title;

  /// Optional subtitle displayed below the title
  final String? subtitle;

  /// Icon displayed next to the title
  final IconData icon;

  /// The main content of the modal
  final Widget child;

  /// Optional height as a percentage of screen height (0.0 to 1.0)
  /// Defaults to 0.85 (85% of screen height)
  final double heightFactor;

  /// Whether the content should be scrollable
  /// Defaults to true
  final bool isScrollable;

  /// Custom padding for the content area
  /// Defaults to EdgeInsets.all(24)
  final EdgeInsets? contentPadding;

  const DuruhaModalBottomSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.heightFactor = 0.95,
    this.isScrollable = true,
    this.contentPadding,
  });

  /// Shows the modal bottom sheet with the provided content
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
    double heightFactor = 0.95,
    bool isScrollable = true,
    EdgeInsets? contentPadding,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DuruhaModalBottomSheet(
          title: title,
          icon: icon,
          subtitle: subtitle,
          heightFactor: heightFactor,
          isScrollable: isScrollable,
          contentPadding: contentPadding,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height:
          MediaQuery.of(context).size.height *
          heightFactor, //MediaQuery.of(context).size.height * heightFactor,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withAlpha(50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with title, subtitle, and close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: isScrollable
                ? SingleChildScrollView(
                    padding: contentPadding ?? const EdgeInsets.all(24),
                    child: child,
                  )
                : Padding(
                    padding: contentPadding ?? const EdgeInsets.all(24),
                    child: child,
                  ),
          ),
        ],
      ),
    );
  }
}
