import 'package:flutter/material.dart';

class DuruhaGridView extends StatelessWidget {
  final List<Widget>? children;
  final NullableIndexedWidgetBuilder? itemBuilder;
  final int? itemCount;

  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Creates a standard Duruha GridView from an explicit array of widgets.
  const DuruhaGridView({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 2,
    this.mainAxisSpacing = 2,
    this.childAspectRatio = 0.85,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  }) : itemBuilder = null,
       itemCount = null;

  /// Creates a standard Duruha GridView that builds its children on demand.
  const DuruhaGridView.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 2,
    this.mainAxisSpacing = 2,
    this.childAspectRatio = 0.85,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  }) : children = null;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding ?? EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount ?? children?.length,
      itemBuilder: children != null
          ? (context, index) => children![index]
          : itemBuilder!,
    );
  }
}
