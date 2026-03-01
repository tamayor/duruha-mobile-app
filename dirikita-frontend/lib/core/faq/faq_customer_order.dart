import 'faq.dart';

const varietySelectionFaq = FaqGroup(
  title: "Variety Auto-Selection",
  sections: [
    FaqSection(
      title: "1. Finding Your Produce",
      content:
          "When you pick \"Any Variety,\" our system automatically finds the best match for you:\n\n"
          "• Priority: We look for the closest farmers with the most stock first.\n"
          "• Fallback: If local stock is out, we look further away to make sure you still get your produce.",
    ),
    FaqSection(
      title: "2. Smart Delivery Fees",
      content:
          "We charge per farmer, not per item.\n\n"
          "• If you buy 5 items from Farmer A, you only pay one delivery fee (split across those 5 items).\n"
          "• Fees are based on real road distance from the farm to you.\n"
          "• Your Control: If you feel a delivery fee is too high, you can delete that item from your cart immediately.",
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
      title: "4. Why One Farmer Wins Over Another",
      content:
          "If two farmers have the same item, we pick the best one based on:\n\n"
          "• Distance: The closest farm to you.\n"
          "• Timing: Produce that is ready for harvest right now.\n"
          "• Efficiency: Farmers who can fulfill your entire order in one go.",
    ),
    FaqSection(
      title: "5. Matching Logic Breakdown",
      content:
          "Our system uses a strict priority queue to select your match:\n\n"
          "1. Closest Distance: Shortest travel time from farm to doorstep.\n"
          "2. Ready for Harvest: Farmers whose availability is closest to your 'Date Needed'.\n"
          "3. Freshness Window: Matching items with the best expiration buffer.\n"
          "4. Stock Availability: Priority given to farmers who can fulfill your requested quantity.\n"
          "5. Efficiency: Selecting the widest availability window to ensure a successful match.",
    ),
  ],
);
