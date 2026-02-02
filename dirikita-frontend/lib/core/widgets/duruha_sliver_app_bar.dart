import 'package:flutter/material.dart';

class DuruhaSliverAppBar extends StatelessWidget {
  final String title;
  final String imageUrl;
  final List<Widget>? actions;
  final double expandedHeight;
  final Widget? leading;
  final bool stretch;
  final Color? backgroundColor;

  const DuruhaSliverAppBar({
    super.key,
    required this.title,
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

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      stretch: stretch,
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
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
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        title: Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
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
