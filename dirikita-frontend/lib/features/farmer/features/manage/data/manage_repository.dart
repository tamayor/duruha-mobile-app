import 'package:shared_preferences/shared_preferences.dart';
import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';

class ManageRepository {
  final _pledgeRepository = PledgeRepository();
  static const String _modeKey = 'manage_is_offer_mode';

  /// Fetches the persisted view mode (Offer vs Pledge).
  /// Returns `true` for Offer mode, `false` for Pledge mode (default).
  Future<bool> fetchViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_modeKey) ?? false;
  }

  /// Persists the view mode.
  Future<void> saveViewMode(bool isOfferMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modeKey, isOfferMode);
  }

  /// Fetches pledges from the shared repository.
  Future<List<HarvestPledge>> fetchPledges() {
    return _pledgeRepository.fetchMyPledges();
  }
}
