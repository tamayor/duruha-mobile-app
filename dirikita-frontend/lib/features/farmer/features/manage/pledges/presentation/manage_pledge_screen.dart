import 'package:flutter/material.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/features/farmer/features/manage/pledges/data/manage_pledge_repository.dart';
import 'package:duruha/features/farmer/features/manage/pledges/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/manage/pledges/presentation/widgets/pledge_card.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';

class ManagePledgeScreen extends StatefulWidget {
  const ManagePledgeScreen({super.key});

  @override
  State<ManagePledgeScreen> createState() => ManagePledgeScreenState();
}

class ManagePledgeScreenState extends State<ManagePledgeScreen> {
  final _repo = ManagePledgeRepository();
  final _scrollController = ScrollController();

  List<FarmerPledgeGroup> _pledges = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _totalCount = 0;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Public method called by parent ManageScreen to refresh
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final farmerId = await SessionService.getRoleId();
    debugPrint('🚦 [PLEDGE SCREEN] Role ID requested: $farmerId');
    if (farmerId == null) {
      debugPrint('❌ [PLEDGE SCREEN] No Role ID found!');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _repo.fetchPledges(
      farmerId: farmerId,
      limit: _limit,
      offset: 0,
    );
    debugPrint('📊 [PLEDGE SCREEN] Pledges received: ${result.pledges.length}');

    if (mounted) {
      setState(() {
        _pledges = result.pledges;
        _totalCount = result.totalCount;
        _offset = 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _pledges.length >= _totalCount) return;

    final farmerId = await SessionService.getRoleId();
    if (farmerId == null) return;

    setState(() => _isLoadingMore = true);

    final nextOffset = _offset + _limit;
    final result = await _repo.fetchPledges(
      farmerId: farmerId,
      limit: _limit,
      offset: nextOffset,
    );

    if (mounted) {
      setState(() {
        _pledges.addAll(result.pledges);
        _offset = nextOffset;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const FarmerLoadingScreen();

    if (_pledges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No pledges found',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _pledges.length + 1,
        itemBuilder: (context, index) {
          if (index == _pledges.length) {
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox(height: 80); // Bottom spacing
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PledgeCard(pledge: _pledges[index], index: index),
          );
        },
      ),
    );
  }
}
