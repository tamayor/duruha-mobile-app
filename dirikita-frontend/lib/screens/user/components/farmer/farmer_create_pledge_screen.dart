import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:duruha/theme/duruha_styles.dart';
import 'package:duruha/widgets/duruha_widgets.dart';
import 'package:duruha/data/mock_data.dart';
import 'package:duruha/models/user_models.dart';

class FarmerCreatePledgeScreen extends StatefulWidget {
  const FarmerCreatePledgeScreen({super.key});

  @override
  State<FarmerCreatePledgeScreen> createState() =>
      _FarmerCreatePledgeScreenState();
}

class _FarmerCreatePledgeScreenState extends State<FarmerCreatePledgeScreen> {
  // Form State
  final _formKey = GlobalKey<FormState>();
  ProduceItem? _selectedCrop;
  final List<String> _selectedVariants = [];
  DateTime? _plantingDate;
  final _quantityController = TextEditingController();
  String _selectedUnit = 'kg';
  bool _isSubmitting = false;

  // Controllers for Read-only fields
  final _dateController = TextEditingController();

  final List<String> _units = ['kg', 'tons', 'sacks', 'pieces', 'kaing'];

  // Use MockData for farmer's pledged crops logic (assuming we pick from available produce)
  // For simplicity, let's allow them to pledge any produce in the system for now,
  // or strictly from their profile if that was the intent.
  // The user prompt said "myCrops" in the mock, so let's use MockData.allProduce as available options
  // since a "New Pledge" might be for a new crop type.
  final List<ProduceItem> _availableCrops = MockData.allProduce;

  @override
  void dispose() {
    _quantityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // --- LOGIC: DATE PICKER ---
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now, // Can't pledge in the past
      lastDate: DateTime(now.year + 2), // 2 years into future
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor, // Header background
              onPrimary: theme.colorScheme.onPrimary, // Header text
              onSurface: theme.colorScheme.onSurface, // Body text
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _plantingDate = picked;
        _dateController.text = DateFormat('MMMM dd, yyyy').format(picked);
      });
    }
  }

  // --- LOGIC: VARIANT TOGGLE ---
  void _toggleVariant(String variant) {
    setState(() {
      if (_selectedVariants.contains(variant)) {
        _selectedVariants.remove(variant);
      } else {
        _selectedVariants.add(variant);
      }
    });
  }

  // --- LOGIC: SUBMIT ---
  void _submitPledge() {
    if (_formKey.currentState!.validate()) {
      if (_selectedVariants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one variant')),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      // SIMULATE API CALL
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _isSubmitting = false);

        // Success Logic (e.g., Pop back to dashboard)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pledge for ${_selectedCrop?.nameEnglish} Created!'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("New Harvest Pledge"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SELECT CROP (Dropdown)
              const SizedBox(height: 8),
              DuruhaDropdown<ProduceItem>(
                value: _selectedCrop,
                label: "Choose crop",
                prefixIcon: Icons.agriculture,
                items: _availableCrops,
                labelBuilder: (crop) {
                  // Resolve name based on dialect
                  final dialect = MockData.mockFarmer.dialect;
                  final displayName =
                      crop.namesByDialect[dialect.toLowerCase()] ??
                      crop.namesByDialect['tagalog'] ??
                      crop.nameEnglish;
                  return "$displayName (${crop.nameEnglish})";
                },
                onChanged: (val) {
                  setState(() {
                    _selectedCrop = val;
                    if (val != null) {
                      _selectedVariants
                          .clear(); // Reset variants on crop change
                    }
                  });
                },
                validator: (val) => val == null ? 'Please select a crop' : null,
              ),

              const SizedBox(height: 24),

              // 2. SELECT VARIANTS (Shows only after crop is picked)
              if (_selectedCrop != null) ...[
                DuruhaSelectionChipGroup(
                  title: "Crop Variants",
                  subtitle: "Which varieties are you planting?",
                  options: _selectedCrop!.availableVarieties,
                  selectedValues: _selectedVariants,
                  onToggle: _toggleVariant,
                ),
                const SizedBox(height: 24),
              ],

              // 3. PLANTING DATE
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  // Prevents keyboard from opening
                  child: DuruhaTextField(
                    label: "Planned Planting Date",
                    icon: Icons.calendar_today,
                    controller: _dateController,
                    validator: (v) =>
                        _plantingDate == null ? 'Date is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. QUANTITY & UNIT ROW
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity Input (Flex 2)
                  Expanded(
                    flex: 2,
                    child: DuruhaTextField(
                      label: "Quantity",
                      icon: Icons.scale,
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Unit Dropdown (Flex 1)
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration:
                          (DuruhaStyles.inputDecoration(
                                    context,
                                    label: "Unit",
                                    icon: Icons.straighten,
                                  ) ??
                                  const InputDecoration())
                              .copyWith(
                                // Remove icon for cleaner tight fit
                                prefixIcon: null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                      items: _units
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 5. SUBMIT BUTTON
              DuruhaButton(
                text: "Confirm Pledge",
                isLoading: _isSubmitting,
                onPressed: _submitPledge,
              ),

              if (_selectedCrop != null ||
                  _quantityController.text.isNotEmpty ||
                  _plantingDate != null) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Pledge Preview",
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildPreviewRow(
                        "Crop",
                        _selectedCrop?.nameEnglish ?? "-",
                      ),
                      _buildPreviewRow(
                        "Variety",
                        _selectedVariants.isNotEmpty
                            ? _selectedVariants.join(", ")
                            : "-",
                      ),
                      _buildPreviewRow(
                        "Quantity",
                        "${_quantityController.text.isEmpty ? '-' : _quantityController.text} $_selectedUnit",
                      ),
                      _buildPreviewRow(
                        "Planting Date",
                        _plantingDate != null
                            ? DateFormat('MMM d, yyyy').format(_plantingDate!)
                            : "-",
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
