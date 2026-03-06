import 'package:duruha/core/widgets/duruha_bottom_sheet.dart';
import 'package:flutter/material.dart';

class FaqSection {
  final String title;
  final String content;

  const FaqSection({required this.title, required this.content});
}

class FaqGroup {
  final String? title;
  final List<FaqSection> sections;

  const FaqGroup({this.title, required this.sections});
}

class FaqContent {
  final String title;
  final List<FaqGroup> groups;
  final Widget? additionalContent;

  const FaqContent({
    required this.title,
    required this.groups,
    this.additionalContent,
  });
}

class DuruhaFaqModal extends StatelessWidget {
  final FaqContent faqData;

  const DuruhaFaqModal({super.key, required this.faqData});

  static void show(BuildContext context, FaqContent data) {
    DuruhaBottomSheet.show(
      context: context,
      title: data.title,
      icon: Icons.help_outline,
      isScrollable: true,
      child: DuruhaFaqModal(faqData: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...faqData.groups.asMap().entries.map((entry) {
          final index = entry.key;
          final group = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
              ],
              if (group.title != null) ...[
                _buildSectionTitle(theme, group.title!, isSubtitle: true),
                const SizedBox(height: 12),
              ],
              ...group.sections.expand(
                (section) => [
                  _buildSectionTitle(theme, section.title),
                  _buildText(theme, section.content),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          );
        }),
        if (faqData.additionalContent != null) ...[
          const SizedBox(height: 12),
          faqData.additionalContent!,
        ],
      ],
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    String title, {
    bool isSubtitle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: isSubtitle
            ? theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondary,
              )
            : theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
      ),
    );
  }

  Widget _buildText(ThemeData theme, String text) {
    return Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5));
  }
}
