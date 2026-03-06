import 'dart:io';

import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/user/presentation/faq_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/badges.dart';
import 'package:duruha/features/farmer/features/profile/presentation/edit_profile_screen.dart';

class FarmerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FarmerProfileScreen({super.key, required this.userData});

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  final _repo = FarmerProfileRepositoryImpl();
  late Future<FarmerProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<FarmerProfile> _loadProfile() async {
    final userId = await SessionService.getUserId();
    return _repo.getFarmerProfile(userId!);
  }

  void _refresh() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initialName = widget.userData['name'] as String? ?? 'Farmer';

    return DuruhaScaffold(
      appBarTitle: 'My Profile',
      bottomNavigationBar: FarmerNavigation(
        name: initialName,
        currentRoute: '/profile',
      ),
      body: FutureBuilder<FarmerProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const FarmerLoadingScreen();
          }
          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Profile not found'));
          }

          final profile = snapshot.data!;
          return _ProfileBody(
            profile: profile,
            onImageUpdated: (updated) {
              if (mounted) {
                setState(() {
                  _profileFuture = Future.value(updated);
                });
              }
            },
            onProfileUpdated: (updated) {
              if (mounted) {
                setState(() {
                  _profileFuture = Future.value(updated);
                });
              }
            },
            repo: _repo,
          );
        },
      ),
    );
  }
}

// ─── Profile Body ─────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final FarmerProfile profile;
  final ValueChanged<FarmerProfile> onImageUpdated;
  final ValueChanged<FarmerProfile> onProfileUpdated;
  final FarmerProfileRepositoryImpl repo;

  const _ProfileBody({
    required this.profile,
    required this.onImageUpdated,
    required this.onProfileUpdated,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final joinedAt = DateTime.tryParse(profile.joinedAt) ?? DateTime.now();
    final joinedLabel = DateFormat('MMM yyyy').format(joinedAt);

    final locationParts = [
      profile.barangay,
      profile.city,
      profile.province,
    ].where((p) => p != null && p.isNotEmpty).join(', ');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero Header ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + camera button
                    _AvatarWithCamera(
                      profile: profile,
                      onTap: () => _pickAndUploadImage(context, profile),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (profile.farmerAlias.isNotEmpty)
                            Text(
                              '"${profile.farmerAlias}"',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          const SizedBox(height: 8),
                          _RoleBadge(
                            label: 'Farmer',
                            icon: Icons.agriculture_rounded,
                            color: scheme.onTertiary,
                            onColor: scheme.tertiary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Location row
                if (locationParts.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: locationParts,
                    color: scheme.onSurfaceVariant,
                  ),
                if (profile.landmark != null && profile.landmark!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.place_outlined,
                    text: profile.landmark!,
                    color: scheme.onSurfaceVariant,
                  ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  text: 'Joined $joinedLabel',
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Stats & Badges ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _StatsSection(profile: profile),
          ),

          const SizedBox(height: 12),

          // ── Farm Overview ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FarmOverview(profile: profile),
          ),

          const SizedBox(height: 20),

          // ── Menu Options ────────────────────────────────────────────────
          DuruhaThemeToggleButton(),
          _MenuOption(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            onTap: () async {
              final updated = await Navigator.push<FarmerProfile>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profile: profile),
                ),
              );
              if (updated != null) onProfileUpdated(updated);
            },
          ),
          _MenuOption(
            icon: Icons.insights_rounded,
            title: 'Performance & Ratings',
            onTap: () =>
                Navigator.pushNamed(context, '/farmer/profile/ratings'),
          ),
          _MenuOption(
            icon: Icons.lock_outline_rounded,
            title: 'Subscriptions',
            onTap: () => Navigator.pushNamed(context, '/farmer/subscriptions'),
          ),
          _MenuOption(
            icon: Icons.list_alt_outlined,
            title: 'Duruha Programs',
            onTap: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/farmer/programs',
              (r) => false,
            ),
          ),
          _MenuOption(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FaqScreen()),
            ),
          ),

          const Divider(height: 32, indent: 24, endIndent: 24),

          _MenuOption(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            isDestructive: true,
            onTap: () =>
                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    FarmerProfile profile,
  ) async {
    final picker = ImagePicker();
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Photo Library'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      final image = await picker.pickImage(source: source);
      if (image == null || !context.mounted) return;

      DuruhaSnackBar.showInfo(context, 'Uploading image…');
      final url = await repo.uploadProfileImage(File(image.path));

      if (!context.mounted) return;
      onImageUpdated(profile.copyWith(imageUrl: url));
      DuruhaSnackBar.showSuccess(context, 'Profile picture updated!');
    } catch (e) {
      if (context.mounted) {
        DuruhaSnackBar.showError(context, 'Failed to upload image: $e');
      }
    }
  }
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _AvatarWithCamera extends StatelessWidget {
  final FarmerProfile profile;
  final VoidCallback onTap;

  const _AvatarWithCamera({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasImage = profile.imageUrl != null && profile.imageUrl!.isNotEmpty;

    return Stack(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: scheme.primaryContainer,
          backgroundImage: hasImage ? NetworkImage(profile.imageUrl!) : null,
          child: !hasImage
              ? Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: DuruhaInkwell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color onColor;

  const _RoleBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final FarmerProfile profile;

  const _StatsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final earnedBadges = DuruhaBadges.all
        .where((b) => profile.unlockedBadgeIds.contains(b.id))
        .toList();

    return DuruhaSectionContainer(
      children: [
        // Trust Score + Crop Points
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatColumn(
              icon: Icons.verified_user_rounded,
              value: profile.trustScore.toString(),
              label: 'Trust Score',
              color: Colors.blue.shade600,
            ),
            Container(
              height: 40,
              width: 1,
              color: scheme.outline.withValues(alpha: 0.15),
            ),
            _StatColumn(
              icon: Icons.stars_rounded,
              value: DuruhaFormatter.formatNumber(profile.cropPoints),
              label: 'Crop Points',
              color: Colors.orange.shade600,
            ),
          ],
        ),
        if (earnedBadges.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Badges Earned',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: earnedBadges
                .map(
                  (b) => SizedBox(
                    width: 48,
                    height: 48,
                    child: BadgeCard(
                      badge: b,
                      isUnlocked: true,
                      iconOnly: true,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _FarmOverview extends StatelessWidget {
  final FarmerProfile profile;

  const _FarmOverview({required this.profile});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(
        Icons.landscape_rounded,
        '${DuruhaFormatter.formatNumber(profile.landArea)} Ha',
        'Land Area',
        null,
      ),
      _Item(
        Icons.water_drop_rounded,
        profile.waterSources.isNotEmpty
            ? '${profile.waterSources.length} source${profile.waterSources.length > 1 ? 's' : ''}'
            : 'Rainfed',
        'Water',
        null,
      ),
      _Item(
        Icons.eco_rounded,
        '${profile.farmerFavProduce.length} type${profile.farmerFavProduce.length != 1 ? 's' : ''}',
        'Crops',
        () => Navigator.pushNamed(context, '/farmer/crops'),
      ),
      _Item(
        Icons.directions_car_rounded,
        profile.accessibilityType.isNotEmpty ? profile.accessibilityType : '—',
        'Access',
        null,
      ),
      if (profile.deliveryWindow.isNotEmpty)
        _Item(Icons.schedule_rounded, profile.deliveryWindow, 'Delivery', null),
    ];

    return DuruhaSectionContainer(
      title: 'Farm Overview',
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: items.map((item) => _OverviewCell(item: item)).toList(),
        ),
      ],
    );
  }
}

class _Item {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  _Item(this.icon, this.value, this.label, this.onTap);
}

class _OverviewCell extends StatelessWidget {
  final _Item item;

  const _OverviewCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DuruhaInkwell(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: scheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (item.onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return DuruhaInkwell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text('Could not load profile', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
