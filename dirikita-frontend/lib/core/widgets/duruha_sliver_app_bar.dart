import 'package:flutter/material.dart';

class DuruhaSliverAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final String imageUrl;
  final List<Widget>? actions;
  final double expandedHeight;
  final Widget? leading;
  final bool stretch;
  final Color? backgroundColor;

  const DuruhaSliverAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    required this.imageUrl,
    this.actions,
    this.expandedHeight = 280,
    this.leading,
    this.stretch = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget buildTitle() {
      if (titleWidget != null) return titleWidget!;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                fontSize:
                    12, // Needs to be small to avoid clipping during collapse
              ),
            ),
        ],
      );
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      stretch: stretch,
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: titleWidget,
      leading:
          leading ??
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.2),
            ),
          ),
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: titleWidget != null ? null : buildTitle(),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
