import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/manage/presentation/widgets/offer_card.dart';

class ManageOfferScreen extends StatelessWidget {
  final List<HarvestOffer> offers;

  const ManageOfferScreen({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Filter active vs history based on disposal date
    final activeOffers = offers
        .where((o) => o.disposalDate.isAfter(now))
        .toList();
    final historyOffers = offers
        .where((o) => o.disposalDate.isBefore(now))
        .toList();

    // Sort active by disposal date soonest
    activeOffers.sort((a, b) => a.disposalDate.compareTo(b.disposalDate));
    // Sort history by recent disposal
    historyOffers.sort((a, b) => b.disposalDate.compareTo(a.disposalDate));

    return DefaultTabController(
      length: 2,
      child: DuruhaScrollHideWrapper(
        bar: const DuruhaTabBar(
          tabs: [
            Tab(text: "Active Offers"),
            Tab(text: "Offer History"),
          ],
        ),
        body: TabBarView(
          children: [
            // Active Offers Tab
            activeOffers.isEmpty
                ? _buildEmptyState(
                    theme,
                    Icons.local_offer_outlined,
                    "No active offers.",
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: activeOffers.length,
                    itemBuilder: (context, index) {
                      return OfferCard(
                        offer: activeOffers[index],
                        isActive: true,
                      );
                    },
                  ),

            // Offer History Tab
            historyOffers.isEmpty
                ? _buildEmptyState(theme, Icons.history, "No offer history.")
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: historyOffers.length,
                    itemBuilder: (context, index) {
                      return OfferCard(
                        offer: historyOffers[index],
                        isActive: false,
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
