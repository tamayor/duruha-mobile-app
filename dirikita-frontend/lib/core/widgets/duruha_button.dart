import 'package:flutter/material.dart';

class DuruhaButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutline;
  final Color? backgroundColor;
  final Icon? icon;
  final bool isFullWidth;
  final double? width;
  final double height;
  final bool isSmall;

  const DuruhaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutline = false,
    this.backgroundColor,
    this.icon,
    this.isFullWidth = true,
    this.width,
    this.height = 52,
    this.isSmall = false,
  });

  @override
  State<DuruhaButton> createState() => _DuruhaButtonState();
}

class _DuruhaButtonState extends State<DuruhaButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveHeight = widget.isSmall ? 36.0 : widget.height;
    final buttonWidth = widget.isLoading
        ? effectiveHeight
        : (widget.width ??
              (widget.isFullWidth ? MediaQuery.of(context).size.width : null));

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: buttonWidth,
        height: effectiveHeight,
        curve: Curves.easeInOut,
        child: widget.isOutline
            ? OutlinedButton(
                onPressed: widget.isLoading ? null : widget.onPressed,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.outline),
                  foregroundColor: colorScheme.onSecondary,
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(
                    vertical: widget.isSmall ? 4 : 12,
                    horizontal: widget.isSmall ? 12 : 24,
                  ),
                ),
                child: _buildChild(theme),
              )
            : FilledButton(
                onPressed: widget.isLoading ? null : widget.onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      widget.backgroundColor ?? colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(
                    vertical: widget.isSmall ? 4 : 12,
                    horizontal: widget.isSmall ? 12 : 24,
                  ),
                  elevation: 2,
                ),
                child: _buildChild(theme),
              ),
      ),
    );
  }

  Widget _buildChild(ThemeData theme) {
    if (widget.isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          color: widget.isOutline
              ? theme.colorScheme.primary
              : theme.colorScheme.onPrimary,
          strokeWidth: 2.5,
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: widget.isSmall ? 12 : 16,
              letterSpacing: 0.5,
            ),
          ),
          if (widget.icon != null) ...[const SizedBox(width: 8), widget.icon!],
        ],
      ),
    );
  }
}
