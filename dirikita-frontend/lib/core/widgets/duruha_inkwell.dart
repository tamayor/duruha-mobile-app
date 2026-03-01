import 'package:flutter/material.dart';

enum InkwellVariation {
  modern, // Android 12+ Glimmer
  classic, // Standard Material Ripple
  subtle, // No splash, just a gentle highlight
  glass, // High-contrast for dark/gradient backgrounds
  brand, // Uses your primary brand color strongly
}

class DuruhaInkwell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;
  final InkwellVariation variation; // <--- New Parameter

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
    this.variation = InkwellVariation.modern, // Default
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1. Get variation settings
    final settings = _getVariationSettings(theme);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias, // Ensures splash follows border radius
        borderRadius: BorderRadius.circular(borderRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.transparent,
            gradient: gradient,
            border: border,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            // Apply variation settings
            splashFactory: settings.factory,
            splashColor: settings.splashColor,
            highlightColor: settings.highlightColor,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }

  // 2. Logic to define the 5 variations
  _InkwellStyle _getVariationSettings(ThemeData theme) {
    switch (variation) {
      case InkwellVariation.modern:
        return _InkwellStyle(
          factory: InkSparkle.splashFactory,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
        );
      case InkwellVariation.classic:
        return _InkwellStyle(
          factory: InkRipple.splashFactory,
          splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        );
      case InkwellVariation.subtle:
        return _InkwellStyle(
          factory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        );
      case InkwellVariation.glass:
        return _InkwellStyle(
          factory: InkSparkle.splashFactory,
          splashColor: Colors.white.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.1),
        );
      case InkwellVariation.brand:
        return _InkwellStyle(
          factory: InkRipple.splashFactory,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        );
    }
  }
}

// Simple helper class to hold the styles
class _InkwellStyle {
  final InteractiveInkFeatureFactory factory;
  final Color splashColor;
  final Color highlightColor;
  _InkwellStyle({
    required this.factory,
    required this.splashColor,
    required this.highlightColor,
  });
}
