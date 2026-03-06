import 'package:duruha/core/faq/faq.dart';

// ─── FAQ Item Model ───────────────────────────────────────────────────────────

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});

  FaqSection toSection() => FaqSection(title: question, content: answer);
}

// ─── Farmer FAQ ───────────────────────────────────────────────────────────────

const farmerFaqItems = <FaqItem>[
  FaqItem(
    question: 'How do I create an offer on Dirikita?',
    answer:
        'Go to the Manage Offers section and tap "Create Offer." Fill in your '
        'produce details, available quantity, price per unit, and harvest '
        'availability window. Once submitted, your offer is visible to consumers.',
  ),
  FaqItem(
    question: 'What is a Pledge and how does it work?',
    answer:
        'A Pledge is a commitment from a consumer who has subscribed to a '
        'Consumer Future Plan (CFP). When a consumer plans ahead for produce, '
        'you will receive a pledge notification. Fulfilling pledges boosts your '
        'Trust Score and Crop Points.',
  ),
  FaqItem(
    question: 'How is my Trust Score calculated?',
    answer:
        'Your Trust Score reflects your reliability as a farmer. It increases '
        'when you fulfill orders on time and decreases when you cancel or fail '
        'to deliver. A higher Trust Score gives your offers higher visibility '
        'during automatic matching.',
  ),
  FaqItem(
    question: 'What happens if I cannot fulfill an order?',
    answer:
        'If you cannot fulfill an order, cancel it as early as possible through '
        'the Manage Orders screen. Late cancellations affect your Trust Score. '
        'If a pledged item fails, the consumer receives a full refund and their '
        'CFP subscription is extended by 1 month.',
  ),
  FaqItem(
    question: 'How do I manage my subscriptions and programs?',
    answer:
        'Navigate to Profile → Subscriptions to view your active plans. '
        'Duruha Programs are accessible via Profile → Duruha Programs, where '
        'you can join programs that give you access to better pricing tiers '
        'and promotional opportunities.',
  ),
  FaqItem(
    question: 'How are delivery fees calculated?',
    answer:
        'Delivery fees are calculated based on the road distance from your '
        'farm to the consumer. Fees are charged per farmer, not per item — '
        'so if a consumer orders multiple items from you, they pay a single '
        'delivery fee split across those items.',
  ),
];

// ─── Consumer FAQ ─────────────────────────────────────────────────────────────

const consumerFaqItems = <FaqItem>[
  FaqItem(
    question: 'What is Order Mode?',
    answer:
        'Order Mode lets you buy produce for immediate needs or schedule a '
        'delivery up to 30 days ahead. Prices are based on current market '
        'listings. You can lock a price by paying immediately, protecting you '
        'from market fluctuations before your scheduled delivery.',
  ),
  FaqItem(
    question: 'What is Consumer Future Plan (CFP)?',
    answer:
        'CFP is a subscription service that lets you plan produce purchases '
        '1, 3, 6, or 12 months ahead. Your demand is signaled to farmers so '
        'they can prepare pledges for you. Pricing is based on market ranges, '
        'ensuring fair value for both you and the farmer.',
  ),
  FaqItem(
    question: 'What is Price Lock and how do I use it?',
    answer:
        'Price Lock lets you secure the current market price for a future '
        'delivery date. To activate it, choose "Immediate Payment" when placing '
        'an order. This protects you if market prices rise before your delivery '
        'day arrives.',
  ),
  FaqItem(
    question: 'What happens if my pledged item is not fulfilled?',
    answer:
        'If a farmer fails to fulfill your pledged item, Dirikita will refund '
        'the full amount to your balance and automatically extend your CFP '
        'subscription by 1 month as an apology for the inconvenience.',
  ),
  FaqItem(
    question: 'How are delivery fees charged?',
    answer:
        'Dirikita charges one delivery fee per farmer, not per item. If you '
        'order multiple items from the same farmer, you pay a single delivery '
        'fee. Fees are based on the road distance from the farm to your '
        'delivery address.',
  ),
  FaqItem(
    question: 'How does automatic variety matching work?',
    answer:
        'When you select "Any Variety," our system finds the best match based '
        'on proximity, harvest readiness, and stock availability. The closest '
        'farmer with the most stock is prioritized. If local stock runs out, '
        'we look further to ensure you still receive your produce.',
  ),
  FaqItem(
    question: 'What quality tiers are available?',
    answer:
        'Three quality tiers are available:\n'
        '• Saver — 0% fee (best value)\n'
        '• Regular — 5% fee (standard quality)\n'
        '• Select — 15% fee (premium curation)',
  ),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

FaqGroup farmerFaqGroup() => FaqGroup(
  title: 'For Farmers',
  sections: farmerFaqItems.map((e) => e.toSection()).toList(),
);

FaqGroup consumerFaqGroup() => FaqGroup(
  title: 'For Consumers',
  sections: consumerFaqItems.map((e) => e.toSection()).toList(),
);
