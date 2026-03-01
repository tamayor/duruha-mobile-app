import 'faq.dart';

const deliveryFeeFaq = FaqGroup(
  title: "Delivery Fee Details",
  sections: [
    FaqSection(
      title: "1. The \"Free Shipping\" Threshold",
      content:
          "Before we calculate anything, we check your total. If your order from a specific farmer meets our Minimum Amount, the delivery fee is automatically set to ₱0.00.",
    ),
    FaqSection(
      title: "2. Calculating the Real Distance",
      content:
          "We don't just measure a straight line on a map.\n\n• Precision Tracking: We use satellite data to find the exact distance between the farm and your home.\n• The Road Factor: We apply a multiplier (1.3x) to account for the actual curves, turns, and island routes of Philippine roads, giving you a realistic estimate of the journey.",
    ),
    FaqSection(
      title: "3. The \"Batch\" Discount (Buying in Bulk)",
      content:
          "The more you (or your group) buy from one farmer, the cheaper the rate becomes:\n\n• Standard Rate: For small, individual orders.\n• Van Rate: For medium-sized batches.\n• Truck Rate: The cheapest rate per kilometer, used when you hit a high volume of items from that farm.",
    ),
    FaqSection(
      title: "4. Distance Tiers (Local vs. Far)",
      content:
          "• Local: A lower base fee for farms nearby.\n• Far: If the produce has to come from a different region or a long distance, a slightly higher base fee and surcharge are applied to cover the extra logistics.",
    ),
    FaqSection(
      title: "5. The \"Good Neighbor\" Discount",
      content:
          "This is where you save by being part of a community. Our system checks if other people near you are also ordering.\n\n• High Density: If many neighbors are ordering, your fee can be cut by 50%.\n• Medium Density: If a few neighbors are ordering, you get a 25% discount.\n\nWhy? Because the driver can make multiple drops in one trip, and we pass those savings directly to you.",
    ),
  ],
);
