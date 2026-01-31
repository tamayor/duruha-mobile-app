import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/features/farmer/features/profile/data/profile_repository.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

class FarmerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FarmerProfileScreen({super.key, required this.userData});

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  late Future<FarmerProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<FarmerProfile> _loadProfile() async {
    // Use the ID from userData if available, otherwise default
    // final id = widget.userData['id'] ?? 'farmer-001';
    return FarmerProfileRepositoryImpl().getFarmerProfile('farmer-001');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Initial basic info from passed arguments (fallback while loading)
    final initialName = widget.userData['name'] ?? 'Farmer';

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
      bottomNavigationBar: FarmerNavigation(
        name: initialName,
        currentRoute: '/profile',
      ),
      body: FutureBuilder<FarmerProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("Profile not found"));
          }

          final profile = snapshot.data!;
          final displayName = profile.name;
          const displayRole = 'Farmer';

          return SingleChildScrollView(
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
                          color: theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          displayRole.toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.onSecondary,
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
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (r) => false,
                    );
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, FarmerProfile profile) {
    final theme = Theme.of(context);

    // Use data from the profile model
    final items = [
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
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: theme.colorScheme.onPrimary,
            ),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
              color: theme.colorScheme.secondary,
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
