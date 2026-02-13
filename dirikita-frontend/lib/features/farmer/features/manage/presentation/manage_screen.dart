import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/loading_screen.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/manage/data/manage_repository.dart';

import 'manage_offer_screen.dart';
import 'manage_pledge_screen.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  final _repository = ManageRepository();
  bool _isLoading = true;
  bool _isOfferMode = false;
  List<HarvestPledge> _pledges = [];
  List<HarvestOffer> _offers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final savedMode = await _repository.fetchViewMode();
      final pledges = await _repository.fetchPledges();
      final offers = await _repository.fetchOffers();
      if (!mounted) return;

      setState(() {
        _isOfferMode = savedMode;
        _pledges = pledges;
        _offers = offers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMode(bool isOffer) async {
    setState(() => _isOfferMode = isOffer);
    await _repository.saveViewMode(isOffer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScaffold(
      appBarTitle: _isOfferMode ? "Manage Offers" : "Manage Pledges",
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(2),
          child: DuruhaToggleButton(
            value: _isOfferMode,
            onChanged: _toggleMode,
            labelTrue: "",
            labelFalse: "",
            iconTrue: Icons.local_offer_rounded,
            iconFalse: Icons.handshake_rounded,
            contentColorTrue: theme.colorScheme.onPrimaryContainer,
            contentColorFalse: theme.colorScheme.onSecondaryContainer,
            colorTrue: theme.colorScheme.primaryContainer,
            colorFalse: theme.colorScheme.secondaryContainer,
          ),
        ),
        const SizedBox(width: 16),
      ],
      bottomNavigationBar: const FarmerNavigation(
        name: "Elly", // Dynamic name later
        currentRoute: '/farmer/manage',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : _isOfferMode
          ? ManageOfferScreen(offers: _offers)
          : ManagePledgeScreen(pledges: _pledges),
    );
  }
}
