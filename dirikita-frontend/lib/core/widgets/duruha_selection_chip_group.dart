import 'package:duruha/core/widgets/duruha_input.dart';
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
  final SelectionLayout layout;

  const DuruhaSelectionChipGroup({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
    this.isRequired = false,
    this.isNumbered = false,
    this.titleSize,
    this.action,
    this.optionIcons,
    this.optionTitles,
    this.optionSubtitles,
    this.layout = SelectionLayout.wrap,
  });

  @override
  State<DuruhaSelectionChipGroup> createState() =>
      _DuruhaSelectionChipGroupState();
}

class _DuruhaSelectionChipGroupState extends State<DuruhaSelectionChipGroup> {
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
                selectedValues: widget.selectedValues,
                onToggle: widget.onToggle,
                isNumbered: widget.isNumbered,
                optionIcons: widget.optionIcons,
                optionTitles: widget.optionTitles,
                optionSubtitles: widget.optionSubtitles,
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

    // Sequencing for the main view chips
    final List<String> displayOptions = widget.isNumbered
        ? [
            ...widget.selectedValues,
            ...widget.options.where(
              (opt) => !widget.selectedValues.contains(opt),
            ),
          ]
        : widget.options;

    const int limit = 10;
    final bool showShowMore = displayOptions.length > limit;
    final List<String> visibleOptions = showShowMore
        ? displayOptions.take(limit).toList()
        : displayOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
            spacing: 10,
            runSpacing: -3,
            clipBehavior: Clip.none,
            children: [
              ..._buildChips(visibleOptions, colorScheme),
              if (showShowMore) _buildViewMoreChip(colorScheme),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._buildChips(visibleOptions, colorScheme),
              if (showShowMore) _buildViewMoreChip(colorScheme),
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

      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.optionTitles?[option] ?? option,
            style: TextStyle(fontSize: _isColumnLayout ? 14 : 13, height: 1.1),
          ),
          if (widget.optionSubtitles?[option] != null)
            Text(
              widget.optionSubtitles![option]!,
              style: TextStyle(
                fontSize: _isColumnLayout ? 11 : 10,
                fontWeight: FontWeight.normal,
                color: isSelected
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                    : colorScheme.onSurfaceVariant,
                height: 1.1,
              ),
            ),
        ],
      );

      final chip = FilterChip(
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
        avatar: (widget.isNumbered && isSelected)
            ? CircleAvatar(
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
              )
            : (widget.optionIcons?[option] != null
                  ? Icon(
                      widget.optionIcons![option],
                      size: 16,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    )
                  : null),
        selected: isSelected,
        onSelected: (_) => widget.onToggle(option),
        showCheckmark: false,
        checkmarkColor: colorScheme.onPrimaryContainer,
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

      if (_isColumnLayout) {
        return Padding(
          padding: const EdgeInsets.only(bottom: .5),
          child: SizedBox(width: double.infinity, child: chip),
        );
      }
      return chip;
    }).toList();
  }

  Widget _buildViewMoreChip(ColorScheme colorScheme) {
    final chip = ActionChip(
      avatar: Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 16),
      label: Text(
        "View More",
        style: TextStyle(color: colorScheme.onSurfaceVariant),
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
  final List<String> selectedValues;
  final Function(String) onToggle;
  final bool isNumbered;
  final Map<String, IconData>? optionIcons;
  final Map<String, String>? optionTitles;
  final Map<String, String>? optionSubtitles;
  final ScrollController scrollController;

  const _SearchSelectionSheet({
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
    required this.isNumbered,
    this.optionIcons,
    this.optionTitles,
    this.optionSubtitles,
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

    // Filtered options based on search query
    List<String> filteredOptions = widget.options
        .where((opt) => opt.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    // Sequencing logic: Selected items move to top based on selection order
    if (widget.isNumbered) {
      filteredOptions.sort((a, b) {
        final int indexA = widget.selectedValues.indexOf(a);
        final int indexB = widget.selectedValues.indexOf(b);
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
        // Handle bar for better layering feel
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
              final int selectionIndex = widget.selectedValues.indexOf(option);
              final bool isSelected = selectionIndex != -1;

              return AnimatedContainer(
                key: ValueKey(option),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surface,
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.5),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
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
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: widget.optionSubtitles?[option] != null
                      ? Text(
                          widget.optionSubtitles![option]!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
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
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.outline,
                  ),
                  onTap: () {
                    widget.onToggle(option);
                    setState(() {});
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
