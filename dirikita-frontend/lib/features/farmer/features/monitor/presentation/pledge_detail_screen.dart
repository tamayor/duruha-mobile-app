import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/widgets/duruha_modal_bottom_sheet.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

class PledgeDetailScreen extends StatefulWidget {
  final String pledgeId;
  final HarvestPledge? pledge;

  const PledgeDetailScreen({super.key, required this.pledgeId, this.pledge});

  @override
  State<PledgeDetailScreen> createState() => _PledgeDetailScreenState();
}

class _PledgeDetailScreenState extends State<PledgeDetailScreen> {
  final _reasonController = TextEditingController();
  final _inputNameController = TextEditingController();
  final _inputCostController = TextEditingController();
  final _repository = PledgeRepository();
  bool _isLoading = true;

  HarvestPledge? _pledge;
  Produce? _produce;

  DateTime? _selectedNewDate;
  String _selectedReason = 'Weather Conditions';
  final List<String> _rescheduleReasons = [
    'Weather Conditions',
    'Pest/Disease Issue',
    'Delayed Maturity',
    'Logistics Issue',
    'Personal/Labor Shortage',
  ];

  final List<Map<String, dynamic>> _dateHistory = [];
  final List<Map<String, dynamic>> _inputs = [];

  String _selectedInputCategory = 'Fertilizer';
  final List<String> _inputCategories = [
    'Seeds',
    'Fertilizer',
    'Pesticide/Chem',
    'Labor',
    'Equipment/Tools',
    'Fuel',
    'Water/Irrigation',
    'Others',
  ];

  String _currentStatus = 'Set';
  final List<Map<String, dynamic>> _statusHistory = [];
  final List<String> _pledgeStatuses = [
    'Set',
    'Cultivate',
    'Plant',
    'Grow',
    'Harvest',
    'Process',
    'Ready to Sell',
    'Sold',
  ];

  @override
  void initState() {
    super.initState();
    _loadPledgeData();
    // Initialize history with creation
    _statusHistory.add({
      'status': 'Set',
      'timestamp': DateTime.now().subtract(const Duration(days: 2)),
    });
  }

  Future<void> _loadPledgeData() async {
    try {
      // 1. Get the pledge object (either from widget or fetch from repository)
      HarvestPledge pledge;
      if (widget.pledge != null) {
        pledge = widget.pledge!;
      } else {
        // Fetch pledge from repository using pledgeId
        final allPledges = await _repository.fetchMyPledges();
        pledge = allPledges.firstWhere(
          (p) => p.id?.toLowerCase() == widget.pledgeId.toLowerCase(),
          orElse: () => throw Exception('Pledge not found'),
        );
      }

      // 2. Fetch the produce metadata
      final allProduce = await ProduceRepository().getAllProduce();
      final produce = allProduce.firstWhere(
        (p) => p.id == pledge.cropId,
        orElse: () => throw Exception('Produce not found'),
      );

      if (mounted) {
        setState(() {
          _pledge = pledge;
          _produce = produce;
          _currentStatus = pledge.currentStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading pledge: $e')));
      }
    }
  }

  // --- LOGIC: DATE ADJUSTMENT ---
  void _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pledge!.harvestDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedNewDate = picked);
      _showRescheduleDialog();
    }
  }

  void _showRescheduleDialog() {
    DuruhaModalBottomSheet.show(
      context: context,
      title: "Adjust\nHarvest Schedule",
      icon: Icons.calendar_month,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DuruhaSectionContainer(
                title: "New Schedule",
                backgroundColor: theme.colorScheme.primaryContainer.withAlpha(
                  20,
                ),
                children: [
                  _buildRow(
                    "Original Date",
                    DateFormat('MMMM d, yyyy').format(_pledge!.harvestDate),
                    icon: Icons.event,
                  ),
                  _buildRow(
                    "Proposed Date",
                    DateFormat('MMMM d, yyyy').format(_selectedNewDate!),
                    icon: Icons.event_available,
                    isBold: true,
                    color: theme.colorScheme.onPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DuruhaDropdown<String>(
                value: _selectedReason,
                label: "Reason for Rescheduling",
                prefixIcon: Icons.help_outline,
                items: _rescheduleReasons,
                onChanged: (v) => setDialogState(() => _selectedReason = v!),
              ),
              const SizedBox(height: 16),
              DuruhaTextField(
                label: "Notes",
                icon: Icons.edit_note,
                controller: _reasonController,
                maxLines: 3,
                isRequired: false,
              ),
              const SizedBox(height: 24),
              if (_dateHistory.isNotEmpty) ...[
                Text(
                  "Schedule History",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.outline,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ..._dateHistory.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(50),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${DateFormat('MMM d').format(item['oldDate'])} → ${DateFormat('MMM d').format(item['newDate'])}",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              DateFormat('MM/dd').format(item['timestamp']),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${item['reason']}${item['notes'].isNotEmpty ? ' - ${item['notes']}' : ''}",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              DuruhaButton(
                text: "Confirm New Date",
                onPressed: () {
                  final newDate = _selectedNewDate!;
                  final reason = _selectedReason;
                  final notes = _reasonController.text;

                  setState(() {
                    _dateHistory.insert(0, {
                      'oldDate': _pledge!.harvestDate,
                      'newDate': newDate,
                      'reason': reason,
                      'notes': notes,
                      'timestamp': DateTime.now(),
                    });
                  });
                  _repository.updatePledgeStatus(
                    widget.pledgeId,
                    "Rescheduled: ${DateFormat('MMM d').format(newDate)}",
                    notes: "$reason - $notes",
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInputsModal({Map<String, dynamic>? expense}) {
    if (expense != null) {
      _inputNameController.text = expense['name'];
      _inputCostController.text = expense['cost'].toStringAsFixed(0);
      _selectedInputCategory = expense['category'];
    } else {
      _inputNameController.clear();
      _inputCostController.clear();
      _selectedInputCategory = _inputCategories.first;
    }

    DuruhaModalBottomSheet.show(
      context: context,
      title: "Farming Expenses",
      icon: Icons.payments,
      subtitle:
          "Total: ${DuruhaFormatter.formatCurrency(_inputs.fold<double>(0, (sum, item) => sum + item['cost']))}",
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final formKey = GlobalKey<FormState>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Form(
                key: formKey,
                child: DuruhaSectionContainer(
                  title: expense != null ? "Edit Expense" : "Add New Entry",
                  children: [
                    DuruhaTextField(
                      label: "Item Name",
                      icon: Icons.inventory_2_outlined,
                      controller: _inputNameController,
                      isRequired: true,
                    ),
                    DuruhaDropdown<String>(
                      value: _selectedInputCategory,
                      label: "Category",
                      prefixIcon: Icons.category_outlined,
                      items: _inputCategories,
                      onChanged: (v) =>
                          setModalState(() => _selectedInputCategory = v!),
                    ),
                    const SizedBox(height: 16),
                    DuruhaTextField(
                      label: "Amount",
                      icon: Icons.payments_outlined,
                      controller: _inputCostController,
                      keyboardType: TextInputType.number,
                      suffix: "₱",
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    DuruhaButton(
                      text: expense != null ? "Update Expense" : "Add Expense",
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final newExpense = {
                            'id':
                                expense?['id'] ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            'name': _inputNameController.text,
                            'category': _selectedInputCategory,
                            'cost': double.parse(_inputCostController.text),
                          };
                          setState(() {
                            if (expense != null) {
                              final index = _inputs.indexOf(expense);
                              if (index != -1) _inputs[index] = newExpense;
                            } else {
                              _inputs.insert(0, newExpense);
                            }
                            _inputNameController.clear();
                            _inputCostController.clear();
                          });
                          if (expense != null) {
                            _repository.updateExpense(
                              widget.pledgeId,
                              newExpense,
                            );
                          } else {
                            _repository.addExpense(widget.pledgeId, newExpense);
                          }
                          setModalState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_inputs.isNotEmpty) ...[
                Text(
                  "Expense History",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ..._inputs.map(
                  (input) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(50),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            _getCategoryIcon(input['category']),
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                input['name'],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                input['category'],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          DuruhaFormatter.formatCurrency(
                            input['cost'].toDouble(),
                            decimalDigits: 0,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                            size: 20,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showInputsModal(expense: input);
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _inputs.remove(input));
                            _repository.deleteExpense(
                              widget.pledgeId,
                              input['id'] ?? 'unknown',
                            );
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pledge?.id ?? "Pledge Details")),
      bottomNavigationBar: const FarmerNavigation(
        name: "Elly",
        currentRoute: '/',
      ),
      body: _isLoading ? const FarmerLoadingScreen() : _buildDetailsTab(),
    );
  }

  Widget _buildDetailsTab() {
    final pledge = _pledge!;
    double totalInputs = _inputs.fold(0, (sum, item) => sum + item['cost']);
    final theme = Theme.of(context);

    // Calculate days remaining
    final harvestDate = _dateHistory.isEmpty
        ? pledge.harvestDate
        : _dateHistory.first['newDate'] as DateTime;
    final daysRemaining = harvestDate.difference(DateTime.now()).inDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Crop Image Header - REMOVED per request
          /*
          if (pledge.imageUrl.isNotEmpty)
             ...
          */

          // Header Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(40),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  daysRemaining >= 0
                      ? "$daysRemaining Days Until Harvest"
                      : "Harvest Ready",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withAlpha(200),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      context,
                      "Min. Quantity",
                      "${pledge.quantity.toStringAsFixed(0)} ${pledge.unit}",
                      Icons.shopping_basket_outlined,
                    ),
                    _buildStat(
                      context,
                      "Invested",
                      DuruhaFormatter.formatCurrency(
                        totalInputs,
                        decimalDigits: 0,
                      ),
                      Icons.payments_outlined,
                    ),
                  ],
                ),
                if (_produce != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
                  Column(
                    children: [
                      Text(
                        "Potential Earnings",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary.withAlpha(150),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DuruhaFormatter.formatCurrency(
                          (_produce!.currentFairMarketGuideline *
                                  pledge.quantity) -
                              totalInputs,
                        ),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                      Text(
                        "Based on ${DuruhaFormatter.formatCurrency(_produce!.currentFairMarketGuideline, decimalDigits: 0)}/kg market price",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimary.withAlpha(180),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          DuruhaButton(
            text: "Record Farming Expenses",
            isOutline: true,
            onPressed: _showInputsModal,
          ),
          const SizedBox(height: 24),
          _buildStatusSection(),
          const SizedBox(height: 24),
          DuruhaSectionContainer(
            title: "Planting Details",
            padding: EdgeInsets.zero,
            children: [
              Material(
                color: Colors.transparent,
                child: DuruhaInkwell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pushNamed(
                      context,
                      '/farmer/crops/${pledge.cropId}',
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pledge.cropNameDialect ?? pledge.cropName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildVariantsRow(pledge.variants, theme),
                              const SizedBox(height: 4),
                              _buildSimpleRow(
                                "Market: ",
                                pledge.targetMarket.toUpperCase(),
                                Icons.storefront_outlined,
                                theme,
                              ),
                            ],
                          ),
                        ),
                        if (pledge.imageUrl.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              pledge.imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(
                            100,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DuruhaSectionContainer(
            title: "Expected Harvest",
            action: TextButton.icon(
              onPressed: _showDatePicker,
              icon: Icon(
                Icons.edit_calendar_rounded,
                size: 18,
                color: theme.colorScheme.onPrimary,
              ),
              label: Text(
                "Change",
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            children: [
              Text(
                DateFormat('MMMM d, yyyy').format(harvestDate),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.onPrimary.withAlpha(200), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary.withAlpha(150),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Seeds':
        return Icons.grass;
      case 'Fertilizer':
        return Icons.science_outlined;
      case 'Pesticide/Chem':
        return Icons.bug_report_outlined;
      case 'Labor':
        return Icons.engineering_outlined;
      case 'Equipment/Tools':
        return Icons.handyman_outlined;
      case 'Fuel':
        return Icons.local_gas_station_outlined;
      case 'Water/Irrigation':
        return Icons.water_drop_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    IconData? icon,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary.withAlpha(150),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(130),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DuruhaSectionContainer(
      title: "Current Status",
      children: [
        DuruhaSelectionChipGroup(
          title: DuruhaStatus.toPresentTense(_currentStatus),
          titleSize: 25,
          options: _pledgeStatuses,
          selectedValues: [_currentStatus],
          onToggle: (status) {
            final currentIndex = _pledgeStatuses.indexOf(_currentStatus);
            final targetIndex = _pledgeStatuses.indexOf(status);

            if (targetIndex > currentIndex) {
              setState(() {
                _currentStatus = status;
                _statusHistory.insert(0, {
                  'status': status,
                  'timestamp': DateTime.now(),
                });
              });
              HapticFeedback.mediumImpact();
              // API Call
              _repository.updatePledgeStatus(widget.pledgeId, status);
            } else if (targetIndex < currentIndex) {
              DuruhaSnackBar.showWarning(
                context,
                "Cannot go back to previous stage. Delete latest update in activity log to revert.",
                title: "Invalid Action",
              );
            }
          },
        ),
        if (_statusHistory.isNotEmpty || _dateHistory.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Activity Log",
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...() {
                  final List<Map<String, dynamic>> activities = [
                    ..._statusHistory.asMap().entries.map(
                      (e) => {
                        ...e.value,
                        'type': 'status',
                        'originalIndex': e.key,
                      },
                    ),
                    ..._dateHistory.map(
                      (d) => {
                        'status':
                            'Date Adjusted: ${DateFormat('MMM d').format(d['newDate'])}',
                        'timestamp': d['timestamp'],
                        'type': 'date',
                      },
                    ),
                  ];
                  activities.sort(
                    (a, b) => (b['timestamp'] as DateTime).compareTo(
                      a['timestamp'] as DateTime,
                    ),
                  );

                  return activities.map((item) {
                    final bool isDate = item['type'] == 'date';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6, right: 12),
                            decoration: BoxDecoration(
                              color: isDate
                                  ? colorScheme.secondary
                                  : _getStatusColor(
                                      item['status'],
                                      colorScheme,
                                    ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item['status'],
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (isDate) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer
                                              .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          "SCHEDULE",
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme
                                                .onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy • h:mm a',
                                  ).format(item['timestamp']),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isDate && item['status'] != 'Set')
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () {
                                setState(() {
                                  _statusHistory.removeAt(
                                    item['originalIndex'],
                                  );
                                  _currentStatus =
                                      _statusHistory.first['status'];
                                });
                                HapticFeedback.selectionClick();
                                // API Call
                                _repository.deleteStatusEntry(
                                  widget.pledgeId,
                                  'status_entry_${item['originalIndex']}', // Mock ID
                                );
                              },
                              color: colorScheme.error.withAlpha(150),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'Set':
        return Colors.blue;
      case 'Cultivate':
        return Colors.brown;
      case 'Plant':
        return Colors.green;
      case 'Grow':
        return Colors.lightGreen;
      case 'Harvest':
        return Colors.orange;
      case 'Process':
        return Colors.deepOrange;
      case 'Ready to Sell':
        return Colors.teal;
      case 'Sold':
        return Colors.purple;
      default:
        return colorScheme.primary;
    }
  }

  Widget _buildSimpleRow(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsRow(List<String> variants, ThemeData theme) {
    if (variants.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.eco_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Varieties:",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: variants.map((variant) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Text(
                        variant,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
