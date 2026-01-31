import 'package:flutter/material.dart';

class DuruhaBadge {
  final String id;
  final String title;
  final String description;
  final String criteria;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  const DuruhaBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.criteria,
    required this.icon,
    required this.color,
    this.isUnlocked = false,
  });
}
