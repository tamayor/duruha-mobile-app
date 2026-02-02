import 'package:flutter/material.dart';

class DuruhaInkwell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;

  const DuruhaInkwell({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.shadow,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // 1. We use Material to provide the 'ink' surface
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent, // Let the 'Ink' decoration show through
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.transparent,
            gradient: gradient,
            border: border,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: InkWell(
            onTap: onTap,
            // 2. This ensures the splash stays inside the rounded corners
            borderRadius: BorderRadius.circular(borderRadius),
            // 3. Customizing the 'feel' of the interaction
            splashColor: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.12),
            highlightColor: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.05),
            splashFactory: InkSparkle.splashFactory, // Modern 'glimmer' effect
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }
}
