import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';

class AddVarietyForm extends StatefulWidget {
  final String produceId;
  final Function(Map<String, dynamic>) onSave;
  final ProduceRepository repository;

  const AddVarietyForm({
    super.key,
    required this.produceId,
    required this.onSave,
    required this.repository,
  });

  @override
  State<AddVarietyForm> createState() => _AddVarietyFormState();
}

class _AddVarietyFormState extends State<AddVarietyForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Text Controllers for all fields
  final _varietyNameController = TextEditingController();
  final _multiplierController = TextEditingController(text: '1.00');
  final _imageUrlController = TextEditingController();
  final _breedingTypeController = TextEditingController();
  final _daysToMaturityMinController = TextEditingController();
  final _daysToMaturityMaxController = TextEditingController();
  final _peakMonthsController = TextEditingController();
  final _philippineSeasonController = TextEditingController();
  final _floodToleranceController = TextEditingController();
  final _handlingFragilityController = TextEditingController();
  final _shelfLifeDaysController = TextEditingController();
  final _optimalStorageTempController = TextEditingController();
  final _packagingRequirementController = TextEditingController();
  final _appearanceDescController = TextEditingController();

  bool _isNative = false;

  @override
  void dispose() {
    _varietyNameController.dispose();
    _multiplierController.dispose();
    _imageUrlController.dispose();
    _breedingTypeController.dispose();
    _daysToMaturityMinController.dispose();
    _daysToMaturityMaxController.dispose();
    _peakMonthsController.dispose();
    _philippineSeasonController.dispose();
    _floodToleranceController.dispose();
    _handlingFragilityController.dispose();
    _shelfLifeDaysController.dispose();
    _optimalStorageTempController.dispose();
    _packagingRequirementController.dispose();
    _appearanceDescController.dispose();
    super.dispose();
  }

  void _parsePastedData(String pastedText) {
    final values = pastedText.split(',').map((e) => e.trim()).toList();

    if (values.isEmpty) {
      return;
    }

    if (values.isNotEmpty) {
      _varietyNameController.text = values[0];
    }
    if (values.length > 1) {
      _isNative = values[1].toLowerCase() == 'true' || values[1] == '1';
    }
    if (values.length > 2) {
      _breedingTypeController.text = values[2];
    }
    if (values.length > 3) {
      _daysToMaturityMinController.text = values[3];
    }
    if (values.length > 4) {
      _daysToMaturityMaxController.text = values[4];
    }
    if (values.length > 5) {
      _peakMonthsController.text = values[5];
    }
    if (values.length > 6) {
      _philippineSeasonController.text = values[6];
    }
    if (values.length > 7) {
      _floodToleranceController.text = values[7];
    }
    if (values.length > 8) {
      _handlingFragilityController.text = values[8];
    }
    if (values.length > 9) {
      _shelfLifeDaysController.text = values[9];
    }
    if (values.length > 10) {
      _optimalStorageTempController.text = values[10];
    }
    if (values.length > 11) {
      _packagingRequirementController.text = values[11];
    }
    if (values.length > 12) {
      _appearanceDescController.text = values[12];
    }
    if (values.length > 13) {
      _imageUrlController.text = values[13];
    }
    if (values.length > 14) {
      _multiplierController.text = values[14];
    }

    setState(() {});
  }

  String _generateVarietyId(String varietyName) {
    // Split by spaces and take first 3 letters of each word
    final words = varietyName.trim().toUpperCase().split(' ');
    final idParts = <String>[];

    for (final word in words) {
      if (word.isNotEmpty) {
        // Take first 3 letters, or all letters if word is shorter
        idParts.add(word.substring(0, word.length < 3 ? word.length : 3));
      }
    }

    return idParts.join('');
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Get existing variety count for this produce
      final varietyCount = await widget.repository.getVarietyCount(
        widget.produceId,
      );
      final increment = varietyCount + 1;

      // Generate variety ID based on variety name
      final baseId = _generateVarietyId(_varietyNameController.text);
      final varietyId = '$baseId-$increment';

      final data = {
        'variety_id': varietyId,
        'variety_name': _varietyNameController.text.trim(),
        'produce_id': widget.produceId,
        'is_native': _isNative,
        'variety_multiplier':
            double.tryParse(_multiplierController.text) ?? 1.0,
        'image_url': _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        'breeding_type': _breedingTypeController.text.trim().isEmpty
            ? null
            : _breedingTypeController.text.trim(),
        'days_to_maturity_min': int.tryParse(_daysToMaturityMinController.text),
        'days_to_maturity_max': int.tryParse(_daysToMaturityMaxController.text),
        'peak_months': _peakMonthsController.text.trim().isEmpty
            ? null
            : _peakMonthsController.text
                  .split(',')
                  .map((e) => e.trim())
                  .toList(),
        'philippine_season': _philippineSeasonController.text.trim().isEmpty
            ? null
            : _philippineSeasonController.text.trim(),
        'flood_tolerance': int.tryParse(_floodToleranceController.text),
        'handling_fragility': int.tryParse(_handlingFragilityController.text),
        'shelf_life_days': int.tryParse(_shelfLifeDaysController.text),
        'optimal_storage_temp_c': double.tryParse(
          _optimalStorageTempController.text,
        ),
        'packaging_requirement':
            _packagingRequirementController.text.trim().isEmpty
            ? null
            : _packagingRequirementController.text.trim(),
        'appearance_desc': _appearanceDescController.text.trim().isEmpty
            ? null
            : _appearanceDescController.text.trim(),
      };

      await widget.onSave(data);
      if (mounted && context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Paste from clipboard button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withAlpha(100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Paste comma-separated values to auto-fill fields',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _parsePastedData(data!.text!);
                    }
                  },
                  icon: const Icon(Icons.content_paste, size: 16),
                  label: const Text('Paste'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Required Fields
          Text(
            'REQUIRED FIELDS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          DuruhaTextField(
            controller: _varietyNameController,
            label: 'Variety Name',
            icon: Icons.eco,
          ),

          // Is Native Toggle
          CheckboxListTile(
            title: const Text('Is Native'),
            value: _isNative,
            onChanged: (value) => setState(() => _isNative = value ?? false),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 16),

          // Optional Fields
          Text(
            'OPTIONAL FIELDS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          DuruhaTextField(
            controller: _multiplierController,
            label: 'Price Multiplier',
            icon: Icons.percent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            isRequired: false,
          ),

          DuruhaTextField(
            controller: _imageUrlController,
            label: 'Image URL',
            icon: Icons.image,
            isRequired: false,
          ),

          DuruhaTextField(
            controller: _breedingTypeController,
            label: 'Breeding Type',
            icon: Icons.biotech,
            isRequired: false,
          ),

          Row(
            children: [
              Expanded(
                child: DuruhaTextField(
                  controller: _daysToMaturityMinController,
                  label: 'Days to Maturity (Min)',
                  icon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  isRequired: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DuruhaTextField(
                  controller: _daysToMaturityMaxController,
                  label: 'Days to Maturity (Max)',
                  icon: Icons.calendar_month,
                  keyboardType: TextInputType.number,
                  isRequired: false,
                ),
              ),
            ],
          ),

          DuruhaTextField(
            controller: _peakMonthsController,
            label: 'Peak Months (comma-separated)',
            icon: Icons.event_available,
            isRequired: false,
          ),

          DuruhaTextField(
            controller: _philippineSeasonController,
            label: 'Philippine Season',
            icon: Icons.wb_sunny,
            isRequired: false,
          ),

          Row(
            children: [
              Expanded(
                child: DuruhaTextField(
                  controller: _floodToleranceController,
                  label: 'Flood Tolerance (1-5)',
                  icon: Icons.water,
                  keyboardType: TextInputType.number,
                  isRequired: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DuruhaTextField(
                  controller: _handlingFragilityController,
                  label: 'Handling Fragility (1-5)',
                  icon: Icons.priority_high,
                  keyboardType: TextInputType.number,
                  isRequired: false,
                ),
              ),
            ],
          ),

          Row(
            children: [
              Expanded(
                child: DuruhaTextField(
                  controller: _shelfLifeDaysController,
                  label: 'Shelf Life (Days)',
                  icon: Icons.hourglass_top,
                  keyboardType: TextInputType.number,
                  isRequired: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DuruhaTextField(
                  controller: _optimalStorageTempController,
                  label: 'Storage Temp (°C)',
                  icon: Icons.ac_unit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  isRequired: false,
                ),
              ),
            ],
          ),

          DuruhaTextField(
            controller: _packagingRequirementController,
            label: 'Packaging Requirement',
            icon: Icons.inventory_2,
            maxLines: 2,
            isRequired: false,
          ),

          DuruhaTextField(
            controller: _appearanceDescController,
            label: 'Appearance Description',
            icon: Icons.description,
            maxLines: 3,
            isRequired: false,
          ),

          const SizedBox(height: 24),

          // Save Button
          DuruhaButton(
            onPressed: _isSaving ? null : _handleSave,
            text: _isSaving ? 'Saving...' : 'Save Variety',
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }
}
