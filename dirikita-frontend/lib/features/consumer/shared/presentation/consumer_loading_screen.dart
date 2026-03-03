import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConsumerLoadingScreen extends StatefulWidget {
  final String? customMessage;

  const ConsumerLoadingScreen({super.key, this.customMessage});

  @override
  State<ConsumerLoadingScreen> createState() => _ConsumerLoadingScreenState();
}

class _ConsumerLoadingScreenState extends State<ConsumerLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _cartController;
  late AnimationController _sparkleController;
  late AnimationController _tagController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

  final List<String> _messages = [
    "Browsing Fresh Picks...",
    "Finding Best Deals...",
    "Packing Your Order...",
    "Almost Ready!",
  ];

  final List<IconData> _icons = [
    Icons.storefront_rounded,
    Icons.local_offer_rounded,
    Icons.shopping_bag_rounded,
    Icons.check_circle_rounded,
  ];

  int _index = 0;

  @override
  void initState() {
    super.initState();

    // 1. Cart Icon Animation
    _cartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cartController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cartController,
        curve: const Interval(0.55, 0.75, curve: Curves.easeInOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _cartController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
      ),
    );

    _cartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _index = (_index + 1) % _messages.length;
          });
          _cartController.forward(from: 0.0);
        }
      }
    });

    // 2. Sparkle / Coin Spin
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 3. Price Tag Drift (replaces clouds)
    _tagController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _cartController.forward();
  }

  @override
  void dispose() {
    _cartController.dispose();
    _sparkleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accentColor = isDark
        ? const Color(0xFFFF7043)
        : const Color(0xFFFF5722);
    final tagColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : theme.colorScheme.onPrimary.withValues(alpha: 0.08);

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
                  // Sparkle / Coin rotating top-right
                  Positioned(
                    top: 18,
                    right: 40,
                    child: AnimatedBuilder(
                      animation: _sparkleController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _sparkleController.value * 2 * math.pi,
                          child: Icon(
                            Icons.monetization_on_rounded,
                            size: 56,
                            color: accentColor,
                            shadows: [
                              Shadow(
                                color: accentColor.withValues(alpha: 0.35),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Drifting price tags (replace clouds)
                  _buildDriftingTag(
                    top: 36,
                    leftBase: -30,
                    size: 40,
                    color: tagColor,
                    icon: Icons.local_offer_rounded,
                    speedMultiplier: 1.0,
                  ),
                  _buildDriftingTag(
                    top: 88,
                    leftBase: -60,
                    size: 30,
                    color: tagColor,
                    icon: Icons.sell_rounded,
                    speedMultiplier: 0.65,
                  ),

                  // Main animated icon
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: AnimatedBuilder(
                      animation: _cartController,
                      builder: (context, child) {
                        // Slight vertical bounce at peak
                        final bounceOffset =
                            math.sin(_bounceAnimation.value * math.pi) * 6.0;
                        return Opacity(
                          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, -bounceOffset),
                            child: Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Icon(
                                _icons[_index],
                                size: 68,
                                color: theme.colorScheme.onPrimary,
                              ),
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

            // --- ANIMATED MESSAGE ---
            SizedBox(
              height: 40,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutQuart,
                switchOutCurve: Curves.easeInQuart,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final isEntering = (child.key == ValueKey<int>(_index));

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
                  theme.colorScheme.onPrimary.withValues(alpha: 0.8),
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

  Widget _buildDriftingTag({
    required double top,
    required double leftBase,
    required double size,
    required Color color,
    required IconData icon,
    required double speedMultiplier,
  }) {
    return AnimatedBuilder(
      animation: _tagController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final distance = screenWidth + 200;
        final currentPos =
            (leftBase + (_tagController.value * distance * speedMultiplier)) %
                distance -
            100;

        return Positioned(
          top: top,
          left: currentPos,
          child: Icon(icon, size: size, color: color),
        );
      },
    );
  }
}
