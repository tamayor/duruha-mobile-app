import 'package:flutter/material.dart';

class DuruhaGlidingIconBadge extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color baseColor; // Custom base text color
  final Color highlightColor; // Custom spotlight/icon color

  const DuruhaGlidingIconBadge({
    super.key,
    required this.text,
    required this.icon,
    this.baseColor = const Color(0x4DFFFFFF), // Low opacity white
    this.highlightColor = Colors.yellowAccent,
  });

  @override
  State<DuruhaGlidingIconBadge> createState() => _DuruhaGlidingIconBadgeState();
}

class _DuruhaGlidingIconBadgeState extends State<DuruhaGlidingIconBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 3000,
      ), // Slightly slower for elegance
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine, // Very smooth acceleration
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure we have a valid width to work with
        final double width =
            (constraints.maxWidth > 0 && constraints.maxWidth.isFinite)
            ? constraints.maxWidth
            : 150.0;

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final double t = _animation.value;

            // Icon starts completely hidden on the left, ends hidden on the right
            final double xOffset = (t * (width + 60)) - 30;

            final double stop1 = ((t * 1.4) - 0.4).clamp(0.0, 1.0);
            final double stop2 = ((t * 1.4) - 0.2).clamp(0.0, 1.0);
            final double stop3 = (t * 1.4).clamp(0.0, 1.0);

            return ClipRect(
              // <--- THIS CLIPS THE OVERFLOW
              child: SizedBox(
                width: width,
                height: 30, // Give it a fixed height so it doesn't jump
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // 1. TEXT LAYER
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [
                            widget.baseColor,
                            widget.baseColor,
                            widget.highlightColor,
                            widget.baseColor,
                            widget.baseColor,
                          ],
                          stops: [0.0, stop1, stop2, stop3, 1.0],
                        ).createShader(bounds);
                      },
                      child: Text(
                        widget.text,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                    // 2. ICON LAYER (Now clipped by the parent ClipRect)
                    Transform.translate(
                      offset: Offset(xOffset, 0),
                      child: Opacity(
                        opacity:
                            ((t < 0.15
                                    ? t / 0.15
                                    : t > 0.85
                                    ? (1.0 - t) / 0.15
                                    : 1.0))
                                .clamp(0.0, 1.0),
                        child: Icon(
                          widget.icon,
                          color: widget.highlightColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
