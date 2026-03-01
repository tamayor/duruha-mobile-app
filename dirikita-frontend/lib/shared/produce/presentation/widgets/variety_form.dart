import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/presentation/widgets/smart_paste_input.dart';

class VarietyForm extends StatefulWidget {
  final String produceId;
  final Function(Map<String, dynamic>) onSave;
  final ProduceRepository repository;
  final String produceName;

  const VarietyForm({
    super.key,
    required this.produceId,
    required this.onSave,
    required this.repository,
    required this.produceName,
    this.initialData,
  });

  final Map<String, dynamic>? initialData;

  @override
  State<VarietyForm> createState() => _VarietyFormState();
}

class _VarietyFormState extends State<VarietyForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _varietyNameController = TextEditingController();
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

  static const _breedingTypes = [
    'Inbred',
    'Hybrid (F1)',
    'OPV',
    'Native/Landrace',
    'Heirloom',
    'Clonal/Grafted',
    'Tissue Culture',
    'Triploid (Seedless)',
  ];
  static const _seasons = ['Dry Season', 'Wet Season', 'Year-round'];

  bool _isNative = false;
  String? _selectedBreedingType;
  String? _selectedSeason;

  @override
  void dispose() {
    _varietyNameController.dispose();
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

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) _populateForm(widget.initialData!);
  }

  void _populateForm(Map<String, dynamic> data) {
    _varietyNameController.text = data['variety_name'] ?? '';
    _imageUrlController.text = data['image_url'] ?? '';
    _daysToMaturityMinController.text = (data['days_to_maturity_min'] ?? '')
        .toString();
    _daysToMaturityMaxController.text = (data['days_to_maturity_max'] ?? '')
        .toString();
    if (data['peak_months'] != null) {
      _peakMonthsController.text = (data['peak_months'] as List).join(', ');
    }
    _philippineSeasonController.text = data['philippine_season'] ?? '';
    _floodToleranceController.text = (data['flood_tolerance'] ?? '').toString();
    _handlingFragilityController.text = (data['handling_fragility'] ?? '')
        .toString();
    _shelfLifeDaysController.text = (data['shelf_life_days'] ?? '').toString();
    _optimalStorageTempController.text = (data['optimal_storage_temp_c'] ?? '')
        .toString();
    _packagingRequirementController.text = data['packaging_requirement'] ?? '';
    _appearanceDescController.text = data['appearance_desc'] ?? '';
    _isNative = data['is_native'] ?? false;
    _selectedBreedingType = data['breeding_type'];
    if (_selectedBreedingType != null &&
        !_breedingTypes.contains(_selectedBreedingType)) {
      _selectedBreedingType = null;
    }
    _selectedSeason = data['philippine_season'];
    if (_selectedSeason != null && !_seasons.contains(_selectedSeason)) {
      _selectedSeason = null;
    }
  }

  void _fillFormFromSmartPaste(List<String> values) {
    try {
      if (values.length < 12) {
        DuruhaSnackBar.showWarning(
          context,
          'Parsed ${values.length} values. Expected at least 12.',
        );
        return;
      }
      setState(() {
        if (values.isNotEmpty) {
          _varietyNameController.text = _cleanValue(values[0]);
        }
        if (values.length > 1) {
          _isNative = _cleanValue(values[1]).toLowerCase() == 'true';
        }
        if (values.length > 2) {
          final parsed = _cleanValue(values[2]);
          _selectedBreedingType = _breedingTypes.firstWhere(
            (e) => e.toLowerCase() == parsed.toLowerCase(),
            orElse: () => parsed,
          );
          if (!_breedingTypes.contains(_selectedBreedingType)) {
            _selectedBreedingType = null;
          }
        }
        if (values.length > 3) {
          _daysToMaturityMinController.text = _cleanValue(values[3]);
        }
        if (values.length > 4) {
          _daysToMaturityMaxController.text = _cleanValue(values[4]);
        }
        if (values.length > 5) {
          final rawMonths = values[5];
          if (rawMonths.toUpperCase().contains('ARRAY[')) {
            _peakMonthsController.text = rawMonths
                .replaceAll(RegExp(r'ARRAY\[|\]', caseSensitive: false), '')
                .replaceAll('"', '')
                .replaceAll("'", "");
          } else {
            _peakMonthsController.text = _cleanValue(rawMonths);
          }
        }
        if (values.length > 6) {
          final parsed = _cleanValue(values[6]);
          _selectedSeason = _seasons.firstWhere(
            (e) => e.toLowerCase() == parsed.toLowerCase(),
            orElse: () => parsed,
          );
          if (!_seasons.contains(_selectedSeason)) _selectedSeason = null;
        }
        if (values.length > 7) {
          _floodToleranceController.text = _cleanValue(values[7]);
        }
        if (values.length > 8) {
          _handlingFragilityController.text = _cleanValue(values[8]);
        }
        if (values.length > 9) {
          _shelfLifeDaysController.text = _cleanValue(values[9]);
        }
        if (values.length > 10) {
          _optimalStorageTempController.text = _cleanValue(values[10]);
        }
        if (values.length > 11) {
          _packagingRequirementController.text = _cleanValue(values[11]);
        }
        if (values.length > 12) {
          _appearanceDescController.text = _cleanValue(values[12]);
        }
        if (values.length > 13) {
          _imageUrlController.text = _cleanValue(values[13]);
        }
      });
      DuruhaSnackBar.showSuccess(context, 'Form auto-filled from Smart Paste!');
    } catch (e) {
      DuruhaSnackBar.showError(context, 'Error parsing input: $e');
    }
  }

  String _cleanValue(String val) {
    var v = val.trim();
    if ((v.startsWith("'") && v.endsWith("'")) ||
        (v.startsWith('"') && v.endsWith('"'))) {
      return v.substring(1, v.length - 1);
    }
    return v;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final data = {
        'variety_name': _varietyNameController.text.trim(),
        'produce_id': widget.produceId,
        if (widget.initialData != null) 'variety_id': widget.initialData!['id'],
        'is_native': _isNative,
        'image_url': _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        'breeding_type': _selectedBreedingType,
        'days_to_maturity_min': int.tryParse(_daysToMaturityMinController.text),
        'days_to_maturity_max': int.tryParse(_daysToMaturityMaxController.text),
        'peak_months': _peakMonthsController.text.trim().isEmpty
            ? null
            : _peakMonthsController.text.split(',').map((e) {
                final m = e.trim();
                return m.length > 3 ? m.substring(0, 3) : m;
              }).toList(),
        'philippine_season': _selectedSeason,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SmartPasteInput(
              onValuesParsed: _fillFormFromSmartPaste,
              fieldLabels: const [
                'Variety Name',
                'Is Native',
                'Breeding Type',
                'Min Days',
                'Max Days',
                'Peak Months',
                'Season',
                'Flood Tol.',
                'Fragility',
                'Shelf Life',
                'Storage Temp',
                'Packaging',
                'Appearance',
                'Image URL',
                'Price',
              ],
              promptToCopy:
                  '''Act as a Senior SQL Developer and Agricultural Specialist. I will give you a ${widget.produceName}. 
Give me at least 5 Generate a valid PostgreSQL INSERT statement for one popular variety of that produce in the Philippines.
Strict Rules:
1. Breeding Type: Choose ONLY from: ['Inbred', 'Hybrid (F1)', 'OPV', 'Native/Landrace', 'Heirloom', 'Clonal/Grafted', 'Tissue Culture', 'Triploid (Seedless)'].
2. Season: Choose ONLY from: ['Dry Season', 'Wet Season', 'Year-round'].
3. Format: Use ARRAY['Month1', 'Month2'] for peak months.
4. Logic: > - flood_tolerance and handling_fragility must be integers (1-5).
    * is_native is a boolean (true/false).
    * variety_id (if required) should be a slug like 'CROP-VARIETY'.
5. Local Context: Base the maturity and description on Philippine tropical conditions.


INSERT INTO "public"."produce_varieties" (
  "variety_name", 
  "is_native", 
  "breeding_type", 
  "days_to_maturity_min", 
  "days_to_maturity_max", 
  "peak_months", 
  "philippine_season", 
  "flood_tolerance", 
  "handling_fragility", 
  "shelf_life_days", 
  "optimal_storage_temp_c", 
  "packaging_requirement", 
  "appearance_desc", 
  "image_url", 
) VALUES (
  'Variety Name', 
  'false', 
  'Hybrid (F1)', 
  '60', 
  '90', 
  ARRAY['Jan','Feb'], 
  'Dry Season', 
  '3', 
  '3', 
  '7', 
  '12.5', 
  'Crates', 
  'Description here', 
  'https://example.com/image.jpg', 
);
''',
            ),
            const SizedBox(height: 24),
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
            CheckboxListTile(
              title: const Text('Is Native'),
              value: _isNative,
              onChanged: (value) => setState(() => _isNative = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            Text(
              'OPTIONAL FIELDS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            DuruhaTextField(
              controller: _imageUrlController,
              label: 'Image URL',
              icon: Icons.image,
              isRequired: false,
            ),
            DuruhaDropdown<String>(
              value: _selectedBreedingType,
              label: 'Breeding Type',
              prefixIcon: Icons.biotech,
              items: _breedingTypes,
              onChanged: (val) => setState(() => _selectedBreedingType = val),
              isRequired: false,
            ),
            const SizedBox(height: 12),
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
            DuruhaDropdown<String>(
              value: _selectedSeason,
              label: 'Philippine Season',
              prefixIcon: Icons.wb_sunny,
              items: _seasons,
              onChanged: (val) => setState(() => _selectedSeason = val),
              isRequired: false,
            ),
            const SizedBox(height: 12),
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
            DuruhaButton(
              onPressed: _isSaving ? null : _handleSave,
              text: _isSaving
                  ? 'Saving...'
                  : (widget.initialData != null
                        ? 'Update Variety'
                        : 'Save Variety'),
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
