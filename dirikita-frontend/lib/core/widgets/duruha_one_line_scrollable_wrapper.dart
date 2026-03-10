import 'package:flutter/material.dart';

/// A wrapper that makes its [child] horizontally scrollable.
/// Useful for long text rows that might overflow on smaller screens.
class DuruhaOneLineScrollableWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const DuruhaOneLineScrollableWrapper({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Colors.transparent],
          stops: [0.85, .95],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: padding,
        child: child,
      ),
    );
  }
}
