import 'dart:io';

import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';
import 'package:duruha/features/consumer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/consumer/features/profile/presentation/edit_profile_screen.dart';

class ConsumerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ConsumerProfileScreen({super.key, required this.userData});

  @override
  State<ConsumerProfileScreen> createState() => _ConsumerProfileScreenState();
}

class _ConsumerProfileScreenState extends State<ConsumerProfileScreen> {
  late Future<ConsumerProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<ConsumerProfile> _loadProfile() async {
    return ConsumerProfileRepositoryImpl().getConsumerProfile('consumer-001');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialName = widget.userData['name'] ?? 'Consumer';

    return DuruhaScaffold(
      appBarTitle: 'My Profile',
      bottomNavigationBar: ConsumerNavigation(
        name: initialName,
        currentRoute: '/profile',
      ),
      body: FutureBuilder<ConsumerProfile>(
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
          const displayRole = 'Consumer';
          final displayLocation =
              "${profile.barangay}, ${profile.city}, \n${profile.province}, ${profile.postalCode}";
          final displayLandmark = profile.landmark;

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: DuruhaSectionContainer(
                        children: [
                          Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    backgroundImage:
                                        profile.imageUrl != null &&
                                            profile.imageUrl!.isNotEmpty
                                        ? NetworkImage(profile.imageUrl!)
                                        : null,
                                    child:
                                        profile.imageUrl == null ||
                                            profile.imageUrl!.isEmpty
                                        ? Text(
                                            displayName.isNotEmpty
                                                ? displayName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: DuruhaInkwell(
                                      onTap: () => _pickAndUploadImage(profile),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: theme.colorScheme.surface,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      displayRole.toUpperCase(),
                                      style: TextStyle(
                                        color: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            displayLocation,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayLandmark,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- OVERVIEW CARD ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildDetailsCard(context, profile),
                    ),

                    const SizedBox(height: 32),
                    const DuruhaThemeToggleButton(),
                    // --- MENU OPTIONS ---
                    _buildMenuOption(
                      context,
                      icon: Icons.person_outline,
                      title: "Edit Profile",
                      onTap: () async {
                        final updatedProfile =
                            await Navigator.push<ConsumerProfile>(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditProfileScreen(profile: profile),
                              ),
                            );

                        if (updatedProfile != null) {
                          setState(() {
                            _profileFuture = Future.value(updatedProfile);
                          });
                        }
                      },
                    ),
                    _buildMenuOption(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      title: "My Orders",
                      onTap: () {
                        Navigator.pushNamed(context, '/consumer/orders');
                      },
                    ),
                    _buildMenuOption(
                      context,
                      icon: Icons.favorite_border,
                      title: "My Favorites",
                      onTap: () {
                        Navigator.pushNamed(context, '/consumer/market');
                      },
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, ConsumerProfile profile) {
    final theme = Theme.of(context);

    final items = [
      _DetailItem(
        'Joined',
        DateFormat('MMM d yyyy').format(DateTime.now()),
        Icons.history,
      ),
      _DetailItem('Dialect', profile.dialect, Icons.language),
      _DetailItem(
        'Segment',
        profile.consumerSegment ?? 'Household',
        Icons.group_outlined,
      ),
      _DetailItem(
        'Frequency',
        profile.cookingFrequency ?? 'Daily',
        Icons.restaurant_menu,
      ),
      _DetailItem(
        'Preferences',
        '${profile.qualityPreferences?.length ?? 0} Saved',
        Icons.verified_outlined,
      ),
      _DetailItem(
        'Interests',
        '${profile.demandCrops?.length ?? 0} Crops',
        Icons.eco_outlined,
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
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
        ),
      ],
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

    return DuruhaInkwell(
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

  Future<void> _pickAndUploadImage(ConsumerProfile profile) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await showModalBottomSheet<XFile?>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Photo Library'),
                  onTap: () async {
                    Navigator.of(
                      context,
                    ).pop(await picker.pickImage(source: ImageSource.gallery));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.of(
                      context,
                    ).pop(await picker.pickImage(source: ImageSource.camera));
                  },
                ),
              ],
            ),
          );
        },
      );

      if (image != null) {
        DuruhaSnackBar.showInfo(context, "Uploading image...");

        final newImageUrl = await ConsumerProfileRepositoryImpl()
            .uploadProfileImage(File(image.path));

        setState(() {
          _profileFuture = Future.value(
            profile.copyWith(imageUrl: newImageUrl),
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          DuruhaSnackBar.showSuccess(
            context,
            "Profile picture updated successfully!",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        DuruhaSnackBar.showError(context, "Failed to upload image: $e");
      }
    }
  }
}

class _DetailItem {
  final String label;
  final String value;
  final IconData icon;

  _DetailItem(this.label, this.value, this.icon);
}
