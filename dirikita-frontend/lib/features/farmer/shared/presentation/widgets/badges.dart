import 'package:flutter/material.dart';

// --- MODELS & ENUMS ---

/// The tier of achievement reached.
enum DuruhaBadgeTier {
  gray,
  bronze,
  silver,
  gold,
  platinum,
  green;

  String get title {
    switch (this) {
      case DuruhaBadgeTier.gray:
        return 'Novice';
      case DuruhaBadgeTier.bronze:
        return 'Bronze';
      case DuruhaBadgeTier.silver:
        return 'Silver';
      case DuruhaBadgeTier.gold:
        return 'Gold';
      case DuruhaBadgeTier.platinum:
        return 'Platinum';
      case DuruhaBadgeTier.green:
        return 'Guardian';
    }
  }

  Color get color {
    switch (this) {
      case DuruhaBadgeTier.gray:
        return const Color(0xFFB0BEC5);
      case DuruhaBadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case DuruhaBadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case DuruhaBadgeTier.gold:
        return const Color(0xFFFFD700);
      case DuruhaBadgeTier.platinum:
        return const Color(0xFFE5E4E2);
      case DuruhaBadgeTier.green:
        return const Color(0xFF00C853);
    }
  }

  Color get accentColor {
    switch (this) {
      case DuruhaBadgeTier.gray:
        return const Color(0xFFCFD8DC);
      case DuruhaBadgeTier.bronze:
        return const Color(0xFFD7CCC8);
      case DuruhaBadgeTier.silver:
        return const Color(0xFFEEEEEE);
      case DuruhaBadgeTier.gold:
        return const Color(0xFFFFF9C4);
      case DuruhaBadgeTier.platinum:
        return const Color(0xFFF5F5F5);
      case DuruhaBadgeTier.green:
        return const Color(0xFFB9F6CA);
    }
  }

  IconData get icon {
    switch (this) {
      case DuruhaBadgeTier.gray:
        return Icons.star_outline_rounded;
      case DuruhaBadgeTier.bronze:
        return Icons.emoji_events_outlined;
      case DuruhaBadgeTier.silver:
        return Icons.workspace_premium_outlined;
      case DuruhaBadgeTier.gold:
        return Icons.emoji_events_rounded;
      case DuruhaBadgeTier.platinum:
        return Icons.diamond_outlined;
      case DuruhaBadgeTier.green:
        return Icons.eco;
    }
  }

  String get description {
    switch (this) {
      case DuruhaBadgeTier.gray:
        return 'A solid start to your journey.';
      case DuruhaBadgeTier.bronze:
        return 'Recognizing your growing dedication.';
      case DuruhaBadgeTier.silver:
        return 'A mark of consistent excellence.';
      case DuruhaBadgeTier.gold:
        return 'The gold standard of achievement.';
      case DuruhaBadgeTier.platinum:
        return 'An elite tier for the truly dedicated.';
      case DuruhaBadgeTier.green:
        return 'The ultimate guardian of nature.';
    }
  }
}

/// The specific category of the badge.
enum BadgeCategory {
  variety,
  earnings,
  years,
  transactions;

  String get label {
    switch (this) {
      case BadgeCategory.variety:
        return 'Variety';
      case BadgeCategory.earnings:
        return 'Total Earnings';
      case BadgeCategory.years:
        return 'Years Active';
      case BadgeCategory.transactions:
        return 'Transactions';
    }
  }

  IconData get baseIcon {
    switch (this) {
      case BadgeCategory.variety:
        return Icons.category_outlined;
      case BadgeCategory.earnings:
        return Icons.payments_outlined;
      case BadgeCategory.years:
        return Icons.calendar_today_outlined;
      case BadgeCategory.transactions:
        return Icons.swap_horiz_outlined;
    }
  }

  String description(DuruhaBadgeTier tier) {
    switch (this) {
      case BadgeCategory.variety:
        return 'Explored ${5 * (tier.index + 1)} different categories.';
      case BadgeCategory.earnings:
        return 'Achieved a milestone in lifetime revenue.';
      case BadgeCategory.years:
        return 'A member for ${tier.index + 1} full years.';
      case BadgeCategory.transactions:
        return 'Completed ${10 * (tier.index + 1)} successful transactions.';
    }
  }
}

/// Model representing a user's specific badge state.
class DuruhaBadge {
  final BadgeCategory category;
  final DuruhaBadgeTier tier;
  final double progress; // 0.0 to 1.0

  DuruhaBadge({
    required this.category,
    required this.tier,
    this.progress = 1.0,
  });

  String get id => '${category.name}_${tier.name}';

  String get title => category.label;

  String get description => tier.description; // e.g. "A solid start..."

  String get criteria => category.description(tier); // e.g. "100 transactions"

  IconData get icon => tier.icon;

  Color get color => tier.color;

  bool get isUnlocked => progress >= 1.0;
}

class DuruhaBadges {
  static List<DuruhaBadge> get all {
    List<DuruhaBadge> badges = [];
    for (var category in BadgeCategory.values) {
      for (var tier in DuruhaBadgeTier.values) {
        badges.add(
          DuruhaBadge(
            category: category,
            tier: tier,
            progress: 0.0, // Default locked
          ),
        );
      }
    }
    return badges;
  }
}

// --- WIDGETS ---

/// A visually appealing badge widget.
class BadgeCard extends StatelessWidget {
  final DuruhaBadge badge;
  final bool isUnlocked;
  final bool iconOnly;

  const BadgeCard({
    super.key,
    required this.badge,
    required this.isUnlocked,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = badge.tier.color;
    final accent = badge.tier.accentColor;

    // Icon-only compact mode
    if (iconOnly) {
      return Tooltip(
        message: '${badge.category.label} - ${badge.tier.title}',
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked
                ? accent.withValues(alpha: 0.2)
                : theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isUnlocked
                  ? color.withValues(alpha: 0.5)
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 2,
            ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            badge.category.baseIcon,
            size: 24,
            color: isUnlocked ? color : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Full card mode
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? color.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Minimalist Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? accent.withValues(alpha: 0.2)
                  : theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              badge.category.baseIcon,
              size: 24,
              color: isUnlocked ? color : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // Badge Label
          Text(
            badge.category.label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Tier Name
          Text(
            badge.tier.title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: isUnlocked ? color : theme.colorScheme.onSurfaceVariant,
            ),
          ),

          // Progress Bar (Always show if not unlocked for motivation, or if specifically set)
          if (!isUnlocked || (badge.progress > 0 && badge.progress < 1.0)) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: badge.progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${(badge.progress * 100).toInt()}%",
              style: TextStyle(
                fontSize: 9,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
