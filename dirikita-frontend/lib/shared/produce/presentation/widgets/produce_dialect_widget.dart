import 'package:duruha/core/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_dialect.dart';
import 'package:duruha/shared/user/data/dialect_repository.dart';

class ProduceDialectWidget extends StatefulWidget {
  final String produceId;
  final List<ProduceDialect> dialects;

  const ProduceDialectWidget({
    super.key,
    required this.produceId,
    required this.dialects,
  });

  @override
  State<ProduceDialectWidget> createState() => _ProduceDialectWidgetState();
}

class _ProduceDialectWidgetState extends State<ProduceDialectWidget> {
  final _repository = ProduceRepository();
  Key _refreshKey = UniqueKey();
  late List<ProduceDialect> _localDialects;

  @override
  void initState() {
    super.initState();
    _localDialects = List.from(widget.dialects);
  }

  @override
  void didUpdateWidget(ProduceDialectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dialects != oldWidget.dialects) {
      _localDialects = List.from(widget.dialects);
    }
  }

  void _refresh() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String dialectName,
    String currentLocalName, {
    VoidCallback? onSaveSuccess,
  }) async {
    final controller = TextEditingController(
      text: currentLocalName == "-" ? "" : currentLocalName,
    );
    bool isSaving = false;
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 100,
                vertical: 100,
              ),
              title: Text("Edit $dialectName Name"),
              content: DuruhaTextField(
                controller: controller,
                label: 'Local Name',
                icon: Icons.edit,
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: theme.colorScheme.onError),
                  ),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = controller.text.trim();
                          if (newName.isEmpty) return;

                          setDialogState(() => isSaving = true);
                          try {
                            await _repository.updateProduceLocalName(
                              widget.produceId,
                              dialectName,
                              newName,
                            );
                            if (context.mounted) {
                              // Update local state for immediate UI feedback
                              setState(() {
                                final index = _localDialects.indexWhere(
                                  (d) =>
                                      d.dialectName.toLowerCase() ==
                                      dialectName.toLowerCase(),
                                );
                                if (index != -1) {
                                  _localDialects[index] = ProduceDialect(
                                    dialectName: dialectName,
                                    localName: newName,
                                  );
                                } else {
                                  _localDialects.add(
                                    ProduceDialect(
                                      dialectName: dialectName,
                                      localName: newName,
                                    ),
                                  );
                                }
                              });

                              onSaveSuccess?.call();
                              Navigator.pop(context);
                              DuruhaSnackBar.showSuccess(
                                context,
                                "Updated $dialectName name to $newName",
                              );
                              _refresh();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                              DuruhaSnackBar.showError(
                                context,
                                "Failed to update: $e",
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          "Save",
                          style: TextStyle(color: theme.colorScheme.onPrimary),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_localDialects.isEmpty && widget.dialects.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return FutureBuilder<List<String>>(
      key: _refreshKey,
      future: SessionService.getUserDialects(),
      builder: (context, userDialectSnapshot) {
        // Sort dialects based on user preference
        List<ProduceDialect> sortedDialects;
        final userPref = userDialectSnapshot.data ?? [];
        final prefs = userPref.map((e) => e.toLowerCase()).toSet();

        if (prefs.isEmpty) {
          sortedDialects = List.from(_localDialects);
        } else {
          final preferred = _localDialects
              .where((d) => prefs.contains(d.dialectName.toLowerCase()))
              .toList();
          final rest = _localDialects
              .where((d) => !prefs.contains(d.dialectName.toLowerCase()))
              .toList();
          sortedDialects = [...preferred, ...rest];
        }

        return GestureDetector(
          onTap: () {
            DuruhaModalBottomSheet.show(
              context: context,
              title: "Local Names",
              icon: Icons.language,
              child: StatefulBuilder(
                builder: (context, setBottomSheetState) {
                  return FutureBuilder<List<String>>(
                    future: fetchAllDialectNames(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator.adaptive(),
                        );
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text("Failed to load dialects"),
                        );
                      }

                      // Simplify sorting for all dialects
                      final allFromRepo = snapshot.data!;
                      final preferredAll = allFromRepo
                          .where((d) => prefs.contains(d.toLowerCase()))
                          .toList();
                      final restAll = allFromRepo
                          .where((d) => !prefs.contains(d.toLowerCase()))
                          .toList();
                      final allDialects = [...preferredAll, ...restAll];

                      // Helper to check if produce has a dialect
                      String getLocalName(String dialect) {
                        try {
                          final match = _localDialects.firstWhere(
                            (d) =>
                                d.dialectName.toLowerCase() ==
                                dialect.toLowerCase(),
                          );
                          return match.localName;
                        } catch (e) {
                          return "-";
                        }
                      }

                      return Column(
                        children: [
                          // Table Header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "DIALECT",
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "LOCAL NAME",
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          // Table Rows
                          ...allDialects.map((dialectName) {
                            final localName = getLocalName(dialectName);
                            final isPreferred = prefs.contains(
                              dialectName.toLowerCase(),
                            );

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isPreferred
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.05,
                                      )
                                    : null,
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dialectName,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: isPreferred
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                color: isPreferred
                                                    ? theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                    : theme
                                                          .colorScheme
                                                          .onPrimary,
                                              ),
                                        ),
                                        if (isPreferred)
                                          Text(
                                            "PRIMARY",
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: InkWell(
                                      onTap: () => _showEditDialog(
                                        context,
                                        dialectName,
                                        localName,
                                        onSaveSuccess: () =>
                                            setBottomSheetState(() {}),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                localName,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: isPreferred
                                                          ? theme
                                                                .colorScheme
                                                                .onSecondaryContainer
                                                          : theme
                                                                .colorScheme
                                                                .onPrimary,
                                                      fontStyle:
                                                          localName == "-"
                                                          ? FontStyle.italic
                                                          : null,
                                                    ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 14,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ...sortedDialects.take(3).map((d) {
                final isPref = prefs.contains(d.dialectName.toLowerCase());
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPref
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: isPref
                        ? null
                        : Border.all(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.2),
                          ),
                  ),
                  child: Text(
                    "${d.localName} (${d.dialectName})",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isPref
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
              if (sortedDialects.length > 3)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "+${sortedDialects.length - 3} more",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
