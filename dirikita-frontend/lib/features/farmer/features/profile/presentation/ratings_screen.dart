import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/core/data/duruha_badges.dart';
import 'package:duruha/core/models/badge_model.dart';
import 'package:duruha/features/farmer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';
import 'package:duruha/features/farmer/features/profile/domain/ratings_model.dart';
import 'package:duruha/features/farmer/features/profile/data/ratings_repository.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';

class FarmerProfileRatingsScreen extends StatelessWidget {
  const FarmerProfileRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        FarmerProfileRepositoryImpl().getFarmerProfile('current_user'),
        PerformanceRepositoryImpl().getPerformanceStats('current_user'),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text("Error loading performance data")),
          );
        }

        final profile = snapshot.data![0] as FarmerProfile;
        final performance = snapshot.data![1] as FarmerPerformance;

        final earnedBadgesCount = DuruhaBadges.all
            .where((b) => profile.unlockedBadgeIds.contains(b.id))
            .length;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text("Program Profile"),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
          ),
          bottomNavigationBar: FarmerNavigation(
            name: profile.name.split(' ').first,
            currentRoute: '/farmer/profile',
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Stats Grid
                Row(
                  children: [
                    _buildMetricCard(
                      context,
                      label: "Trust Score",
                      value: performance.trustScore.toString(),
                      subtitle: performance.trustSubtitle,
                      icon: Icons.verified_user_rounded,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 16),
                    _buildMetricCard(
                      context,
                      label: "Crop Points",
                      value: DuruhaFormatter.formatNumber(
                        performance.cropPoints,
                      ),
                      subtitle: performance.pointsSubtitle,
                      icon: Icons.stars_rounded,
                      color: Colors.orange.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                const SizedBox(height: 32),

                // Achievement Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        performance.currentRankName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        performance.rankNextGoal,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: performance.rankProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Badges Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Duruha Badges",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "$earnedBadgesCount / ${DuruhaBadges.all.length}",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: DuruhaBadges.all.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final badge = DuruhaBadges.all[index];
                    final isUnlocked = profile.unlockedBadgeIds.contains(
                      badge.id,
                    );
                    return _buildBadgeItem(
                      context,
                      badge,
                      isUnlocked: isUnlocked,
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 16),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeItem(
    BuildContext context,
    DuruhaBadge badge, {
    bool isUnlocked = false,
  }) {
    final theme = Theme.of(context);
    final isEarned = isUnlocked || badge.isUnlocked;

    return InkWell(
      onTap: () => _showBadgeDetails(context, badge, isUnlocked: isEarned),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEarned
              ? badge.color.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEarned
                ? badge.color.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isEarned
                    ? badge.color.withValues(alpha: 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    badge.icon,
                    color: isEarned
                        ? badge.color
                        : theme.colorScheme.outline.withValues(alpha: 0.4),
                    size: 28,
                  ),
                  if (!isEarned)
                    Icon(
                      Icons.lock_rounded,
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                      size: 14,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isEarned
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge.criteria,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isEarned)
              Icon(Icons.verified_rounded, color: badge.color, size: 20),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(
    BuildContext context,
    DuruhaBadge badge, {
    bool isUnlocked = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: badge.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: badge.color.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(badge.icon, color: badge.color, size: 64),
            ),
            const SizedBox(height: 24),
            Text(
              badge.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            DuruhaSectionContainer(
              title: "How to Unlock",
              style: DuruhaContainerStyle.filled,
              backgroundColor: badge.color.withValues(alpha: 0.05),
              children: [
                Text(
                  badge.criteria,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: DuruhaButton(
                text: isUnlocked ? "Badge Earned" : "Keep Growing",
                onPressed: () => Navigator.pop(context),
                isOutline: !isUnlocked,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
