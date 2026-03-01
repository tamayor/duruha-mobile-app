import 'package:flutter/material.dart';

class DuruhaBottomSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final double heightFactor;
  final bool isScrollable;
  final EdgeInsets? contentPadding;

  const DuruhaBottomSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.heightFactor = 0.95,
    this.isScrollable = true,
    this.contentPadding,
  });

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
      barrierColor: Colors.black.withAlpha(120),
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 450),
      ),
      builder: (context) {
        return DuruhaBottomSheet(
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
  State<DuruhaBottomSheet> createState() => _DuruhaBottomSheetState();
}

class _DuruhaBottomSheetState extends State<DuruhaBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.97,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Trigger entrance animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    await _controller.reverse();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * widget.heightFactor,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Animated drag handle
            GestureDetector(
              onTap: _handleClose,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 4,
                    width: 40 * _controller.value, // grows in on open
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: Icon(
                      widget.icon,
                      color: theme.colorScheme.onSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                            fontSize: 20,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Animated close button
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: IconButton(
                      onPressed: _handleClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),

            // Animated divider
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 1,
                    width: MediaQuery.of(context).size.width * value,
                    color: theme.colorScheme.outline.withAlpha(30),
                  ),
                );
              },
            ),

            // Content area
            Expanded(
              child: widget.isScrollable
                  ? SingleChildScrollView(
                      padding:
                          widget.contentPadding ??
                          const EdgeInsets.symmetric(horizontal: 8),
                      child: widget.child,
                    )
                  : Padding(
                      padding:
                          widget.contentPadding ??
                          const EdgeInsets.symmetric(horizontal: 8),
                      child: widget.child,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
