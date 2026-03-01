import 'package:duruha/core/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/manage/pledge/data/manage_repository.dart';

import '../../offers/presentation/manage_offer_screen.dart';
import '../../pledge/presentation/manage_pledge_screen.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  final _repository = ManageRepository();
  bool _isLoading = true;
  bool _isPledgeMode = false;
  List<HarvestPledge> _pledges = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Force Offer Mode regardless of saved preference
      final pledges = await _repository.fetchPledges();
      if (!mounted) return;

      setState(() {
        _isPledgeMode = false;
        _pledges = pledges;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMode(bool isPledge) async {
    if (isPledge == true) {
      DuruhaSnackBar.showInfo(context, "Pledge management is coming soon!");
      return;
    }
    setState(() => _isPledgeMode = isPledge);
    await SessionService.saveModePreference(isPledge);
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: _isPledgeMode ? 'Manage Pledges' : 'Manage Offers',
      appBarActions: [
        DuruhaToggleButton(
          value: _isPledgeMode,
          onChanged: _toggleMode,
          iconTrue: Icons.handshake_rounded,
          iconFalse: Icons.local_offer_rounded,
        ),
        const SizedBox(width: 16),
      ],
      bottomNavigationBar: const FarmerNavigation(
        name: 'Elly',
        currentRoute: '/farmer/manage',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : _isPledgeMode
          ? ManagePledgeScreen(pledges: _pledges)
          : const ManageOfferScreen(),
    );
  }
}
