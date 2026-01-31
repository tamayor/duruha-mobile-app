import 'package:flutter/material.dart';

class DuruhaProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final BorderRadius? borderRadius;
  final Widget? overlay;
  final bool animate;

  const DuruhaProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 12.0,
    this.borderRadius,
    this.overlay,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveBgColor =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(height / 2);

    final clampedValue = value.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: effectiveBgColor,
            borderRadius: effectiveBorderRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Progress Bar
              if (animate)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: clampedValue),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, _) {
                    return FractionallySizedBox(
                      widthFactor: animatedValue,
                      child: Container(
                        decoration: BoxDecoration(
                          color: effectiveColor,
                          borderRadius: effectiveBorderRadius,
                        ),
                      ),
                    );
                  },
                )
              else
                FractionallySizedBox(
                  widthFactor: clampedValue,
                  child: Container(
                    decoration: BoxDecoration(
                      color: effectiveColor,
                      borderRadius: effectiveBorderRadius,
                    ),
                  ),
                ),

              // Overlay Content (Text, markers, etc)
              if (overlay != null) Positioned.fill(child: overlay!),
            ],
          ),
        );
      },
    );
  }
}
