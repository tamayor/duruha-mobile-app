import 'package:flutter/material.dart';

class DuruhaDataGrid<T> extends StatelessWidget {
  final List<T> data;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double maxCrossAxisExtent;
  final double? mainAxisExtent; // New: Forces a specific height
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Widget? emptyState;
  final bool
  isList; // New: If true, it behaves like a normal list (hugs content)

  const DuruhaDataGrid({
    super.key,
    required this.data,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.maxCrossAxisExtent = 200,
    this.mainAxisExtent,
    this.childAspectRatio = 0.8,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.isList = false, // Default is still a Grid
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return emptyState ??
          const Center(
            child: Text("No items found", style: TextStyle(color: Colors.grey)),
          );
    }

    // If it's a list, we use ListView so the cards can "hug" their height
    if (isList) {
      return ListView.separated(
        padding: padding,
        itemCount: data.length,
        separatorBuilder: (context, index) => SizedBox(height: mainAxisSpacing),
        itemBuilder: (context, index) => itemBuilder(context, data[index]),
      );
    }

    // If it's a grid, we use the delegate
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        // Using mainAxisExtent if provided, otherwise fallback to ratio
        mainAxisExtent: mainAxisExtent,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) {
        return itemBuilder(context, data[index]);
      },
    );
  }
}
