// lib/src/features/farmer/shared/data/duruha_badges.dart

import 'package:flutter/material.dart';
import '../models/badge_model.dart';

class DuruhaBadges {
  static List<DuruhaBadge> all = [
    // --- TRACK 1: THE VETERAN (Tenure) ---
    _buildTieredBadge(
      'legacy',
      1,
      "Novice Tiller",
      "1 Year Farmer",
      Icons.eco_rounded,
      const Color(0xFFB0BEC5),
    ),
    _buildTieredBadge(
      'legacy',
      2,
      "Hardy Tiller",
      "3 Year Farmer",
      Icons.grass_rounded,
      const Color(0xFFCD7F32),
    ),
    _buildTieredBadge(
      'legacy',
      3,
      "Master Tiller",
      "5 Year Farmer",
      Icons.nature_rounded,
      const Color(0xFFC0C0C0),
    ),
    _buildTieredBadge(
      'legacy',
      4,
      "Legacy Tiller",
      "10 Year Farmer",
      Icons.account_tree_rounded,
      const Color(0xFFFFD700),
    ),
    _buildTieredBadge(
      'legacy',
      5,
      "Ancestor Tiller",
      "Lifetime Dedication",
      Icons.auto_awesome_rounded,
      const Color(0xFFE040FB),
    ),

    // --- TRACK 2: THE TITAN (Tonnage/Volume) ---
    _buildTieredBadge(
      'titan',
      1,
      "Sack Bearer",
      "1,000kg Produced",
      Icons.shopping_basket_rounded,
      const Color(0xFFB0BEC5),
    ),
    _buildTieredBadge(
      'titan',
      2,
      "Cart Pusher",
      "5,000kg Produced",
      Icons.local_shipping_rounded,
      const Color(0xFFCD7F32),
    ),
    _buildTieredBadge(
      'titan',
      3,
      "Truck Loader",
      "10,000kg Produced",
      Icons.conveyor_belt,
      const Color(0xFFC0C0C0),
    ), // Custom icon or placeholder
    _buildTieredBadge(
      'titan',
      4,
      "Mega Producer",
      "50,000kg Produced",
      Icons.warehouse_rounded,
      const Color(0xFFFFD700),
    ),
    _buildTieredBadge(
      'titan',
      5,
      "Harvest Titan",
      "100,000kg+ Produced",
      Icons.factory_rounded,
      const Color(0xFF00E5FF),
    ),

    // --- TRACK 3: THE RELIABLE (Streaks/Activity) ---
    _buildTieredBadge(
      'active',
      1,
      "Early Sprout",
      "7 Day Streak",
      Icons.wb_twilight_rounded,
      const Color(0xFFB0BEC5),
    ),
    _buildTieredBadge(
      'active',
      2,
      "Daily Hand",
      "30 Day Streak",
      Icons.front_hand_rounded,
      const Color(0xFFFF8C00),
    ),
    _buildTieredBadge(
      'active',
      3,
      "Constant Pulse",
      "90 Day Streak",
      Icons.favorite_rounded,
      const Color(0xFFC0C0C0),
    ),
    _buildTieredBadge(
      'active',
      4,
      "Unstoppable",
      "180 Day Streak",
      Icons.bolt_rounded,
      const Color(0xFFFFD700),
    ),
    _buildTieredBadge(
      'active',
      5,
      "Eternal Flame",
      "365 Day Streak",
      Icons.local_fire_department_rounded,
      const Color(0xFFFF1744),
    ),

    // --- TRACK 4: THE SPECIALIST (Diversity/Variety) ---
    _buildTieredBadge(
      'spec',
      1,
      "Simple Sower",
      "2 Crop Types",
      Icons.category_outlined,
      const Color(0xFFB0BEC5),
    ),
    _buildTieredBadge(
      'spec',
      2,
      "Variety Seeker",
      "5 Crop Types",
      Icons.category_rounded,
      const Color(0xFFCD7F32),
    ),
    _buildTieredBadge(
      'spec',
      3,
      "Botanist",
      "10 Crop Types",
      Icons.biotech_rounded,
      const Color(0xFFC0C0C0),
    ),
    _buildTieredBadge(
      'spec',
      4,
      "Diversity Devotee",
      "20 Crop Types",
      Icons.layers_rounded,
      const Color(0xFFFFD700),
    ),
    _buildTieredBadge(
      'spec',
      5,
      "Nature’s Architect",
      "50+ Crop Types",
      Icons.hub_rounded,
      const Color(0xFF00C853),
    ),

    // --- TRACK 5: THE GUARDIAN (Quality/Trust) ---
    _buildTieredBadge(
      'trust',
      1,
      "Honest Farmer",
      "90% Grade A",
      Icons.verified_user_outlined,
      const Color(0xFFB0BEC5),
    ),
    _buildTieredBadge(
      'trust',
      2,
      "Reliable Source",
      "95% Grade A",
      Icons.verified_rounded,
      const Color(0xFFCD7F32),
    ),
    _buildTieredBadge(
      'trust',
      3,
      "Quality King",
      "98% Grade A",
      Icons.workspace_premium_rounded,
      const Color(0xFFC0C0C0),
    ),
    _buildTieredBadge(
      'trust',
      4,
      "Trust Titan",
      "990+ Trust Score",
      Icons.shield_rounded,
      const Color(0xFFFFD700),
    ),
    _buildTieredBadge(
      'trust',
      5,
      "Duruha Legend",
      "Perfect Record",
      Icons.diamond_rounded,
      const Color(0xFFD500F9),
    ),
  ];

  // Internal helper to create the badge objects
  static DuruhaBadge _buildTieredBadge(
    String category,
    int level,
    String title,
    String criteria,
    IconData icon,
    Color color,
  ) {
    return DuruhaBadge(
      id: '${category}_lvl_$level',
      title: title,
      description: "Level $level achievement in the $category track.",
      criteria: criteria,
      icon: icon,
      color: color,
      isUnlocked: false, // Default to locked
    );
  }
}
