import 'package:duruha/core/constants/delivery_statuses.dart';
import 'package:flutter/material.dart';

enum BadgeSize { tiny, small, medium }

class DuruhaStatusBadge extends StatelessWidget {
  final String? status;
  final String? label;
  final Color? color;
  final BadgeSize size;
  final bool isOutlined;
  final bool strikethrough;

  const DuruhaStatusBadge({
    super.key,
    this.status,
    this.label,
    this.color,
    this.size = BadgeSize.small,
    this.isOutlined = false,
    this.strikethrough = false,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve color: use provided color, or get from status, or fallback to grey
    final badgeColor = color ?? DeliveryStatus.getStatusColor(status);

    // Resolve label: use provided label, or get display label from status
    final badgeLabel =
        label ??
        (status != null ? DeliveryStatus.getDisplayLabel(status!) : '');

    double fontSize;
    EdgeInsets padding;
    double borderRadius;
    FontWeight fontWeight = FontWeight.bold;
    double borderOpacity = 0.3;
    double bgOpacity = 0.12;

    switch (size) {
      case BadgeSize.tiny:
        fontSize = 9;
        padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
        borderRadius = 4;
        fontWeight = FontWeight.w900;
        bgOpacity = 0.08;
        break;
      case BadgeSize.small:
        fontSize = 10;
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
        borderRadius = 20;
        break;
      case BadgeSize.medium:
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
        borderRadius = 20;
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: bgOpacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: isOutlined
            ? Border.all(
                color: badgeColor.withValues(alpha: borderOpacity),
                width: 0.5,
              )
            : null,
      ),
      child: Text(
        badgeLabel,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: badgeColor,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
          letterSpacing: size == BadgeSize.medium ? 0.5 : null,
        ),
      ),
    );
  }
}
