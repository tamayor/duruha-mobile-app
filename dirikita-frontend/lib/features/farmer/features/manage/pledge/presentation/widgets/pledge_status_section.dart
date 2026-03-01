import 'package:duruha/core/widgets/duruha_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/core/widgets/duruha_selection_chip_group.dart';
import 'pledge_small_components.dart';

class PledgeStatusSection extends StatelessWidget {
  final String currentStatus;
  final List<String> pledgeStatuses;
  final List<Map<String, dynamic>> statusHistory;
  final List<Map<String, dynamic>> dateHistory;
  final Function(String status) onStatusToggle;
  final Function(int index, String status) onDeleteStatusEntry;

  const PledgeStatusSection({
    super.key,
    required this.currentStatus,
    required this.pledgeStatuses,
    required this.statusHistory,
    required this.dateHistory,
    required this.onStatusToggle,
    required this.onDeleteStatusEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DuruhaSectionContainer(
      title: "Current Status",
      children: [
        DuruhaSelectionChipGroup(
          title: DuruhaStatus.toFarmerStatusPresentTense(currentStatus),
          titleSize: 25,
          options: pledgeStatuses,
          selectedValues: [currentStatus],
          onToggle: onStatusToggle,
        ),
        if (statusHistory.isNotEmpty || dateHistory.isNotEmpty) ...[
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
                    ...statusHistory.asMap().entries.map(
                      (e) => {
                        ...e.value,
                        'type': 'status',
                        'originalIndex': e.key,
                      },
                    ),
                    ...dateHistory.map(
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
                          Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: isDate
                                      ? colorScheme.secondary
                                      : getPledgeStatusColor(
                                          item['status'],
                                          colorScheme,
                                        ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isDate
                                                  ? colorScheme.secondary
                                                  : getPledgeStatusColor(
                                                      item['status'],
                                                      colorScheme,
                                                    ))
                                              .withAlpha(100),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              if (activities.indexOf(item) !=
                                  activities.length - 1)
                                Container(
                                  width: 2,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: colorScheme.outlineVariant.withAlpha(
                                      100,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
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
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 16,
                              ),
                              onPressed: () async {
                                final confirmed = await DuruhaDialog.show(
                                  context: context,
                                  title: 'Delete "${item['status']}" status?',
                                  message: 'This action cannot be undone.',
                                  confirmText: 'Delete',
                                  cancelText: 'Cancel',
                                  icon: Icons.delete_forever_rounded,
                                  isDanger: true,
                                );

                                if (confirmed == true) {
                                  onDeleteStatusEntry(
                                    item['originalIndex'],
                                    item['status'],
                                  );
                                }
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
}
