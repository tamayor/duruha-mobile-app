import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:duruha/core/widgets/duruha_user_profile.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import 'package:intl/intl.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';
import 'package:duruha/features/consumer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/consumer/features/subscription/data/consumer_plan_repository.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/features/consumer/features/profile/presentation/edit_profile_screen.dart';
import 'package:duruha/core/widgets/duruha_chat_widget.dart';

class ConsumerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ConsumerProfileScreen({super.key, required this.userData});

  @override
  State<ConsumerProfileScreen> createState() => _ConsumerProfileScreenState();
}

class _ConsumerProfileScreenState extends State<ConsumerProfileScreen> {
  final _repo = ConsumerProfileRepositoryImpl();
  late Future<ConsumerProfile> _profileFuture;
  late Future<String?> _tierNameFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _tierNameFuture = _loadTierName();
  }

  Future<ConsumerProfile> _loadProfile() async {
    return _repo.getConsumerProfile();
  }

  Future<String?> _loadTierName() async {
    final consumerId = await SessionService.getRoleId();
    if (consumerId == null) return null;
    final plan = await ConsumerPlanRepository().getActivePlan(consumerId);
    return plan?.qualityLevel;
  }

  void _refresh() {
    setState(() {
      _profileFuture = _loadProfile();
      _tierNameFuture = _loadTierName();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'My Profile',
      bottomNavigationBar: const ConsumerNavigation(currentRoute: '/profile'),
      body: FutureBuilder<ConsumerProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ConsumerLoadingScreen();
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
          return FutureBuilder<String?>(
            future: _tierNameFuture,
            builder: (context, tierSnapshot) {
              final tierName = tierSnapshot.data ?? 'Saver';
              return _ProfileBody(
                profile: profile,
                tierName: tierName,
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
          );
        },
      ),
    );
  }
}

// ─── Profile Body ─────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final ConsumerProfile profile;
  final String tierName;
  final ValueChanged<ConsumerProfile> onImageUpdated;
  final ValueChanged<ConsumerProfile> onProfileUpdated;
  final ConsumerProfileRepositoryImpl repo;

  const _ProfileBody({
    required this.profile,
    required this.tierName,
    required this.onImageUpdated,
    required this.onProfileUpdated,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final joinedAt =
        DateTime.now(); // Assume now since no joinedAt property inside ConsumerProfile models
    final joinedLabel = DateFormat('MMM yyyy').format(joinedAt);

    final locationParts = [
      profile.addressLine1,
      profile.addressLine2,
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
                    DuruhaUserProfile(
                      imageUrl: profile.imageUrl,
                      userName: profile.name,
                      radius: 44.0,
                      allowUpload: true,
                      bucketName: 'avatars',
                      onImageUploaded: (url) {
                        onImageUpdated(profile.copyWith(imageUrl: url));
                        repo.updateProfile(profile.copyWith(imageUrl: url));
                        SessionService.saveUser(
                          profile.copyWith(imageUrl: url),
                        );
                      },
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
                          const SizedBox(height: 8),
                          _RoleBadge(
                            label: 'Consumer',
                            icon: Icons.person_rounded,
                            color: DuruhaColorHelper.getColor(
                              context,
                              'consumer',
                            ),
                            onColor: DuruhaColorHelper.getColor(
                              context,
                              'consumer',
                            ),
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
                if (profile.latitude != null && profile.longitude != null)
                  _InfoRow(
                    icon: Icons.gps_fixed_rounded,
                    text:
                        '${profile.latitude!.toStringAsFixed(5)}, ${profile.longitude!.toStringAsFixed(5)}',
                    color: scheme.onSecondary.withValues(alpha: 0.5),
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

          // ── Overview ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ConsumerOverview(profile: profile, tierName: tierName),
          ),

          const SizedBox(height: 20),

          // ── Menu Options ────────────────────────────────────────────────
          const DuruhaThemeToggleButton(),
          _MenuOption(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            onTap: () async {
              final updated = await Navigator.push<ConsumerProfile>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profile: profile),
                ),
              );
              if (updated != null) onProfileUpdated(updated);
            },
          ),
          _MenuOption(
            icon: Icons.payments_outlined,
            title: 'Subscriptions',
            onTap: () =>
                Navigator.pushNamed(context, '/consumer/subscriptions'),
          ),
          _MenuOption(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DuruhaChatScreen()),
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

class _ConsumerOverview extends StatelessWidget {
  final ConsumerProfile profile;
  final String tierName;

  const _ConsumerOverview({required this.profile, required this.tierName});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(
        Icons.language_rounded,
        profile.dialect.isNotEmpty ? profile.dialect[0] : 'None',
        'Dialect',
        null,
      ),
      _Item(
        Icons.group_outlined,
        profile.consumerSegment ?? 'Household',
        'Segment',
        null,
      ),
      _Item(
        Icons.restaurant_menu_rounded,
        profile.cookingFrequency ?? 'Daily',
        'Frequency',
        null,
      ),
      _Item(Icons.workspace_premium_outlined, tierName, 'Quality', null),
      _Item(
        Icons.eco_outlined,
        '${profile.consumerFavProduce.length} Crops',
        'Interests',
        null,
      ),
    ];

    return DuruhaSectionContainer(
      title: 'Overview',
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
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
