import 'package:duruha/core/widgets/duruha_input.dart';
import 'package:flutter/material.dart';

class DuruhaSelectionChipGroup extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> options;
  final List<String> selectedValues;
  final Function(String) onToggle;
  final bool isRequired;
  final bool isNumbered;
  final double? titleSize;

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 4),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          clipBehavior: Clip.none,
          children: [
            ...visibleOptions.map((option) {
              final int index = widget.selectedValues.indexOf(option);
              final bool isSelected = index != -1;

              return FilterChip(
                label: Text(option),
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
                    : null,
                selected: isSelected,
                onSelected: (_) => widget.onToggle(option),
                showCheckmark: !widget.isNumbered,
                checkmarkColor: colorScheme.onSurface,
                selectedColor: colorScheme.primaryContainer,
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
              );
            }),
            if (showShowMore)
              ActionChip(
                avatar: Icon(
                  Icons.search,
                  color: colorScheme.onSurfaceVariant,
                  size: 16,
                ),
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
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchSelectionSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String> selectedValues;
  final Function(String) onToggle;
  final bool isNumbered;
  final ScrollController scrollController;

  const _SearchSelectionSheet({
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
    required this.isNumbered,
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
                    option,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: colorScheme.onSurface,
                    ),
                  ),
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
