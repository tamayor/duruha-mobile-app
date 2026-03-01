import 'package:duruha/core/widgets/duruha_inkwell.dart';
import 'package:flutter/material.dart';

class DuruhaSelectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final String? imageUrl;
  final IconData? icon;
  final bool isSelected;
  final bool isList;
  final VoidCallback onTap;
  final Widget? trailing;

  const DuruhaSelectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.imageUrl,
    this.icon,
    required this.isSelected,
    required this.isList,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget content = isList
        ? _buildHorizontal(colorScheme)
        : _buildVertical(colorScheme);

    return Padding(
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
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: DuruhaInkwell(
          onTap: onTap,
          child: isList
              ? ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 90),
                  child: content,
                )
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
        crossAxisAlignment: subtitleWidget != null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (imageUrl != null || icon != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
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
                    color: colorScheme.onPrimary,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                if (subtitleWidget != null)
                  subtitleWidget!
                else
                  Text(
                    subtitle ?? "",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSecondary.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (isSelected)
            _buildCheck(colorScheme),
        ],
      ),
    );
  }

  // 2. VERTICAL (GRID) STYLE
  // FIX: replaced Expanded with a fixed SizedBox(height: 140) so the image
  // always has a concrete height to paint into. Expanded requires a bounded
  // parent height which is not always guaranteed in a grid cell.
  Widget _buildVertical(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(colorScheme),
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
              if (subtitleWidget != null)
                subtitleWidget!
              else
                Text(
                  subtitle ?? "",
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
    // Priority 1: icon
    if (icon != null) {
      return Container(
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

    // Priority 2: imageUrl
    if (imageUrl != null) {
      // Sanitize: trim whitespace and strip trailing '?'
      final sanitized = imageUrl!.trim().replaceAll(RegExp(r'\?+$'), '');

      // Empty after sanitizing
      if (sanitized.isEmpty) {
        return _buildPlaceholder(colorScheme);
      }

      // Network image
      if (sanitized.startsWith('http://') || sanitized.startsWith('https://')) {
        return Image.network(
          sanitized,
          fit: BoxFit.cover,
          // Required by some CDNs / Supabase storage
          headers: const {
            'User-Agent': 'Duruha/1.0 (contact: support@duruha.com)',
          },
          // Show a shimmer-style placeholder while loading
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: colorScheme.surfaceContainerHighest,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            );
          },
          // Show broken image icon on error
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
              'DuruhaSelectionCard image error for "$sanitized": $error',
            );
            return _buildBrokenImage(colorScheme);
          },
        );
      }

      // Asset image
      return Image.asset(
        sanitized,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'DuruhaSelectionCard asset error for "$sanitized": $error',
          );
          return _buildBrokenImage(colorScheme);
        },
      );
    }

    // Priority 3: nothing provided
    return _buildPlaceholder(colorScheme);
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildBrokenImage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 32,
        ),
      ),
    );
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
