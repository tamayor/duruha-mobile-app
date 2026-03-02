import 'faq.dart';

const manageOfferFaq = FaqGroup(
  title: "Manage Offers",
  sections: [
    FaqSection(
      title: "1.You have only max 5 changes per offers",
      content:
          "To prevent spamming, you can only make a maximum of 5 changes per offer.\n\n"
          "If you try to make more than 5 changes, the changes will not be saved.\n\n"
          "Decide properly before making changes to your offer.",
    ),
    FaqSection(
      title: "2. Deleting an Offer",
      content:
          "You can only delete an offer if no one has ordered from it yet.\n\n"
          "Once at least one order exists, deletion is no longer allowed — you can only deactivate it.",
    ),
    FaqSection(
      title: "3. Deactivating an Offer",
      content:
          "Once your offer has orders, the only thing you can do to \"remove\" it is deactivate it.\n\n"
          "Deactivating pauses your price lock subscription — it won't keep running while your offer is inactive.\n\n"
          "You can reactivate your offer anytime, which resumes your price lock — but only if it hasn't expired yet.\n\n"
          "If your price lock has already expired by the time you try to reactivate, reactivation is not allowed.",
    ),
    FaqSection(
      title: "4. Price Lock Rules",
      content:
          "Price lock credits are non-refundable — once consumed, they're gone.\n\n"
          "If your price lock expires, you lose whatever credits remained — they will not be returned.\n\n"
          "Once even one consumer has ordered from your offer using a price lock, the price lock fee is non-refundable — you cannot back out of it.\n\n"
          "Use price lock intentionally — only activate it if you're committed to fulfilling orders at that locked price.",
    ),
    FaqSection(
      title: "5. Adjusting Quantity",
      content:
          "You can only add quantity during the availability period you originally set — not after it ends.\n\n"
          "You can subtract quantity at any time, but only as long as the remaining quantity won't go below zero.\n\n"
          "You cannot remove more stock than what is currently unallocated.",
    ),
    FaqSection(
      title: "6. Adjusting Availability Dates",
      content:
          "You cannot change your availability start date once that date has already passed.\n\n"
          "Plan your availability window carefully before your offer goes live.",
    ),
    FaqSection(
      title: "7. General Reminder",
      content:
          "Price lock is a commitment — once orders come in, there are no refunds, no cancellations, and no backing out. Only use it if you're confident in your pricing and supply.",
    ),
  ],
);

const FaqContent faqFarmerManageOffer = FaqContent(
  title: "Manage Offers FAQ",
  groups: [manageOfferFaq],
);
