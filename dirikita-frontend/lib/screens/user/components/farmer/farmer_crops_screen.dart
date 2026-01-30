import 'package:duruha/screens/user/components/user_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:duruha/data/mock_data.dart';
import 'package:duruha/models/user_models.dart';
import 'package:intl/intl.dart';

class FarmerCropsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = "Elly";
    final displayRole = "Farmer";

    // Fetch mocked farmer crops.
    // In a real app, you would fetch based on the logged-in user ID.
    final myCrops = MockData.mockFarmer.pledgedCrops ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Pledged Crops'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBar: UserNavigationBar(
        role: displayRole,
        name: displayName,
        currentRoute: '/farmer/crops',
      ),
      // We don't necessarily need the UserNavigationBar here if it's a detail screen,
      // but if it's a 'bottom nav' destination, we might.
      // The user accessed this via 'Profile -> Crops', so usually it's a sub-page with a Back button.
      // So we will NOT include UserNavigationBar to allow 'Back' navigation.
      body: myCrops.isEmpty
          ? Center(
              child: Text(
                'No crops pledged yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: myCrops.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final crop = myCrops[index];
                return _buildCropCard(context, crop);
              },
            ),
    );
  }

  Widget _buildCropCard(BuildContext context, ProduceItem crop) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Image / Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                image: crop.imageThumbnailUrl.startsWith('http')
                    ? DecorationImage(
                        image: NetworkImage(crop.imageThumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !crop.imageThumbnailUrl.startsWith('http')
                  ? Center(child: Text('🌱', style: TextStyle(fontSize: 24)))
                  : null,
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crop.namesByDialect['tagalog'] ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    crop.nameEnglish,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
