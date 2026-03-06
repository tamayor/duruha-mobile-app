import 'faq.dart';

const varietySelectionFaq = FaqGroup(
  title: "Variety Auto-Selection",
  sections: [
    FaqSection(
      title: "1. Finding Your Produce",
      content:
          "When you pick \"Any Variety,\" our system automatically finds the best match for you:\n\n"
          "• Priority: We look for the closest farmers with the most stock first.\n"
          "• Fallback: If local stock runs out, we search further away to ensure you still get your produce.\n"
          "• Multi-Variety Fill: If your order can't be fulfilled by one variety alone, we split it across multiple varieties — the highest-priority variety takes as much as it can, and the remainder is covered by the next best.",
    ),
    FaqSection(
      title: "2. Smart Delivery Fees",
      content:
          "We charge per farmer allocation, not per item.\n\n"
          "• If a variety is sourced from multiple farmer offers, only the highest delivery fee is charged — the rest are waived.\n"
          "• If two varieties come from different farmers, each gets its own delivery fee.\n"
          "• Fees are based on real road distance from the farm to you.\n"
          "• Your Control: If you feel a delivery fee is too high, you can cancel that item immediately.",
    ),
    FaqSection(
      title: "3. Quality Options",
      content:
          "Choose the level of service that fits your budget:\n\n"
          "• Saver: 0% fee (Best value)\n"
          "• Regular: 5% fee (Standard quality)\n"
          "• Select: 15% fee (Premium curation)",
    ),
    FaqSection(
      title: "4. Why One Variety Wins Over Another",
      content:
          "When you specify variety choices, we rank them by:\n\n"
          "• Stock First: Varieties with available stock are always prioritized.\n"
          "• Distance: The closest farm to you.\n"
          "• Quantity: Varieties with the most total stock fill your order faster.\n"
          "• Timing: Availability closest to your Date Needed.",
    ),
    FaqSection(
      title: "5. How Multi-Offer Allocation Works",
      content:
          "A single variety may be sourced from more than one farmer offer:\n\n"
          "• Example: You order 100kg of Red Rice. Farmer A has 50kg (Offer 1) and 50kg (Offer 2). Both offers are allocated and appear as separate delivery entries.\n"
          "• Delivery Fee: Only the highest fee among those entries is charged — the other is waived.\n"
          "• You can track each allocation separately in your order details.",
    ),
    FaqSection(
      title: "6. Matching Priority Breakdown",
      content:
          "Our system uses a strict priority queue to select your match:\n\n"
          "1. Closest Distance: Shortest travel time from farm to doorstep.\n"
          "2. Ready for Harvest: Farmers whose availability is closest to your Date Needed.\n"
          "3. Stock Availability: Priority given to farmers who can fulfill the most quantity.\n"
          "4. Freshness Window: Items with the best expiration buffer.\n"
          "5. Efficiency: Selecting the widest availability window to ensure a successful match.",
    ),
  ],
);
