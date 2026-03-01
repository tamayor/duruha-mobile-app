import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DuruhaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final double blurAmount;
  final double opacity;
  final PreferredSizeWidget? bottom;

  const DuruhaAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.blurAmount = 15,
    this.opacity = 0.2, // Low opacity is key for the glass look
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          color: (backgroundColor ?? colorScheme.surface).withValues(
            alpha: opacity,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // This SizedBox handles the Status Bar + Toolbar area
              SizedBox(
                height: topPadding + kToolbarHeight,
                child: Builder(
                  builder: (context) {
                    final canPop = Navigator.of(context).canPop();
                    final shouldShowBackButton = showBackButton && canPop;

                    return AppBar(
                      // Forces status bar icons to be visible
                      systemOverlayStyle: theme.brightness == Brightness.dark
                          ? SystemUiOverlayStyle.light
                          : SystemUiOverlayStyle.dark,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      centerTitle: false,
                      leadingWidth: shouldShowBackButton ? 56 : 0,
                      leading: shouldShowBackButton
                          ? IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 20,
                              ),
                              onPressed:
                                  onBackPressed ??
                                  () => Navigator.of(context).pop(),
                            )
                          : null,
                      title:
                          titleWidget ??
                          Text(
                            title ?? '',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                      actions: actions,
                    );
                  },
                ),
              ),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }
}
