import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:duruha/screens/user/components/user_navigation_bar.dart';
import 'package:duruha/data/mock_data.dart';
import 'package:duruha/models/user_models.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final argRole = userData['role'] ?? 'User';
    final isFarmer = argRole == 'Farmer';

    // Get Mock Data if role matches (Simulating data fetch)
    // If name matches mock, we use mock, otherwise we default/mix
    final UserProfile profile = isFarmer
        ? MockData.mockFarmer
        : MockData.mockConsumer;

    // We prefer the Mock Data for details, but keep the Name/Role from args if they differ?
    // For this specific 'populate mock data' task, let's use the Mock Data values primarily
    // to show off the data we just created.
    final displayName = profile.name;
    final displayRole = isFarmer
        ? 'Farmer'
        : 'Consumer'; // profile.role is an enum

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: UserNavigationBar(
        role: displayRole,
        name: displayName,
        currentRoute: '/profile',
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // --- HEADER ---
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isFarmer
                          ? const Color(0xFFC6A65C)
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      displayRole.toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- STATS / DETAILS CARD ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildDetailsCard(context, profile),
            ),

            const SizedBox(height: 32),

            // --- MENU OPTIONS ---
            _buildMenuOption(
              context,
              icon: Icons.person_outline,
              title: "Edit Profile",
              onTap: () {},
            ),
            _buildMenuOption(
              context,
              icon: Icons.notifications_outlined,
              title: "Notifications",
              onTap: () {},
            ),
            _buildMenuOption(
              context,
              icon: Icons.help_outline,
              title: "Help & Support",
              onTap: () {},
            ),
            const Divider(height: 48),
            _buildMenuOption(
              context,
              icon: Icons.logout,
              title: "Log Out",
              isDestructive: true,
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final isFarmer = profile.isFarmer;

    // Use data from the profile model
    final items = isFarmer
        ? [
            _DetailItem(
              'Joined',
              DateFormat('MMM d yyyy').format(DateTime.now()),
              Icons.history,
            ),
            _DetailItem('Dialect', profile.dialect, Icons.language),
            _DetailItem(
              'Farm Size',
              '${profile.landArea?.toStringAsFixed(1) ?? "0"} Ha',
              Icons.landscape,
            ),
            _DetailItem(
              'Water',
              profile.waterSources?.isNotEmpty == true
                  ? '${profile.waterSources!.length} Sources'
                  : 'Rainfed',
              Icons.water_drop,
            ),
            _DetailItem(
              'Crops',
              '${profile.pledgedCrops?.length ?? 0} Types',
              Icons.eco,
              onTap: () => Navigator.pushNamed(context, '/farmer/crops'),
            ),
            _DetailItem(
              'Experience',
              '5 Years', // Still hardcoded as not in model yet
              Icons.history,
            ),
          ]
        : [
            _DetailItem(
              'Joined',
              DateFormat('MMM d yyyy').format(DateTime.now()),
              Icons.history,
            ),
            _DetailItem('Dialect', profile.dialect, Icons.language),
            _DetailItem(
              'Segment',
              profile.consumerSegment ?? 'Household',
              Icons.home,
            ),
            _DetailItem(
              'Cooking',
              profile.cookingFrequency ?? 'Daily',
              Icons.restaurant_menu,
            ),
            _DetailItem(
              'Preference',
              (profile.qualityPreferences?.isNotEmpty == true)
                  ? profile.qualityPreferences!.first
                        .split(' ')
                        .first // "Class" or "Class A"
                  : 'Any',
              Icons.star,
            ),
            _DetailItem(
              'Demand',
              '${profile.demandCrops?.length ?? 0} Items',
              Icons.shopping_basket,
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Overview",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: items
                .map((item) => _buildStatItem(context, item))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, _DetailItem item) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  _DetailItem(this.label, this.value, this.icon, {this.onTap});
}
