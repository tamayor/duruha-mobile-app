import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/supabase_config.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'offer_detail_screen.dart';
import '../domain/offer_model.dart';

class OfferDetailLoaderScreen extends StatefulWidget {
  final String offerId;

  const OfferDetailLoaderScreen({super.key, required this.offerId});

  @override
  State<OfferDetailLoaderScreen> createState() =>
      _OfferDetailLoaderScreenState();
}

class _OfferDetailLoaderScreenState extends State<OfferDetailLoaderScreen> {
  late Future<({HarvestOffer offer, ProduceGroup produce})> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadOfferDetails();
  }

  Future<({HarvestOffer offer, ProduceGroup produce})>
  _loadOfferDetails() async {
    final response = await supabase
        .from('farmer_offers')
        .select('''
          *,
          farmer_price_lock_subscriptions(
            status
          ),
          produce_varieties(
            variety_name,
            produce:produce_id(
              id,
              english_name
            )
          )
        ''')
        .eq('offer_id', widget.offerId)
        .single();

    final variety = response['produce_varieties'];
    final produce = variety['produce'];

    final produceGroup = ProduceGroup(
      produceId: produce['id'],
      produceLocalName: produce['english_name'] ?? '',
      produceEnglishName: produce['english_name'] ?? '',
      varieties: [],
    );

    final String availableFromStr =
        response['available_from'] ?? response['created_at'];

    final fplsStatus =
        response['farmer_price_lock_subscriptions']?['status'] ?? '';

    final harvestOffer = HarvestOffer(
      fplsStatus: fplsStatus,
      offerId: response['offer_id'],
      varietyName: variety['variety_name'] ?? 'Unknown',
      quantity: (response['quantity'] as num? ?? 0.0).toDouble(),
      remainingQuantity: (response['remaining_quantity'] as num? ?? 0.0)
          .toDouble(),
      isActive: response['is_active'] ?? true,
      isPriceLocked: response['is_price_locked'] ?? false,
      totalPriceLockCredit: (response['total_price_lock_credit'] as num?)
          ?.toDouble(),
      remainingPriceLockCredit:
          (response['remaining_price_lock_credit'] as num?)?.toDouble(),
      availableFrom: DateTime.parse(availableFromStr),
      availableTo: response['available_to'] != null
          ? DateTime.parse(response['available_to'])
          : DateTime(2100),
      ordersTotalPrice: 0,
      farmerTotalEarnings: 0,
      orders: [],
    );

    return (offer: harvestOffer, produce: produceGroup);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DuruhaScaffold(
            appBarTitle: 'Offer Details',
            body: FarmerLoadingScreen(),
          );
        } else if (snapshot.hasError) {
          return DuruhaScaffold(
            appBarTitle: 'Offer Details',
            body: Center(child: Text("Error loading offer: ${snapshot.error}")),
          );
        } else if (!snapshot.hasData) {
          return const DuruhaScaffold(
            appBarTitle: 'Offer Details',
            body: Center(child: Text("Offer not found")),
          );
        }

        return OfferDetailScreen(
          offer: snapshot.data!.offer,
          produce: snapshot.data!.produce,
          isActive: snapshot.data!.offer.isActive,
        );
      },
    );
  }
}
