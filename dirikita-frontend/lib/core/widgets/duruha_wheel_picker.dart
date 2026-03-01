import 'package:flutter/material.dart';

class DuruhaWheelPicker<T> extends StatefulWidget {
  final List<T> items;
  final T? selectedValue;
  final ValueChanged<T>? onChanged;
  final String Function(T)? labelBuilder;
  final Color Function(T)? itemColorBuilder;
  final bool Function(T)? itemEnabledBuilder;
  final bool enabled;
  final double height;
  final double itemExtent;
  final double diameterRatio;
  final double perspective;
  final double magnification;
  final bool useMagnifier;

  const DuruhaWheelPicker({
    super.key,
    required this.items,
    this.selectedValue,
    this.onChanged,
    this.labelBuilder,
    this.itemColorBuilder,
    this.itemEnabledBuilder,
    this.enabled = true,
    this.height = 50.0,
    this.itemExtent = 75.0,
    this.diameterRatio = 0.7,
    this.perspective = 0.001,
    this.magnification = 1,
    this.useMagnifier = false,
  });

  @override
  State<DuruhaWheelPicker<T>> createState() => _DuruhaWheelPickerState<T>();
}

class _DuruhaWheelPickerState<T> extends State<DuruhaWheelPicker<T>> {
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.items.indexOf(widget.selectedValue as T);
    _scrollController = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void didUpdateWidget(DuruhaWheelPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedValue != oldWidget.selectedValue) {
      final newIndex = widget.items.indexOf(widget.selectedValue as T);
      if (newIndex >= 0 &&
          _scrollController.hasClients &&
          _scrollController.selectedItem != newIndex) {
        _scrollController.animateToItem(
          newIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _snapBackToOriginal() {
    final originalIndex = widget.items.indexOf(widget.selectedValue as T);
    if (originalIndex >= 0) {
      // Small delay to let physics settle slightly before snapping back
      Future.delayed(Duration.zero, () {
        if (_scrollController.hasClients) {
          _scrollController.animateToItem(
            originalIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = widget.items.indexOf(widget.selectedValue as T);
    final statusColor =
        widget.itemColorBuilder != null && widget.selectedValue != null
        ? widget.itemColorBuilder!(widget.selectedValue as T)
        : theme.colorScheme.primary;

    return Container(
      height: widget.height,
      width: double.infinity,
      transformAlignment: Alignment.center,
      transform: Matrix4.translationValues(0, 0, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Selection Highlight
          IgnorePointer(
            child: Container(
              width: widget.itemExtent + 20,
              height: widget.height - 14, // Adjusted relative to height
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withAlpha(100), width: 1),
              ),
            ),
          ),

          // The Scroller
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  widget.selectedValue != null) {
                // Determine if we need to snap back
                bool shouldSnapBack = false;

                if (!widget.enabled) {
                  shouldSnapBack = true;
                } else if (widget.itemEnabledBuilder != null) {
                  final scrolledIndex = _scrollController.selectedItem;
                  if (scrolledIndex >= 0 &&
                      scrolledIndex < widget.items.length) {
                    final isItemEnabled = widget.itemEnabledBuilder!(
                      widget.items[scrolledIndex],
                    );
                    if (!isItemEnabled) {
                      shouldSnapBack = true;
                    }
                  }
                }

                if (shouldSnapBack) {
                  _snapBackToOriginal();
                }
              }
              return false;
            },
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.15, 0.85, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: RotatedBox(
                quarterTurns: 3, // Rotates the whole list to be horizontal
                child: ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: widget.itemExtent,
                  diameterRatio: widget.diameterRatio,
                  perspective: widget.perspective,
                  useMagnifier: widget.useMagnifier,
                  magnification: widget.magnification,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    if (widget.enabled &&
                        index >= 0 &&
                        index < widget.items.length) {
                      widget.onChanged?.call(widget.items[index]);
                    }
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.items.length,
                    builder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = index == currentIndex;
                      final itemColor = widget.itemColorBuilder != null
                          ? widget.itemColorBuilder!(item)
                          : theme.colorScheme.primary;

                      final label = widget.labelBuilder != null
                          ? widget.labelBuilder!(item)
                          : item.toString();

                      return RotatedBox(
                        quarterTurns: 1, // Flips text back to upright
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isSelected ? 1.0 : 0.4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ), // Added padding for safety
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,

                                children: [
                                  Flexible(
                                    child: Text(
                                      label.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      // maxLines: 1, // Removed to allow wrapping
                                      // overflow: TextOverflow.visible, // Default is fine for wrapping
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? (widget.enabled
                                                  ? itemColor
                                                  : theme.colorScheme.onPrimary)
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
