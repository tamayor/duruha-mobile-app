import 'package:flutter/material.dart';

class DuruhaButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutline;
  final Color? backgroundColor;

  const DuruhaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutline = false,
    this.backgroundColor,
  });

  @override
  State<DuruhaButton> createState() => _DuruhaButtonState();
}

class _DuruhaButtonState extends State<DuruhaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _widthAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    if (widget.isLoading) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(DuruhaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final buttonWidth = widget.isLoading
            ? 52.0 +
                  (_widthAnimation.value *
                      (MediaQuery.of(context).size.width - 84))
            : double.infinity;

        return Center(
          child: AbsorbPointer(
            absorbing: widget.isLoading,
            child: SizedBox(
              width: buttonWidth,
              height: 52,
              child: widget.isOutline
                  ? OutlinedButton(
                      onPressed: widget.onPressed,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colorScheme.outline),
                        foregroundColor: colorScheme.onSecondary,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _buildChild(theme),
                    )
                  : FilledButton(
                      onPressed: widget.onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                      ),
                      child: _buildChild(theme),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChild(ThemeData theme) {
    if (widget.isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          color: widget.isOutline
              ? theme.colorScheme.primary
              : theme.colorScheme.onSecondary,
          strokeWidth: 2.5,
        ),
      );
    }
    return FadeTransition(
      opacity: Tween<double>(
        begin: 1.0,
        end: 1.0 - _opacityAnimation.value,
      ).animate(_controller),
      child: Text(
        widget.text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
