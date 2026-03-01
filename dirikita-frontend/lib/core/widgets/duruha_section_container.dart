import 'package:flutter/material.dart';

enum DuruhaContainerStyle { filled, outlined }

class DuruhaSectionContainer extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;
  final Color? backgroundColor;
  final DuruhaContainerStyle style;
  final bool isShrinkable;
  final bool initialShrunk;
  final bool? shrinkOverride;

  const DuruhaSectionContainer({
    super.key,
    this.title,
    this.subtitle,
    this.action,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.backgroundColor,
    this.style = DuruhaContainerStyle.filled,
    this.isShrinkable = false,
    this.initialShrunk = false,
    this.shrinkOverride,
  });

  @override
  State<DuruhaSectionContainer> createState() => _DuruhaSectionContainerState();
}

class _DuruhaSectionContainerState extends State<DuruhaSectionContainer> {
  late bool _isShrunk;

  @override
  void initState() {
    super.initState();
    _isShrunk = widget.shrinkOverride ?? widget.initialShrunk;
  }

  @override
  void didUpdateWidget(DuruhaSectionContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shrinkOverride != oldWidget.shrinkOverride &&
        widget.shrinkOverride != null) {
      _isShrunk = widget.shrinkOverride!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color effectiveBgColor = widget.style == DuruhaContainerStyle.filled
        ? (widget.backgroundColor ??
              colorScheme.surfaceContainerLow.withValues(alpha: 0.5))
        : Colors.transparent;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: widget.crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          // MATERIAL + INKWELL wrapped around the PADDING
          if (widget.title != null || widget.action != null || widget.isShrinkable)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isShrinkable
                    ? () => setState(() => _isShrunk = !_isShrunk)
                    : null,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(16),
                  bottom: Radius.circular(_isShrunk ? 16 : 0),
                ),
                child: Padding(
                  padding: widget.padding,
                  child: _SectionHeader(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    action: widget.action,
                    isShrinkable: widget.isShrinkable,
                    isShrunk: _isShrunk,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ),
              ),
            ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: (widget.title != null || widget.action != null || widget.isShrinkable)
                  ? widget.padding.copyWith(top: 8)
                  : widget.padding,
              child: Column(
                crossAxisAlignment: widget.crossAxisAlignment,
                children: widget.children,
              ),
            ),
            crossFadeState: _isShrunk
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class DuruhaSliverSectionContainer extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final DuruhaContainerStyle style;
  final bool isShrinkable;
  final bool initialShrunk;
  final bool? shrinkOverride;

  const DuruhaSliverSectionContainer({
    super.key,
    this.title,
    this.subtitle,
    this.action,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.style = DuruhaContainerStyle.filled,
    this.isShrinkable = true,
    this.initialShrunk = false,
    this.shrinkOverride,
  });

  @override
  State<DuruhaSliverSectionContainer> createState() =>
      _DuruhaSliverSectionContainerState();
}

class _DuruhaSliverSectionContainerState
    extends State<DuruhaSliverSectionContainer> {
  late bool _isShrunk;

  @override
  void initState() {
    super.initState();
    _isShrunk = widget.shrinkOverride ?? widget.initialShrunk;
  }

  @override
  void didUpdateWidget(DuruhaSliverSectionContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shrinkOverride != oldWidget.shrinkOverride &&
        widget.shrinkOverride != null) {
      _isShrunk = widget.shrinkOverride!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color effectiveBgColor =
        widget.backgroundColor ?? colorScheme.surfaceContainerLow;

    return SliverMainAxisGroup(
      slivers: [
        if (widget.title != null || widget.action != null || widget.isShrinkable)
          SliverPersistentHeader(
            pinned: true,
            delegate: _DuruhaSectionHeaderDelegate(
              title: widget.title,
              subtitle: widget.subtitle,
              action: widget.action,
              isShrinkable: widget.isShrinkable,
              isShrunk: _isShrunk,
              onToggle: () => setState(() => _isShrunk = !_isShrunk),
              theme: theme,
              colorScheme: colorScheme,
              backgroundColor: effectiveBgColor,
              padding: widget.padding,
            ),
          ),
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isShrunk
                ? const SizedBox(width: double.infinity, height: 0)
                : Container(
                    decoration: BoxDecoration(
                      color: effectiveBgColor.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      border: Border(
                        left: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                        right: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                        bottom: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    padding: (widget.title != null || widget.action != null || widget.isShrinkable)
                        ? widget.padding.copyWith(top: 8)
                        : widget.padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.children,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DuruhaSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String? title;
  final String? subtitle;
  final Widget? action;
  final bool isShrinkable;
  final bool isShrunk;
  final VoidCallback onToggle;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final Color backgroundColor;
  final EdgeInsets padding;

  _DuruhaSectionHeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.isShrinkable,
    required this.isShrunk,
    required this.onToggle,
    required this.theme,
    required this.colorScheme,
    required this.backgroundColor,
    required this.padding,
  });

  double get _calculatedHeight {
    double baseHeight = (subtitle != null) ? 52.0 : 32.0;
    return baseHeight + padding.vertical;
  }

  @override
  double get minExtent => _calculatedHeight;
  @override
  double get maxExtent => _calculatedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(16),
          bottom: Radius.circular(isShrunk ? 16 : 0),
        ),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isShrinkable ? onToggle : null,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16),
            bottom: Radius.circular(isShrunk ? 16 : 0),
          ),
          child: Padding(
            padding: padding,
            child: _SectionHeader(
              title: title,
              subtitle: subtitle,
              action: action,
              isShrinkable: isShrinkable,
              isShrunk: isShrunk,
              theme: theme,
              colorScheme: colorScheme,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DuruhaSectionHeaderDelegate oldDelegate) {
    return oldDelegate.isShrunk != isShrunk ||
        oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle;
  }
}

class _SectionHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? action;
  final bool isShrinkable;
  final bool isShrunk;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.isShrinkable,
    required this.isShrunk,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (title != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(width: 8),
        if (action != null) action!,
        if (isShrinkable)
          AnimatedRotation(
            turns: isShrunk ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
