import 'package:flutter/material.dart';
import 'dart:math' as math;

class FarmerLoadingScreen extends StatefulWidget {
  final String? customMessage;

  const FarmerLoadingScreen({super.key, this.customMessage});

  @override
  State<FarmerLoadingScreen> createState() => _FarmerLoadingScreenState();
}

class _FarmerLoadingScreenState extends State<FarmerLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _plantController;
  late AnimationController _sunController;
  late AnimationController _cloudController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<String> _messages = [
    "Preparing the Soil...",
    "Sowing Seeds...",
    "Watering Crops...",
    "Harvesting Soon...",
  ];
  int _index = 0;

  @override
  void initState() {
    super.initState();

    // 1. Plant Growth
    _plantController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _plantController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _plantController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
      ),
    );

    _plantController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _index = (_index + 1) % _messages.length;
          });
          _plantController.forward(from: 0.0);
        }
      }
    });

    // 2. Sun Rotation (Really Slow)
    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30), // 20 seconds for one full spin
    )..repeat(); // No 'reverse', just continuous rotation

    // 3. Cloud Drift
    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _plantController.forward();
  }

  @override
  void dispose() {
    _plantController.dispose();
    _sunController.dispose();
    _cloudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sunColor = isDark ? const Color(0xFFFFA726) : const Color(0xFFFFC107);
    final cloudColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.15);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- SCENE AREA ---
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Sun (Rotating)
                  Positioned(
                    top: 20,
                    right: 40,
                    child: AnimatedBuilder(
                      animation: _sunController,
                      builder: (context, child) {
                        return Transform.rotate(
                          // Rotate 360 degrees (2 * pi)
                          angle: _sunController.value * 2 * math.pi,
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            size: 64,
                            color: sunColor,
                            shadows: [
                              Shadow(
                                color: sunColor.withValues(alpha: 0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Clouds
                  _buildCloud(
                    top: 40,
                    leftBase: -20,
                    size: 64,
                    color: cloudColor,
                    speedMultiplier: 1.0,
                  ),
                  _buildCloud(
                    top: 90,
                    leftBase: -50,
                    size: 48,
                    color: cloudColor,
                    speedMultiplier: 0.6,
                  ),

                  // Plant Icon
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: AnimatedBuilder(
                      animation: _plantController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Icon(
                              Icons.eco_rounded,
                              size: 64,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- TEXT: LEFT IN, RIGHT OUT ---
            SizedBox(
              height: 40,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutQuart,
                switchOutCurve: Curves.easeInQuart,
                // Custom Transition Builder for Directional Slide
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Logic:
                  // 1. Entering Child (New Text): Slides from Left (-1.0) to Center (0.0)
                  // 2. Exiting Child (Old Text): Slides from Center (0.0) to Right (1.0)

                  // How we detect: The 'child' key matches the current _index for the Entering one.
                  final isEntering = (child.key == ValueKey<int>(_index));

                  // Entering: Normal slide (-1 -> 0)
                  // Exiting: The animation runs in reverse (1 -> 0).
                  // To make it exit to the RIGHT, we need offset 1.0 when animation is 0.0.
                  // Tween(begin: 1.0, end: 0.0) does exactly that for reverse animation.

                  final offsetAnimation = isEntering
                      ? Tween<Offset>(
                          begin: const Offset(-1.0, 0.0),
                          end: Offset.zero,
                        ).animate(animation)
                      : Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                child: Text(
                  widget.customMessage ?? _messages[_index],
                  key: ValueKey<int>(_index),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- PROGRESS BAR ---
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
                borderRadius: BorderRadius.circular(4),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloud({
    required double top,
    required double leftBase,
    required double size,
    required Color color,
    required double speedMultiplier,
  }) {
    return AnimatedBuilder(
      animation: _cloudController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final distance = screenWidth + 200;
        final currentPos =
            (leftBase + (_cloudController.value * distance * speedMultiplier)) %
                distance -
            100;

        return Positioned(
          top: top,
          left: currentPos,
          child: Icon(Icons.cloud_rounded, size: size, color: color),
        );
      },
    );
  }
}
