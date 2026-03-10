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
          if (widget.title != null ||
              widget.action != null ||
              widget.isShrinkable)
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
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: _isShrunk ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Padding(
                padding:
                    (widget.title != null ||
                        widget.action != null ||
                        widget.isShrinkable)
                    ? widget.padding.copyWith(top: 8)
                    : widget.padding,
                child: Column(
                  crossAxisAlignment: widget.crossAxisAlignment,
                  children: widget.children,
                ),
              ),
            ),
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

  /// Optional fully-custom header widget. When provided, [title], [subtitle],
  /// and [action] are ignored for the header. The header is still pinned as a
  /// [SliverPersistentHeader] and participates in shrink/expand toggling when
  /// [isShrinkable] is true (the toggle callback is passed via [onCustomHeaderToggle]).
  final Widget Function(VoidCallback toggle, bool isShrunk)? customHeader;

  /// Height of the custom header. Required when [customHeader] is provided.
  final double? customHeaderHeight;

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
    this.customHeader,
    this.customHeaderHeight,
  }) : assert(
         customHeader == null || customHeaderHeight != null,
         'customHeaderHeight must be provided when customHeader is used',
       );

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

  void _toggle() => setState(() => _isShrunk = !_isShrunk);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color effectiveBgColor =
        widget.backgroundColor ?? colorScheme.surfaceContainerLow;

    final bool hasHeader =
        widget.customHeader != null ||
        widget.title != null ||
        widget.action != null ||
        widget.isShrinkable;

    return SliverMainAxisGroup(
      slivers: [
        if (hasHeader)
          SliverPersistentHeader(
            pinned: true,
            delegate: widget.customHeader != null
                ? _DuruhaCustomHeaderDelegate(
                    height: widget.customHeaderHeight!,
                    isShrunk: _isShrunk,
                    builder: (isShrunk) =>
                        widget.customHeader!(_toggle, isShrunk),
                  )
                : _DuruhaSectionHeaderDelegate(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    action: widget.action,
                    isShrinkable: widget.isShrinkable,
                    isShrunk: _isShrunk,
                    onToggle: _toggle,
                    theme: theme,
                    colorScheme: colorScheme,
                    backgroundColor: effectiveBgColor,
                    padding: widget.padding,
                  ),
          ),
        SliverToBoxAdapter(
          child: ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: _isShrunk ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                width: double.infinity,
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
                padding: hasHeader
                    ? widget.padding.copyWith(top: 8)
                    : widget.padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                ),
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
    double baseHeight = (subtitle != null) ? 42.0 : 22.0;
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

class _DuruhaCustomHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final bool isShrunk;
  final Widget Function(bool isShrunk) builder;

  _DuruhaCustomHeaderDelegate({
    required this.height,
    required this.isShrunk,
    required this.builder,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: isShrunk == true
              ? Radius.circular(16)
              : Radius.circular(0),
          bottomRight: isShrunk == true
              ? Radius.circular(16)
              : Radius.circular(0),
        ),
      ),
      child: SizedBox.expand(child: builder(isShrunk)),
    );
  }

  @override
  bool shouldRebuild(covariant _DuruhaCustomHeaderDelegate oldDelegate) {
    return oldDelegate.isShrunk != isShrunk ||
        oldDelegate.height != height ||
        oldDelegate.builder != builder;
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
