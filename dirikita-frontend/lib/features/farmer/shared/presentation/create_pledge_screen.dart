import 'package:duruha/features/farmer/shared/data/farmer_shared_repository.dart';
import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:duruha/core/widgets/duruha_widgets.dart';

class FarmerCreatePledgeScreen extends StatefulWidget {
  const FarmerCreatePledgeScreen({super.key});

  @override
  State<FarmerCreatePledgeScreen> createState() =>
      _FarmerCreatePledgeScreenState();
}

class _FarmerCreatePledgeScreenState extends State<FarmerCreatePledgeScreen> {
  // Form State
  final _formKey = GlobalKey<FormState>();
  Produce? _selectedCrop;
  final List<String> _selectedVariants = [];
  DateTime? _harvestDate;
  final _quantityController = TextEditingController();
  String _selectedUnit = 'kg';
  bool _isSubmitting = false;
  String _farmerDialect = 'Tagalog'; // Default

  // Simulation State
  Map<String, dynamic>? _simulatedDemand;
  bool _isLoadingDemand = false;
  // Toggle state

  // Controllers for Read-only fields
  final _dateController = TextEditingController();

  final List<String> _units = ['kg', 'tons', 'sacks', 'pieces', 'kaing'];

  // Use MockData for farmer's pledged crops logic (assuming we pick from available produce)
  List<Produce> _availableCrops = [];
  bool _isLoadingCrops = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadFarmerDialect(), _loadCrops()]);
  }

  Future<void> _loadCrops() async {
    try {
      final crops = await ProduceRepository().getAllProduce();
      if (mounted) {
        setState(() {
          _availableCrops = crops;
          _isLoadingCrops = false;
        });

        // Check argument for pre-selection
        final args = ModalRoute.of(context)?.settings.arguments;
        String? targetCropId;
        String? targetMonth;
        String? targetYear;

        if (args is String) {
          targetCropId = args;
        } else if (args is Map) {
          targetCropId = args['cropId'];
          targetMonth = args['month'];
          targetYear = args['year']?.toString();
        }

        if (targetCropId != null) {
          try {
            final preSelected = crops.firstWhere((p) => p.id == targetCropId);
            setState(() => _selectedCrop = preSelected);
          } catch (_) {
            // ID not found
          }
        }

        if (targetMonth != null) {
          // Parse month string to DateTime
          // Assuming format like "Feb", "Mar", etc. from the mock data
          try {
            final months = [
              "Jan",
              "Feb",
              "Mar",
              "Apr",
              "May",
              "Jun",
              "Jul",
              "Aug",
              "Sep",
              "Oct",
              "Nov",
              "Dec",
            ];
            final monthIndex = months.indexOf(targetMonth) + 1;

            if (monthIndex > 0) {
              int year = DateTime.now().year;

              // If year argument provided, use it
              if (targetYear != null) {
                year = int.tryParse(targetYear) ?? year;
              } else {
                // Heuristic: if month is earlier than current month, assume next year
                if (monthIndex < DateTime.now().month) {
                  year++;
                }
              }

              final date = DateTime(year, monthIndex, 1);
              setState(() {
                _harvestDate = date;
                _dateController.text = DateFormat('MMMM dd, yyyy').format(date);
              });

              // Trigger simulation fetch
              if (_selectedCrop != null) {
                _fetchDemand(date);
              }
            }
          } catch (e) {
            debugPrint("Error parsing month: $e");
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading crops: $e');
      if (mounted) {
        setState(() => _isLoadingCrops = false);
      }
    }
  }

  Future<void> _fetchDemand(DateTime date) async {
    if (_selectedCrop == null) return;

    setState(() => _isLoadingDemand = true);

    try {
      final demand = await PledgeRepository().getDemandForecast(
        _selectedCrop!.id,
        date,
      );
      if (mounted) {
        setState(() {
          _simulatedDemand = demand;
          _isLoadingDemand = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDemand = false);
    }
  }

  Future<void> _loadFarmerDialect() async {
    try {
      final dialect = await FarmerSharedRepository().getUserDialect();
      if (mounted) {
        setState(() {
          _farmerDialect = dialect;
        });
      }
    } catch (e) {
      // Fallback or log error
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // --- LOGIC: DATE PICKER ---
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _harvestDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
        _harvestDate = picked;
        _dateController.text = DateFormat('MMMM dd, yyyy').format(picked);
      });
      _fetchDemand(picked);
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

  void _submitPledge() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVariants.isEmpty) {
        DuruhaSnackBar.showWarning(
          context,
          'Please select at least one variant',
        );
        return;
      }

      // 2. Map UI state to the Domain Model
      String targetMarket = 'Local';
      if (_simulatedDemand != null) {
        final double lDemand = (_simulatedDemand!['local_demand_kg'] as num)
            .toDouble();
        final double lFulfilled =
            (_simulatedDemand!['local_fulfilled_kg'] as num).toDouble();
        if (lFulfilled >= lDemand) {
          targetMarket = 'National';
        }
      }

      final pledge = HarvestPledge(
        cropId: _selectedCrop?.id,
        cropName: _selectedCrop?.nameEnglish ?? '',
        variants: _selectedVariants,
        harvestDate: _harvestDate!,
        quantity: double.tryParse(_quantityController.text) ?? 0,
        unit: _selectedUnit,
        farmerId: 'farmer-001',
        targetMarket: targetMarket,
      );

      setState(() => _isSubmitting = true);

      // 3. Call the external repository
      final success = await PledgeRepository().createPledge(pledge);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        DuruhaSnackBar.showSuccess(context, 'Pledge Created!');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/farmer/farm', (route) => false);
      } else {
        DuruhaSnackBar.showError(
          context,
          'Failed to create pledge. Try again.',
        );
      }
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SECTION 1: CROP SELECTION
              DuruhaSectionContainer(
                title: "What are you planting?",
                children: [
                  _isLoadingCrops
                      ? const Center(child: CircularProgressIndicator())
                      : DuruhaDropdown<Produce>(
                          value: _selectedCrop,
                          label: "Choose crop",
                          prefixIcon: Icons.agriculture,
                          items: _availableCrops,
                          labelBuilder: (crop) {
                            final dialect = _farmerDialect;
                            final displayName =
                                crop.namesByDialect[dialect] ??
                                crop.namesByDialect[dialect.toLowerCase()] ??
                                crop.namesByDialect['tagalog'] ??
                                crop.nameEnglish;
                            return "$displayName (${crop.nameEnglish})";
                          },
                          onChanged: (val) {
                            setState(() {
                              _selectedCrop = val;
                              if (val != null) {
                                _selectedVariants.clear();
                              }
                            });
                          },
                          validator: (val) =>
                              val == null ? 'Please select a crop' : null,
                        ),

                  if (_selectedCrop != null) ...[
                    const SizedBox(height: 24),
                    DuruhaSelectionChipGroup(
                      title: "Crop Variants",
                      subtitle: "Which varieties are you planting?",
                      options: _selectedCrop!.availableVarieties,
                      selectedValues: _selectedVariants,
                      onToggle: _toggleVariant,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // SECTION 2: PLEDGE DETAILS
              DuruhaSectionContainer(
                title: "Harvest Details",
                children: [
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: DuruhaTextField(
                        label: "Delivery Date",
                        icon: Icons.calendar_today,
                        controller: _dateController,
                        validator: (v) =>
                            _harvestDate == null ? 'Date is required' : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Simulated Demand Display
                  if (_isLoadingDemand)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    _buildDemandForecastBox(context),

                  if (_simulatedDemand != null &&
                      ((_simulatedDemand!['local_fulfilled_kg'] as num) >=
                          (_simulatedDemand!['local_demand_kg'] as num)))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.public,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Local demand full. You will be supplying the National Market.",
                                style: TextStyle(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            final qty = double.tryParse(val);
                            if (qty == null) return 'Invalid';

                            if (_simulatedDemand != null) {
                              final double lDemand =
                                  (_simulatedDemand!['local_demand_kg'] as num)
                                      .toDouble();
                              final double lFulfilled =
                                  (_simulatedDemand!['local_fulfilled_kg']
                                          as num)
                                      .toDouble();

                              // Auto-switch logic: If local is strictly full, supply national
                              final bool isLocalFull = lFulfilled >= lDemand;

                              if (!isLocalFull) {
                                // Local Supply Logic
                                const double minLocalPledge = 20.0;
                                if (qty < minLocalPledge) {
                                  return 'Min: ${minLocalPledge.toStringAsFixed(0)} kg';
                                }

                                final double lRemaining = (lDemand - lFulfilled)
                                    .clamp(0.0, double.infinity);

                                if (qty > lRemaining) {
                                  return 'Max: ${lRemaining.toStringAsFixed(0)} kg';
                                }
                              } else {
                                // National Supply Logic
                                const double minNationalPledge = 50.0;
                                if (qty < minNationalPledge) {
                                  return 'Min: ${minNationalPledge.toStringAsFixed(0)} kg';
                                }
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: DuruhaDropdown<String>(
                          value: _selectedUnit,
                          label: "Unit",
                          prefixIcon: Icons.straighten,
                          items: _units,
                          labelBuilder: (u) => u,
                          onChanged: (v) => setState(() => _selectedUnit = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SECTION 3: PREVIEW (Conditional)
              if (_selectedCrop != null ||
                  _quantityController.text.isNotEmpty ||
                  _harvestDate != null) ...[
                DuruhaSectionContainer(
                  title: "Pledge Preview",
                  backgroundColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                  children: [
                    _buildPreviewRow(
                      "Target Market",
                      (_simulatedDemand != null &&
                              ((_simulatedDemand!['local_fulfilled_kg']
                                      as num) >=
                                  (_simulatedDemand!['local_demand_kg']
                                      as num)))
                          ? "National"
                          : "Local",
                    ),
                    _buildPreviewRow("Crop", _selectedCrop?.nameEnglish ?? "-"),
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
                      "Harvest Date",
                      _harvestDate != null
                          ? DateFormat('MMM d, yyyy').format(_harvestDate!)
                          : "-",
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // SUBMIT BUTTON
              DuruhaButton(
                text: "Confirm Pledge",
                isLoading: _isSubmitting,
                onPressed: _submitPledge,
              ),
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

  Widget _buildDemandForecastBox(BuildContext context) {
    if (_simulatedDemand == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Parse values safely with explicit casting to handle dynamic
    final double lDemand = (_simulatedDemand!['local_demand_kg'] as num)
        .toDouble();
    final double lFulfilled = (_simulatedDemand!['local_fulfilled_kg'] as num)
        .toDouble();
    final double lPrice = (_simulatedDemand!['local_price'] as num).toDouble();

    final double nDemand = (_simulatedDemand!['national_demand_kg'] as num)
        .toDouble();
    final double nFulfilled =
        (_simulatedDemand!['national_fulfilled_kg'] as num).toDouble();
    final double nPrice = (_simulatedDemand!['national_price'] as num)
        .toDouble();

    final double minLocalPledge = 20.0;
    final double minNationalPledge = 50.0;

    // Ratios
    final double lRatio = (lFulfilled / lDemand).clamp(0.0, 1.0);
    final double nRatio = (nFulfilled / nDemand).clamp(0.0, 1.0);

    final bool localFull = lFulfilled >= lDemand;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 18,
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                "Market Forecast for ${DateFormat('MMMM dd, yyyy').format(_harvestDate!)}",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Local Section (Hide fulfilled amount text if full? no, user said 'dont show this if the local demand == fulfilled', referring to something previous? likely the progress bar logic or something. I'll stick to 'no min pledge for local' interpretation)
          _buildProgressBar(
            context,
            "Local Market",
            lFulfilled,
            lDemand,
            lPrice,
            lRatio,
            localFull,
          ),

          if (localFull)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Local demand fully met! Switch to National.",
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // National Section
          _buildProgressBar(
            context,
            "National Market",
            nFulfilled,
            nDemand,
            nPrice,
            nRatio,
            false,
          ),

          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                "Min. Pledge:",
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (localFull)
                Text(
                  "National: ${minNationalPledge.toStringAsFixed(0)}kg",
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                )
              else
                Text(
                  "Local: ${minLocalPledge.toStringAsFixed(0)}kg",
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    String title,
    double current,
    double max,
    double price,
    double ratio,
    bool isFull,
  ) {
    final theme = Theme.of(context);
    final color = isFull
        ? theme.colorScheme.error
        : (ratio > 0.8 ? Colors.orange : Colors.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              "${DuruhaFormatter.formatCurrency(price)} / kg",
              style: TextStyle(
                color: theme.colorScheme.onSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          "${DuruhaFormatter.formatNumber(current.toInt())} / ${DuruhaFormatter.formatNumber(max.toInt())} kg fulfilled",
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
