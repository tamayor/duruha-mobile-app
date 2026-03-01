import 'package:flutter/material.dart';

enum DuruhaSnackBarType { success, error, warning, info, neutral }

class DuruhaSnackBar {
  static OverlayEntry? _currentOverlay;

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    DuruhaSnackBarType type = DuruhaSnackBarType.neutral,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onActionPressed,
    String? actionLabel,
    IconData? customIcon,
    Color? customColor,
  }) {
    // Remove any existing snackbar immediately
    _currentOverlay?.remove();
    _currentOverlay = null;

    final theme = Theme.of(context);

    Color backgroundColor;
    Color foregroundColor;
    IconData icon;

    switch (type) {
      case DuruhaSnackBarType.success:
        backgroundColor = const Color.fromARGB(255, 56, 126, 59);
        foregroundColor = Colors.white;
        icon = Icons.check_circle_outline_rounded;
        break;
      case DuruhaSnackBarType.error:
        backgroundColor = theme.colorScheme.error;
        foregroundColor = theme.colorScheme.onError;
        icon = Icons.error_outline_rounded;
        break;
      case DuruhaSnackBarType.warning:
        backgroundColor = Colors.orange.shade800;
        foregroundColor = Colors.white;
        icon = Icons.warning_amber_rounded;
        break;
      case DuruhaSnackBarType.info:
        backgroundColor = theme.colorScheme.primary;
        foregroundColor = theme.colorScheme.onPrimary;
        icon = Icons.info_outline_rounded;
        break;
      case DuruhaSnackBarType.neutral:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        foregroundColor = theme.colorScheme.onSecondary;
        icon = Icons.notifications_none_rounded;
        break;
    }

    if (customColor != null) backgroundColor = customColor;
    if (customIcon != null) icon = customIcon;

    _currentOverlay = OverlayEntry(
      builder: (context) => _SnackBarOverlay(
        title: title,
        message: message,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        icon: icon,
        actionLabel: actionLabel,
        onActionPressed: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
          onActionPressed?.call();
        },
        duration: duration,
        onDismissed: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  // --- RESTORED CONVENIENCE FUNCTIONS ---

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.success,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.error,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.warning,
    );
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.info,
    );
  }

  static void showNeutral(
    BuildContext context,
    String message, {
    String? title,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.neutral,
    );
  }
}

// --- INTERNAL OVERLAY WIDGET ---
class _SnackBarOverlay extends StatefulWidget {
  final String? title;
  final String message;
  final Color backgroundColor, foregroundColor;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback onActionPressed;
  final VoidCallback onDismissed;
  final Duration duration;

  const _SnackBarOverlay({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.onActionPressed,
    required this.onDismissed,
    required this.duration,
    this.title,
    this.actionLabel,
  });

  @override
  State<_SnackBarOverlay> createState() => _SnackBarOverlayState();
}

class _SnackBarOverlayState extends State<_SnackBarOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 2.5),
      end: Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Dismissible(
            key: Key(widget.message),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => widget.onDismissed(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                  ), // Better for tablets/web
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.foregroundColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.foregroundColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.title != null)
                              Text(
                                widget.title!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: widget.foregroundColor,
                                  fontSize: 14,
                                ),
                              ),
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: widget.foregroundColor.withValues(
                                  alpha: 0.9,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.actionLabel != null)
                        TextButton(
                          onPressed: widget.onActionPressed,
                          child: Text(
                            widget.actionLabel!,
                            style: TextStyle(
                              color: widget.foregroundColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
