import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';

class DuruhaProgram {
  final String title;
  final String description;
  final List<String> tags;
  final String buttonText;
  final IconData icon;
  final Color color;
  final String category;
  final bool isPopular;

  DuruhaProgram({
    required this.title,
    required this.description,
    required this.tags,
    required this.buttonText,
    required this.icon,
    required this.color,
    required this.category,
    this.isPopular = false,
  });
}

class FarmerProgramsScreen extends StatefulWidget {
  const FarmerProgramsScreen({super.key});

  @override
  State<FarmerProgramsScreen> createState() => _FarmerProgramsScreenState();
}

class _FarmerProgramsScreenState extends State<FarmerProgramsScreen> {
  String _selectedCategory = "All";

  final List<String> _categories = [
    "All",
    "Finance",
    "Logistics",
    "Supplies",
    "Expertise",
  ];

  final List<DuruhaProgram> _allPrograms = [
    DuruhaProgram(
      title: "Seed Capital & Micro-Loans",
      description:
          "Low-interest financing for seeds, fertilizers, and equipment. Pay back only after you harvest.",
      tags: ["Low Interest", "Pay Later"],
      buttonText: "Check Eligibility",
      icon: Icons.monetization_on_outlined,
      color: Colors.green,
      category: "Finance",
    ),
    DuruhaProgram(
      title: "Talk with Agri-Experts",
      description:
          "Book a 30-minute video call with agronomists to diagnose pests or improve yield strategies.",
      tags: ["Free for Members", "Video Call"],
      buttonText: "Book Consultation",
      icon: Icons.video_call_outlined,
      color: Colors.blue,
      category: "Expertise",
    ),
    DuruhaProgram(
      title: "Duruha Logistics Pool",
      description:
          "Share truck space with nearby farmers sending produce to the same city. Reduce transport costs by 40%.",
      tags: ["Cost Saver", "Daily Trips"],
      buttonText: "Find Routes",
      icon: Icons.local_shipping_outlined,
      color: Colors.orange,
      category: "Logistics",
      isPopular: true,
    ),
    DuruhaProgram(
      title: "Harvest Shield Insurance",
      description:
          "Protect your crops against typhoons and droughts. Instant payout based on local weather data.",
      tags: ["Weather Index", "Fast Payout"],
      buttonText: "View Coverage",
      icon: Icons.security_outlined,
      color: Colors.indigo,
      category: "Finance",
    ),
    DuruhaProgram(
      title: "Bulk Input Group Buy",
      description:
          "Join 500+ farmers buying organic fertilizers in bulk. Get wholesale prices delivered to your zone.",
      tags: ["Wholesale Price", "Organic"],
      buttonText: "Join Group Buy",
      icon: Icons.groups_outlined,
      color: Colors.teal,
      category: "Supplies",
    ),
    DuruhaProgram(
      title: "GAP Certification Assist",
      description:
          "Step-by-step guidance and paperwork assistance to get your Good Agricultural Practice (GAP) seal.",
      tags: ["Premium Pricing", "Export Ready"],
      buttonText: "Start Certification",
      icon: Icons.verified_user_outlined,
      color: Colors.purple,
      category: "Expertise",
    ),
  ];

  List<DuruhaProgram> get _filteredPrograms {
    if (_selectedCategory == "All") return _allPrograms;
    return _allPrograms.where((p) => p.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DuruhaScaffold(
      appBarTitle: 'Farmer Programs',
      bottomNavigationBar: const FarmerNavigation(
        name: "Elly",
        currentRoute: '/',
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgramHeader(context),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 10,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Available for You",
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Exclusive support programs for you.",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DuruhaPopupMenu<String>(
                            items: _categories,
                            selectedValue: _selectedCategory,
                            onSelected: (category) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              HapticFeedback.selectionClick();
                            },
                            labelBuilder: (category) => category,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_filteredPrograms.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No programs found for this category.",
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._filteredPrograms.map(
                          (program) => _buildProgramCard(context, program),
                        ),

                      const SizedBox(height: 32),

                      // Suggestion Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Suggest a Program",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Don't see what you need? Tell us how we can help your farm grow.",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DuruhaButton(
                              text: "Send Suggestion",
                              onPressed: () {},
                              isOutline: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DuruhaInkwell(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.pushNamed(context, '/farmer/profile/ratings');
      },
      child: DuruhaSectionContainer(
        title: "Elly's Program Profile",
        subtitle: "Real-time performance stats & eligibility rank",
        style: DuruhaContainerStyle.filled,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        padding: const EdgeInsets.all(20),
        action: IconButton.filledTonal(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pushNamed(context, '/farmer/profile/ratings');
          },
          icon: const Icon(Icons.insights_rounded),
        ),
        children: [
          Row(
            children: [
              _buildTopStat(
                context,
                label: "Trust Score",
                value: "982",
                icon: Icons.verified_user_rounded,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 12),
              _buildTopStat(
                context,
                label: "Crop Points",
                value: "14.5k",
                icon: Icons.stars_rounded,
                color: Colors.orange.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramCard(BuildContext context, DuruhaProgram program) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (program.isPopular)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  "POPULAR",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: program.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(program.icon, color: program.color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        program.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  program.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: program.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outline.withValues(
                                alpha: 0.05,
                              ),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                DuruhaButton(
                  text: program.buttonText,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
