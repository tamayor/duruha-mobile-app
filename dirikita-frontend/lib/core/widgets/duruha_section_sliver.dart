import 'package:flutter/material.dart';

class DuruhaSectionSliver extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget content;
  final double headerHeight;
  final double footerHeight;
  final EdgeInsets headerPadding;
  final EdgeInsets contentPadding;
  final bool initiallyCompact;
  final bool? compactOverride;

  const DuruhaSectionSliver({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.content,
    this.headerHeight = 80,
    this.footerHeight = 0,
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
    this.initiallyCompact = false,
    this.compactOverride,
  });

  @override
  State<DuruhaSectionSliver> createState() => _DuruhaSectionSliverState();
}

class _DuruhaSectionSliverState extends State<DuruhaSectionSliver> {
  late bool _isCompact;

  @override
  void initState() {
    super.initState();
    _isCompact = widget.compactOverride ?? widget.initiallyCompact;
  }

  @override
  void didUpdateWidget(DuruhaSectionSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compactOverride != oldWidget.compactOverride &&
        widget.compactOverride != null) {
      _isCompact = widget.compactOverride!;
    }
  }

  void _toggleCompact() {
    setState(() {
      _isCompact = !_isCompact;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Provide a trailing expanding/collapsing icon if none provided, or wrap existing?
    // User requested "toggle compact on and off when header is click".
    // We can add a simple rotatable icon or just rely on the tap anywhere.
    // Let's rely on tap anywhere on the header as requested.

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _DuruhaSectionHeaderDelegate(
            title: widget.title,
            subtitle: widget.subtitle,
            leading: widget.leading,
            trailing:
                widget.trailing ??
                Icon(
                  _isCompact ? Icons.expand_more : Icons.expand_less,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            height: widget.headerHeight,
            padding: widget.headerPadding,
            theme: theme,
            onTap: _toggleCompact,
          ),
        ),
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isCompact
                ? const SizedBox.shrink()
                : Padding(
                    padding: widget.contentPadding,
                    child: widget.content,
                  ),
          ),
        ),
        if (widget.footerHeight > 0)
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isCompact
                  ? const SizedBox.shrink()
                  : SizedBox(height: widget.footerHeight),
            ),
          ),
      ],
    );
  }
}

class _DuruhaSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final EdgeInsets padding;
  final ThemeData theme;
  final VoidCallback onTap;

  _DuruhaSectionHeaderDelegate({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.height,
    required this.padding,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: padding.left),
        height: height,
        width: MediaQuery.of(context).size.width,
        padding: padding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 16)],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _DuruhaSectionHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle ||
        oldDelegate.leading != leading ||
        oldDelegate.trailing != trailing ||
        oldDelegate.theme != theme ||
        oldDelegate.onTap != onTap;
  }
}
