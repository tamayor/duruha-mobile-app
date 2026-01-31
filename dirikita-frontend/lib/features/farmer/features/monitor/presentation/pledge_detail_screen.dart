import 'package:duruha/core/helpers/duruha_monitor_helper.dart';
import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';

import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/features/farmer/features/monitor/data/monitor_repository.dart';
import 'package:duruha/features/farmer/features/monitor/domain/monitor_models.dart';
import 'package:duruha/features/farmer/features/profile/data/profile_repository.dart';

class PledgeDetailScreen extends StatefulWidget {
  final String pledgeId;
  final HarvestPledge? pledge;

  const PledgeDetailScreen({super.key, required this.pledgeId, this.pledge});

  @override
  State<PledgeDetailScreen> createState() => _PledgeDetailScreenState();
}

class _PledgeDetailScreenState extends State<PledgeDetailScreen> {
  final _repository = MonitorRepository();
  final _profileRepo = FarmerProfileRepositoryImpl();
  final _reasonController = TextEditingController();
  final _inputNameController = TextEditingController();
  final _inputCostController = TextEditingController();

  Produce? _produce;
  HarvestPledge? _pledge;
  String _userName = "Farmer";
  bool _isLoading = true;

  DateTime? _selectedNewDate;
  String _selectedReason = '';
  final _rescheduleReasons = MonitorDataHelper.getRescheduleReasons();

  List<Map<String, dynamic>> _dateHistory = [];
  List<Map<String, dynamic>> _inputs = [];

  String _selectedInputCategory = '';
  final _inputCategories = MonitorDataHelper.getInputCategories();

  String _currentStatus = 'Set';
  List<Map<String, dynamic>> _statusHistory = [];
  final _pledgeStatuses = MonitorDataHelper.getPledgeStatuses();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.pledge?.currentStatus ?? 'Set';
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _repository.getStatusHistory(widget.pledgeId),
        _repository.getExpenseHistory(widget.pledgeId),
        _repository.getScheduleHistory(widget.pledgeId),
        _profileRepo.getFarmerProfile('current_user'),
        if (widget.pledge == null)
          _repository.getPledgeById(widget.pledgeId)
        else
          Future.value(widget.pledge),
      ]);

      if (!mounted) return;

      final statusHist = results[3] as List<PledgeStatusHistory>;
      final expenseHist = results[4] as List<PledgeExpense>;
      final scheduleHist = results[5] as List<PledgeScheduleHistory>;
      final profile = results[6] as dynamic;
      final pledge = results[7] as HarvestPledge?;

      setState(() {
        _statusHistory = statusHist.map((h) => h.toMap()).toList();
        _inputs = expenseHist.map((e) => e.toMap()).toList();
        _dateHistory = scheduleHist.map((s) => s.toMap()).toList();
        _userName = profile.name.split(' ').first;
        _pledge = pledge;
        _isLoading = false;
      });

      if (_pledge != null) {
        _fetchProduceData();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProduceData() async {
    if (_pledge == null) return;
    try {
      final allProduce = await ProduceRepository().getAllProduce();
      final produce = allProduce.firstWhere((p) => p.id == _pledge!.cropId);
      if (mounted) {
        setState(() {
          _produce = produce;
        });
      }
    } catch (e) {
      // Error handling
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Adjust Harvest Schedule",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DuruhaSectionContainer(
                            title: "New Schedule",
                            backgroundColor: theme.colorScheme.primaryContainer
                                .withAlpha(20),
                            children: [
                              _buildRow(
                                "Original Date",
                                DateFormat(
                                  'MMMM d, yyyy',
                                ).format(_pledge!.harvestDate),
                                icon: Icons.event,
                              ),
                              _buildRow(
                                "Proposed Date",
                                DateFormat(
                                  'MMMM d, yyyy',
                                ).format(_selectedNewDate!),
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
                            onChanged: (v) =>
                                setDialogState(() => _selectedReason = v!),
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
                                    color: theme.colorScheme.outlineVariant
                                        .withAlpha(50),
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "${DateFormat('MMM d').format(item['oldDate'])} → ${DateFormat('MMM d').format(item['newDate'])}",
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'MM/dd',
                                          ).format(item['timestamp']),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.outline,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${item['reason']}${item['notes'].isNotEmpty ? ' - ${item['notes']}' : ''}",
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: DuruhaButton(
                      text: "Confirm New Date",
                      onPressed: () {
                        setState(() {
                          _dateHistory.insert(0, {
                            'oldDate': _pledge!.harvestDate,
                            'newDate': _selectedNewDate,
                            'reason': _selectedReason,
                            'notes': _reasonController.text,
                            'timestamp': DateTime.now(),
                          });
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInputsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final formKey = GlobalKey<FormState>();
            double totalInputs = _inputs.fold(
              0,
              (sum, item) => sum + item['cost'],
            );

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payments, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Farming Expenses",
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Total: ${DuruhaFormatter.formatCurrency(totalInputs)}",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Form(
                            key: formKey,
                            child: DuruhaSectionContainer(
                              title: "Add New Entry",
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
                                  onChanged: (v) => setModalState(
                                    () => _selectedInputCategory = v!,
                                  ),
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
                                    if (value == null || value.isEmpty) {
                                      return null;
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Please enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                DuruhaButton(
                                  text: "Add Expense",
                                  onPressed: () {
                                    if (formKey.currentState!.validate()) {
                                      setState(() {
                                        _inputs.insert(0, {
                                          'name': _inputNameController.text,
                                          'category': _selectedInputCategory,
                                          'cost': double.parse(
                                            _inputCostController.text,
                                          ),
                                        });
                                        _inputNameController.clear();
                                        _inputCostController.clear();
                                      });
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
                                    color: theme.colorScheme.outlineVariant
                                        .withAlpha(50),
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Icon(
                                        _getCategoryIcon(input['category']),
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            input['name'],
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            input['category'],
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.outline,
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
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_pledge == null) {
      return const Scaffold(body: Center(child: Text("Pledge not found")));
    }
    return Scaffold(
      appBar: AppBar(title: Text(_pledge?.id ?? "Pledge Details")),
      bottomNavigationBar: FarmerNavigation(
        name: _userName,
        currentRoute: '/farmer/biz',
      ),
      body: _buildDetailsTab(),
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
            action: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushNamed(
                  context,
                  '/farmer/biz/crops/${pledge.cropId}',
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "View Full Insights",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            children: [
              if (pledge.cropNameDialect != null)
                _buildRow(
                  "Local Name",
                  pledge.cropNameDialect!,
                  icon: Icons.language,
                ),
              _buildRow(
                "Crop Varieties",
                pledge.variants.join(", "),
                icon: Icons.eco_outlined,
              ),
              _buildRow(
                "Market Strategy",
                pledge.targetMarket,
                icon: Icons.storefront_outlined,
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
}
