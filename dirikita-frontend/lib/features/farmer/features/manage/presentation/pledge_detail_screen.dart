import 'package:duruha/features/farmer/features/manage/data/manage_pledge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/loading_screen.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

// Modular widgets
import 'package:duruha/features/farmer/features/manage/presentation/widgets/pledge_harvest_schedule.dart';
import 'package:duruha/features/farmer/features/manage/presentation/widgets/pledge_header_summary.dart';
import 'package:duruha/features/farmer/features/manage/presentation/widgets/pledge_planting_details.dart';
import 'package:duruha/features/farmer/features/manage/presentation/widgets/pledge_status_section.dart';

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
  final _repository = ManagePledgeRepository();
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
    'Done',
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
      HarvestPledge pledge;
      if (widget.pledge != null) {
        pledge = widget.pledge!;
      } else {
        pledge = await _repository.getPledgeById(widget.pledgeId);
      }

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
          if (pledge.perDatePledges != null) {
            // Already handled by the model
          }
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
      _inputCostController.text = expense['cost'].toString();
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                            color: theme.colorScheme.onSecondary,
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
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          DuruhaFormatter.formatCurrency(
                            input['cost'].toDouble(),
                            decimalDigits: 2,
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
                          onPressed: () async {
                            final confirmed = await DuruhaConfirmationModal.show(
                              context: context,
                              title: 'Delete Expense?',
                              message:
                                  'Are you sure you want to delete "${input['name']}"? This action cannot be undone.',
                              confirmText: 'Delete',
                              cancelText: 'Cancel',
                              icon: Icons.delete_forever_rounded,
                              isDanger: true,
                            );

                            if (confirmed == true) {
                              setState(() => _inputs.remove(input));
                              _repository.deleteExpense(
                                widget.pledgeId,
                                input['id'] ?? 'unknown',
                              );
                              setModalState(() {});
                            }
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
    return DuruhaScaffold(
      appBarTitle: _pledge?.id ?? "Pledge Details",
      bottomNavigationBar: const FarmerNavigation(
        name: "Elly",
        currentRoute: '/',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildDetailsContent(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDetailsContent() {
    final pledge = _pledge!;
    double totalInputs = pledge.totalExpenses;

    // Calculate days remaining (using the earliest date if multiple exist)
    DateTime harvestDate;
    final entries = pledge.perDatePledges ?? [];
    if (entries.isNotEmpty) {
      final dates = entries.map((e) => e.date).toSet().toList()..sort();
      harvestDate = dates.first;
    } else {
      harvestDate = _dateHistory.isEmpty
          ? pledge.harvestDate
          : _dateHistory.first['newDate'] as DateTime;
    }
    final daysRemaining = harvestDate.difference(DateTime.now()).inDays;

    return Column(
      children: [
        PledgeHeaderSummary(
          daysRemaining: daysRemaining,
          pledge: pledge,
          totalInputs: totalInputs,
          currentStatus: _currentStatus,
          produce: _produce,
          onRecordExpenses: _showInputsModal,
        ),
        const SizedBox(height: 24),
        PledgeStatusSection(
          currentStatus: _currentStatus,
          pledgeStatuses: _pledgeStatuses,
          statusHistory: _statusHistory,
          dateHistory: _dateHistory,
          onStatusToggle: (status) {
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
              _repository.updatePledgeStatus(widget.pledgeId, status);
            } else if (targetIndex < currentIndex) {
              DuruhaSnackBar.showWarning(
                context,
                "Cannot go back to previous stage. Delete latest update in activity log to revert.",
                title: "Invalid Action",
              );
            }
          },
          onDeleteStatusEntry: (index, status) {
            setState(() {
              _statusHistory.removeAt(index);
              _currentStatus = _statusHistory.first['status'];
            });
            HapticFeedback.selectionClick();
            _repository.deleteStatusEntry(
              widget.pledgeId,
              'status_entry_$index',
            );
          },
        ),
        const SizedBox(height: 16),
        PledgeHarvestSchedule(
          pledge: pledge,
          harvestDate: harvestDate,
          currentStatus: _currentStatus,
          onToggleHarvest: (entry, newStatus) async {
            if (_currentStatus != 'Harvest') {
              DuruhaSnackBar.showWarning(
                context,
                'Marking dates as complete is only allowed when status is Harvest.',
              );
              return;
            }

            HapticFeedback.mediumImpact();

            setState(() {
              // Find the specific entry in our local pledge object and update it
              final index = _pledge!.perDatePledges!.indexWhere(
                (e) =>
                    e.variety == entry.variety &&
                    e.quantity == entry.quantity &&
                    e.date == entry.date,
              );

              if (index != -1) {
                final updatedEntry = HarvestEntry(
                  date: entry.date,
                  variety: entry.variety,
                  quantity: entry.quantity,
                  earnings: entry.earnings,
                  isCompleted: newStatus,
                );
                _pledge!.perDatePledges![index] = updatedEntry;
              }
            });

            await _repository.toggleHarvestDateStatus(
              widget.pledgeId,
              entry.date,
              newStatus,
            );
          },
          onShowDatePicker: _showDatePicker,
        ),

        const SizedBox(height: 24),
        PledgePlantingDetails(pledge: pledge),
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
}
