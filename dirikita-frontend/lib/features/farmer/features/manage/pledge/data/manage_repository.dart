import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/manage/offers/domain/offer_model.dart';
import 'package:duruha/features/farmer/features/manage/offers/data/manage_offer_repository.dart';

class ManageRepository {
  final _pledgeRepository = PledgeRepository();
  final _offerRepository = ManageOfferRepository();

  /// Fetches pledges from the shared repository.
  Future<List<HarvestPledge>> fetchPledges() {
    return _pledgeRepository.fetchMyPledges();
  }

  /// Fetches date-grouped offers from the offer repository.
  Future<({List<DailyOfferGroup> groups, bool hasMore})> fetchOffers({
    required bool active,
    String? cursor,
  }) {
    return _offerRepository.fetchOffers(active: active, cursor: cursor);
  }
}
