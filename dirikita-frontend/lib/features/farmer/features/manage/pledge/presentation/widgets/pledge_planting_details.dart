import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/core/widgets/duruha_inkwell.dart';
import 'pledge_small_components.dart';

class PledgePlantingDetails extends StatelessWidget {
  final HarvestPledge pledge;

  const PledgePlantingDetails({super.key, required this.pledge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaSectionContainer(
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
                '/farmer/biz/crops/',
                arguments: pledge.cropId,
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
                        PledgeVariantChips(variants: pledge.variants),
                        const SizedBox(height: 4),
                        PledgeSimpleRow(
                          label: "Market: ",
                          value: pledge.targetMarket.toUpperCase(),
                          icon: Icons.storefront_outlined,
                        ),
                      ],
                    ),
                  ),
                  if (pledge.imageUrl.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withAlpha(
                            100,
                          ),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          pledge.imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 72,
                              height: 72,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
