import 'package:duruha/core/widgets/duruha_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DuruhaToggleButton extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? labelTrue;
  final String? labelFalse;
  final IconData? iconTrue;
  final IconData? iconFalse;
  final Color? colorTrue;
  final Color? colorFalse;
  final Color? contentColorTrue;
  final Color? contentColorFalse;
  final String? descriptionTrue;
  final String? descriptionFalse;

  const DuruhaToggleButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelTrue,
    this.labelFalse,
    this.iconTrue,
    this.iconFalse,
    this.colorTrue,
    this.colorFalse,
    this.contentColorTrue,
    this.contentColorFalse,
    this.descriptionTrue,
    this.descriptionFalse,
  });

  @override
  State<DuruhaToggleButton> createState() => _DuruhaToggleButtonState();
}

class _DuruhaToggleButtonState extends State<DuruhaToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(-0.2, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final activeColor = widget.colorTrue ?? theme.colorScheme.primary;
    final inactiveColor = widget.colorFalse ?? theme.colorScheme.tertiary;

    final activeContentColor =
        widget.contentColorTrue ?? theme.colorScheme.onPrimary;
    final inactiveContentColor =
        widget.contentColorFalse ?? theme.colorScheme.onTertiary;

    final isActive = widget.value;
    final currentColor = isActive ? activeColor : inactiveColor;
    final currentContentColor = isActive
        ? activeContentColor
        : inactiveContentColor;

    final currentLabel = isActive ? widget.labelTrue : widget.labelFalse;
    final currentIcon = isActive ? widget.iconTrue : widget.iconFalse;

    final bool isIconOnly = currentLabel?.isEmpty ?? true;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final newValue = !widget.value;
              widget.onChanged(newValue);
              HapticFeedback.lightImpact();

              final description = newValue
                  ? widget.descriptionTrue
                  : widget.descriptionFalse;

              if (description != null) {
                final snackColor = newValue
                    ? (widget.colorTrue ?? theme.colorScheme.primary)
                    : (widget.colorFalse ?? theme.colorScheme.tertiary);

                DuruhaSnackBar.show(
                  context,
                  message: description,
                  title:
                      (newValue ? widget.labelTrue : widget.labelFalse) ??
                      "Toggle",
                  customColor: snackColor,
                  type: DuruhaSnackBarType.info,
                );
              }
            },
            borderRadius: BorderRadius.circular(100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isIconOnly ? 48 : null,
              height: isIconOnly ? 48 : null,
              padding: isIconOnly
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: isIconOnly
                  ? null
                  : BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Icon with Vertical Switch effect
                    if (currentIcon != null) ...[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              final inAnimation = Tween<Offset>(
                                begin: const Offset(0.0, -0.5),
                                end: Offset.zero,
                              ).animate(animation);

                              final outAnimation = Tween<Offset>(
                                begin: const Offset(0.0, 0.5),
                                end: Offset.zero,
                              ).animate(animation);

                              if (child.key == ValueKey(isActive)) {
                                return SlideTransition(
                                  position: inAnimation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              } else {
                                return SlideTransition(
                                  position: outAnimation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              }
                            },
                        child: Icon(
                          currentIcon,
                          key: ValueKey<bool>(isActive),
                          color: currentContentColor,
                          size: 20,
                        ),
                      ),
                    ],

                    if (!isIconOnly) ...[
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axis: Axis.horizontal,
                                  axisAlignment: -1.0,
                                  child: child,
                                ),
                              );
                            },
                        child: Text(
                          currentLabel!,
                          key: ValueKey<bool>(isActive),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: currentContentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
