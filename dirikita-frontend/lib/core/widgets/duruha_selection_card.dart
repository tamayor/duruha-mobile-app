import 'package:duruha/core/widgets/duruha_inkwell.dart';
import 'package:flutter/material.dart';

class DuruhaSelectionCard extends StatelessWidget {
  final String title, subtitle;
  final String? imageUrl;
  final IconData? icon;
  final bool isSelected;
  final bool isList; // Manual override from parent
  final VoidCallback onTap;

  const DuruhaSelectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.icon,
    required this.isSelected,
    required this.isList, // Required to handle parent layout logic
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The logic: If parent says isList, we force Horizontal.
    // Otherwise, we use the vertical grid style.
    Widget content = isList
        ? _buildHorizontal(colorScheme)
        : _buildVertical(colorScheme);

    return Padding(
      // Small margin to prevent borders from touching in a list
      padding: EdgeInsets.symmetric(vertical: isList ? 4 : 0),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isSelected ? 2 : 0,
        clipBehavior: Clip.antiAlias,
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.6)
            : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            // Subtle border when not selected, Primary when selected
            color: isSelected ? colorScheme.outline : colorScheme.outline,
            width: isSelected ? 0 : 1,
          ),
        ),
        child: DuruhaInkwell(
          onTap: onTap,
          child: isList
              ? SizedBox(
                  // Dynamic height if it's an icon to prevent constraints issues,
                  // but keeping 90 for consistency with images if needed.
                  // For now, let's keep 90 but allowing flexibility might be safer.
                  // Actually, generic search cards rely on this 90.
                  height: 90,
                  child: content,
                ) // Fixed height for List stability
              : content,
        ),
      ),
    );
  }

  // 1. HORIZONTAL (LIST) STYLE
  Widget _buildHorizontal(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          if (imageUrl != null || icon != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1, // Keeps image/icon square
                child: _buildImage(colorScheme),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSecondary,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSecondary.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (isSelected) _buildCheck(colorScheme),
        ],
      ),
    );
  }

  // 2. VERTICAL (GRID) STYLE
  Widget _buildVertical(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildImage(colorScheme)),
              if (isSelected)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _buildCheck(colorScheme, isBadge: true),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage(ColorScheme colorScheme) {
    if (icon != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            icon,
            size: 32,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      );
    }
    if (imageUrl != null) {
      return imageUrl!.startsWith('http')
          ? Image.network(imageUrl!, fit: BoxFit.cover)
          : Image.asset(imageUrl!, fit: BoxFit.cover);
    }
    return const SizedBox();
  }

  Widget _buildCheck(ColorScheme colorScheme, {bool isBadge = false}) {
    if (isBadge) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: colorScheme.onPrimary,
        child: Icon(Icons.check, size: 14, color: colorScheme.primary),
      );
    }
    return Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 28);
  }
}
