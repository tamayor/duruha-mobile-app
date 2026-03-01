import 'package:duruha/core/widgets/duruha_input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum SelectionLayout { wrap, column }

class DuruhaSelectionChipGroup extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> options;
  final List<String> selectedValues;
  final Function(String) onToggle;
  final bool isRequired;
  final bool isNumbered;
  final double? titleSize;
  final Widget? action;
  final Map<String, IconData>? optionIcons;
  final Map<String, String>? optionTitles;
  final Map<String, String>? optionSubtitles;
  final Map<String, String>? optionTrailingText;
  final SelectionLayout layout;
  final int limit;
  final bool showChipBox;
  final Widget? titleAction;
  final List<String>? disabledOptions;

  const DuruhaSelectionChipGroup({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
    this.limit = 10,
    this.isRequired = false,
    this.isNumbered = false,
    this.titleSize,
    this.action,
    this.optionIcons,
    this.optionTitles,
    this.optionSubtitles,
    this.optionTrailingText,
    this.layout = SelectionLayout.wrap,
    this.showChipBox = true,
    this.titleAction,
    this.disabledOptions,
  });

  @override
  State<DuruhaSelectionChipGroup> createState() =>
      _DuruhaSelectionChipGroupState();
}

class _DuruhaSelectionChipGroupState extends State<DuruhaSelectionChipGroup> {
  late ValueNotifier<List<String>> _selectedNotifier;

  @override
  void initState() {
    super.initState();
    _selectedNotifier = ValueNotifier(widget.selectedValues);
  }

  @override
  void didUpdateWidget(covariant DuruhaSelectionChipGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.selectedValues, oldWidget.selectedValues)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectedNotifier.value = widget.selectedValues;
        }
      });
    }
  }

  @override
  void dispose() {
    _selectedNotifier.dispose();
    super.dispose();
  }

  void _openSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              elevation: 12,
              clipBehavior: Clip.antiAlias,
              child: _SearchSelectionSheet(
                title: widget.title,
                options: widget.options,
                selectedNotifier: _selectedNotifier,
                onToggle: widget.onToggle,
                isNumbered: widget.isNumbered,
                optionIcons: widget.optionIcons,
                optionTitles: widget.optionTitles,
                optionSubtitles: widget.optionSubtitles,
                optionTrailingText: widget.optionTrailingText,
                disabledOptions: widget.disabledOptions,
                scrollController: scrollController,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<String> displayOptions = widget.isNumbered
        ? [
            ...widget.selectedValues,
            ...widget.options.where(
              (opt) => !widget.selectedValues.contains(opt),
            ),
          ]
        : widget.options;

    final bool showShowMore = displayOptions.length > widget.limit;
    final List<String> visibleOptions = showShowMore
        ? displayOptions.take(widget.limit).toList()
        : displayOptions;

    final int hiddenSelectedCount = widget.selectedValues
        .where((val) => !visibleOptions.contains(val))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.showChipBox ? 4 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                            fontSize: widget.titleSize,
                          ),
                        ),
                        if (widget.isRequired)
                          Text(
                            " *",
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (widget.titleAction != null) ...[
                          const SizedBox(width: 4),
                          widget.titleAction!,
                        ],
                      ],
                    ),
                    if (widget.action != null) widget.action!,
                  ],
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 5),
        ],
        if (widget.layout == SelectionLayout.wrap)
          Wrap(
            spacing: widget.showChipBox ? 10 : 8,
            runSpacing: widget.showChipBox ? 10 : 4,
            clipBehavior: Clip.none,
            children: [
              ..._buildChips(visibleOptions, colorScheme),
              if (showShowMore)
                _buildViewMoreChip(colorScheme, hiddenSelectedCount),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._buildChips(visibleOptions, colorScheme),
              if (showShowMore)
                _buildViewMoreChip(colorScheme, hiddenSelectedCount),
            ],
          ),
      ],
    );
  }

  bool get _isColumnLayout => widget.layout == SelectionLayout.column;

  List<Widget> _buildChips(
    List<String> visibleOptions,
    ColorScheme colorScheme,
  ) {
    return visibleOptions.map((option) {
      final int index = widget.selectedValues.indexOf(option);
      final bool isSelected = index != -1;
      final bool isDisabled = widget.disabledOptions?.contains(option) ?? false;

      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.optionTitles?[option] ?? option,
            style: TextStyle(fontSize: _isColumnLayout ? 14 : 13, height: 1.1),
          ),
          if (widget.optionSubtitles?[option] != null ||
              widget.optionTrailingText?[option] != null)
            const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.optionSubtitles?[option] != null)
                Text(
                  widget.optionSubtitles![option]!,
                  style: TextStyle(
                    fontSize: _isColumnLayout ? 12 : 11,
                    fontWeight: FontWeight.normal,
                    color: isSelected
                        ? colorScheme.onSecondary
                        : colorScheme.onSurfaceVariant,
                    height: 1.1,
                  ),
                ),
              const SizedBox(width: 16),
              if (widget.optionTrailingText?[option] != null)
                Text(
                  widget.optionTrailingText![option]!,
                  style: TextStyle(
                    fontSize: _isColumnLayout ? 12 : 11,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.5)
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      );

      // FIX: When showChipBox = false, the chip must be fully transparent
      // across ALL states — default, selected, pressed, hovered, focused.
      // Using a plain WidgetStateProperty.all(Colors.transparent) is not
      // enough because FilterChip applies a surface tint on top.
      // We override the full theme with a ThemeData so every state resolves
      // to transparent, removing any background bleed.
      Widget chip = widget.showChipBox
          ? _buildBoxChip(
              option,
              isSelected,
              index,
              content,
              colorScheme,
              isDisabled,
            )
          : _buildTransparentChip(
              option,
              isSelected,
              index,
              content,
              colorScheme,
              isDisabled,
            );

      if (_isColumnLayout) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: SizedBox(width: double.infinity, child: chip),
        );
      }
      return chip;
    }).toList();
  }

  // Standard chip with box/border styling
  Widget _buildBoxChip(
    String option,
    bool isSelected,
    int index,
    Widget content,
    ColorScheme colorScheme,
    bool isDisabled,
  ) {
    return FilterChip(
      label: Row(
        mainAxisSize: _isColumnLayout ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_isColumnLayout) Expanded(child: content) else content,
          if (isSelected && !widget.isNumbered) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.check_sharp,
              size: 16,
              color: colorScheme.onPrimaryContainer,
            ),
          ],
        ],
      ),
      labelStyle: TextStyle(
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      avatar: _buildAvatar(option, isSelected, index, colorScheme, isDisabled),
      selected: isSelected,
      onSelected: isDisabled ? null : (_) => widget.onToggle(option),
      showCheckmark: false,
      selectedColor: colorScheme.primaryContainer,
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          width: isSelected ? 1.5 : 1,
        ),
      ),
    );
  }

  // Fully transparent chip — no background in any state
  Widget _buildTransparentChip(
    String option,
    bool isSelected,
    int index,
    Widget content,
    ColorScheme colorScheme,
    bool isDisabled,
  ) {
    return Theme(
      // Override chip theme so ALL states resolve to transparent.
      // This prevents the Material ripple surface from showing a tinted
      // background on press/hover even when backgroundColor = transparent.
      data: Theme.of(context).copyWith(
        chipTheme: ChipThemeData(
          backgroundColor: Colors.transparent,
          selectedColor: Colors.transparent,
          disabledColor: Colors.transparent,
          secondarySelectedColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          pressElevation: 0,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      child: FilterChip(
        label: Row(
          mainAxisSize: _isColumnLayout ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_isColumnLayout) Expanded(child: content) else content,
            if (isSelected && !widget.isNumbered) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_sharp,
                size: 16,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.outlineVariant,
              ),
            ],
          ],
        ),
        labelStyle: TextStyle(
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        avatar: _buildAvatar(
          option,
          isSelected,
          index,
          colorScheme,
          isDisabled,
        ),
        selected: isSelected,
        onSelected: isDisabled ? null : (_) => widget.onToggle(option),
        showCheckmark: false,
        // All color states → transparent
        color: WidgetStateProperty.all(Colors.transparent),
        backgroundColor: Colors.transparent,
        selectedColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        pressElevation: 0,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(horizontal: 8),
        labelPadding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget? _buildAvatar(
    String option,
    bool isSelected,
    int index,
    ColorScheme colorScheme,
    bool isDisabled,
  ) {
    if (isDisabled) {
      return Icon(
        widget.optionIcons?[option] ?? Icons.block,
        size: 16,
        color: colorScheme.outline,
      );
    }
    if (widget.isNumbered && isSelected) {
      return CircleAvatar(
        radius: 10,
        backgroundColor: colorScheme.primary,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (widget.optionIcons?[option] != null) {
      return Icon(
        widget.optionIcons![option],
        size: 16,
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
      );
    }
    return null;
  }

  Widget _buildViewMoreChip(ColorScheme colorScheme, int hiddenSelectedCount) {
    final chip = ActionChip(
      avatar: Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 16),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "View More",
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (hiddenSelectedCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$hiddenSelectedCount',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onPressed: () => _openSearchSheet(context),
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline),
      ),
    );

    if (_isColumnLayout) {
      return SizedBox(width: double.infinity, child: chip);
    }
    return chip;
  }
}

class _SearchSelectionSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final ValueNotifier<List<String>> selectedNotifier;
  final Function(String) onToggle;
  final bool isNumbered;
  final Map<String, IconData>? optionIcons;
  final Map<String, String>? optionTitles;
  final Map<String, String>? optionSubtitles;
  final Map<String, String>? optionTrailingText;
  final List<String>? disabledOptions;
  final ScrollController scrollController;

  const _SearchSelectionSheet({
    required this.title,
    required this.options,
    required this.selectedNotifier,
    required this.onToggle,
    required this.isNumbered,
    this.optionIcons,
    this.optionTitles,
    this.optionSubtitles,
    this.optionTrailingText,
    this.disabledOptions,
    required this.scrollController,
  });

  @override
  State<_SearchSelectionSheet> createState() => _SearchSelectionSheetState();
}

class _SearchSelectionSheetState extends State<_SearchSelectionSheet> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<String> filteredOptions = widget.options
        .where((opt) => opt.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return ValueListenableBuilder<List<String>>(
      valueListenable: widget.selectedNotifier,
      builder: (context, selectedValues, child) {
        if (widget.isNumbered) {
          filteredOptions.sort((a, b) {
            final int indexA = selectedValues.indexOf(a);
            final int indexB = selectedValues.indexOf(b);
            final bool isASelected = indexA != -1;
            final bool isBSelected = indexB != -1;

            if (isASelected && isBSelected) return indexA.compareTo(indexB);
            if (isASelected) return -1;
            if (isBSelected) return 1;
            return 0;
          });
        }

        return Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                height: 4,
                width: 32,
                decoration: BoxDecoration(
                  color: colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Select ${widget.title}",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DuruhaInput(
                label: "Search",
                icon: Icons.search,
                hintText: "Search items...",
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                controller: widget.scrollController,
                itemCount: filteredOptions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = filteredOptions[index];
                  final int selectionIndex = selectedValues.indexOf(option);
                  final bool isSelected = selectionIndex != -1;
                  final bool isDisabled =
                      widget.disabledOptions?.contains(option) ?? false;

                  return AnimatedContainer(
                    key: ValueKey(option),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : (isDisabled
                                ? colorScheme.surfaceContainerHighest
                                : colorScheme.surface),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : (isDisabled
                                  ? colorScheme.outlineVariant
                                  : colorScheme.outline.withValues(alpha: 0.5)),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          widget.optionTitles?[option] ?? option,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isDisabled
                                ? colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.4,
                                  )
                                : colorScheme.onSurface,
                          ),
                        ),
                        subtitle:
                            (widget.optionSubtitles?[option] != null ||
                                widget.optionTrailingText?[option] != null)
                            ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (widget.optionSubtitles?[option] != null)
                                    Text(
                                      widget.optionSubtitles![option]!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  if (widget.optionTrailingText?[option] !=
                                      null)
                                    Text(
                                      widget.optionTrailingText![option]!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              )
                            : null,
                        leading: widget.isNumbered && isSelected
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: colorScheme.primary,
                                child: Text(
                                  '${selectionIndex + 1}',
                                  style: TextStyle(
                                    color: colorScheme.onSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : widget.optionIcons?[option] != null
                            ? Icon(
                                widget.optionIcons![option],
                                color: isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              )
                            : null,
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.outline,
                        ),
                        onTap: isDisabled
                            ? null
                            : () => widget.onToggle(option),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
