import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/features/admin/produce/data/produce_repository.dart';

import 'widgets/admin_produce_form_models.dart';
import 'widgets/admin_produce_level_widget.dart';
import 'widgets/admin_variety_level_widget.dart';

class AdminProduceFormScreen extends StatefulWidget {
  final Produce? produceToEdit;

  const AdminProduceFormScreen({super.key, this.produceToEdit});

  @override
  State<AdminProduceFormScreen> createState() => _AdminProduceFormScreenState();
}

class _AdminProduceFormScreenState extends State<AdminProduceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FormProduce _produce = FormProduce();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initEditMode();
  }

  void _initEditMode() {
    if (widget.produceToEdit == null) return;

    final p = widget.produceToEdit!;
    _produce.id = p.id;
    _produce.englishName.text = p.englishName;
    _produce.scientificName.text = p.scientificName ?? '';
    _produce.baseUnit.text = p.baseUnit;
    _produce.imageUrl.text = p.imageUrl ?? '';
    _produce.category = p.category;
    _produce.storageGroup = p.storageGroup ?? '';
    _produce.respirationRate = p.respirationRate ?? '';
    _produce.isEthyleneProducer = p.isEthyleneProducer ?? false;
    _produce.isEthyleneSensitive = p.isEthyleneSensitive ?? false;
    _produce.crushWeightTolerance.text = p.crushWeightTolerance.toString();
    _produce.crossContaminationRisk.text = p.crossContaminationRisk ?? '';

    for (final v in p.varieties) {
      final formV = FormVariety();
      formV.varietyId = v.id;
      formV.name.text = v.name;
      formV.isNative = v.isNative;
      formV.breedingType = v.breedingType ?? 'OPV';
      formV.daysMin.text = v.daysToMaturityMin?.toString() ?? '';
      formV.daysMax.text = v.daysToMaturityMax?.toString() ?? '';
      formV.floodTolerance.text = v.floodTolerance?.toString() ?? '';
      formV.shelfLifeDays.text = v.shelfLifeDays.toString();
      formV.handlingFragility.text = v.handlingFragility?.toString() ?? '';
      formV.packagingReq.text = v.packagingRequirement ?? '';
      formV.optimalTemp.text = v.optimalStorageTempC?.toString() ?? '';
      formV.philippineSeason = v.philippineSeason ?? 'Year-round';
      formV.peakMonths.text = v.peakMonths.join(', ');
      formV.appearanceDesc.text = v.appearanceDesc ?? '';
      formV.imageUrl.text = v.imageUrl ?? '';

      for (final l in v.listings) {
        final formL = FormListing();
        formL.listingId = l.listingId;
        formL.produceForm.text = l.produceForm ?? '';
        formL.farmerToTraderPrice.text = l.farmerToTraderPrice.toString();
        formL.farmerToDuruhaPrice.text = l.farmerToDuruhaPrice.toString();
        formL.duruhaToConsumerPrice.text = l.duruhaToConsumerPrice.toString();
        formL.marketToConsumerPrice.text = l.marketToConsumerPrice.toString();
        formV.listings.add(formL);
      }

      _produce.varieties.add(formV);
    }
  }

  @override
  void dispose() {
    _produce.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    debugPrint('🚀 [AdminProduceForm] Starting submission...');
    final formState = _formKey.currentState;
    if (formState == null) {
      debugPrint('❌ [AdminProduceForm] Error: _formKey.currentState is null');
      return;
    }

    if (!formState.validate()) {
      debugPrint('⚠️ [AdminProduceForm] Validation failed.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('User session not found. Please log in again.');
      }
      final adminId = user.id;
      final repo = ProduceRepository(client);

      debugPrint('📦 [AdminProduceForm] Building produce payload...');
      // Build the nested payload using the repository's static helpers.
      final payload = ProduceRepository.buildPayload(
        produceId: _produce.id,
        englishName: _produce.englishName.text,
        scientificName: _produce.scientificName.text,
        baseUnit: _produce.baseUnit.text,
        imageUrl: _produce.imageUrl.text,
        category: _produce.category,
        storageGroup: _produce.storageGroup,
        respirationRate: _produce.respirationRate,
        isEthyleneProducer: _produce.isEthyleneProducer,
        isEthyleneSensitive: _produce.isEthyleneSensitive,
        crushWeightTolerance:
            int.tryParse(_produce.crushWeightTolerance.text) ?? 5,
        crossContaminationRisk: _produce.crossContaminationRisk.text,
        varieties: _produce.varieties.map((v) {
          debugPrint(
            '🍎 [AdminProduceForm] Building variety: "${v.name.text}" (ID: ${v.varietyId})',
          );
          return ProduceRepository.buildVariety(
            varietyId: v.varietyId,
            name: v.name.text,
            isNative: v.isNative,
            breedingType: v.breedingType,
            daysToMaturityMin: int.tryParse(v.daysMin.text),
            daysToMaturityMax: int.tryParse(v.daysMax.text),
            philippineSeason: v.philippineSeason,
            floodTolerance: int.tryParse(v.floodTolerance.text),
            handlingFragility: int.tryParse(v.handlingFragility.text),
            shelfLifeDays: int.tryParse(v.shelfLifeDays.text) ?? 7,
            optimalStorageTempC: double.tryParse(v.optimalTemp.text),
            packagingRequirement: v.packagingReq.text,
            appearanceDesc: v.appearanceDesc.text,
            imageUrl: v.imageUrl.text,
            listings: v.listings.map((l) {
              debugPrint(
                '   💰 Listing: "${l.produceForm.text}" (ID: ${l.listingId})',
              );
              return ProduceRepository.buildListing(
                listingId: l.listingId,
                produceForm: l.produceForm.text,
                farmerToTraderPrice:
                    double.tryParse(l.farmerToTraderPrice.text) ?? 0,
                farmerToDuruhaPrice:
                    double.tryParse(l.farmerToDuruhaPrice.text) ?? 0,
                duruhaToConsumerPrice:
                    double.tryParse(l.duruhaToConsumerPrice.text) ?? 0,
                marketToConsumerPrice:
                    double.tryParse(l.marketToConsumerPrice.text) ?? 0,
              );
            }).toList(),
          );
        }).toList(),
      );

      debugPrint('📤 [AdminProduceForm] Sending payload to RPC...');
      debugPrint('Payload: $payload');

      // Route to create or update based on whether a produce id exists.
      if (_produce.id == null) {
        debugPrint('🆕 Creating new produce...');
        await repo.createProduce(adminId: adminId, payload: payload);
      } else {
        debugPrint('📝 Updating existing produce (ID: ${_produce.id})...');
        await repo.updateProduce(
          adminId: adminId,
          produceId: _produce.id!,
          payload: payload,
        );
      }

      if (mounted) {
        DuruhaSnackBar.showSuccess(
          context,
          "Produce hierarchy saved successfully.",
        );
        Navigator.pop(context, true); // Return true to signal refresh
      }
    } catch (e, stack) {
      debugPrint('❌ [AdminProduceForm] Error during submission: $e');
      debugPrint('Stack trace: $stack');
      if (mounted) {
        DuruhaSnackBar.showError(context, "Failed to save produce: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: widget.produceToEdit == null
          ? 'Add Nested Produce'
          : 'Edit Produce',
      showBackButton: true,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0).copyWith(bottom: 100),
          children: [
            AdminProduceLevelWidget(produce: _produce),
            const SizedBox(height: 24),
            AdminVarietyLevelWidget(produce: _produce),
            const SizedBox(height: 32),
            DuruhaButton(
              onPressed: _isSaving ? null : _submitForm,
              text: _isSaving ? "Saving..." : "Save Produce Matrix",
              icon: const Icon(Icons.save),
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
