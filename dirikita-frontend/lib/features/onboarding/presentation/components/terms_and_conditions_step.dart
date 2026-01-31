import 'package:duruha/core/terms-and-conditions/terms_content.dart';
import 'package:flutter/material.dart';
// Actually, to be safe and avoid adding deps without permission, I'll use Text with simple formatting or styling.
// But wait, the user instructions "Add New Project Creation... npx" implies I should be careful with deps.
// Markdown is standard in Flutter? No, 'flutter_markdown' is external.
// I'll stick to RichText or just plain Text for now to avoid dependency issues unless I see it in pubspec.yaml.
// I can view pubspec.yaml to check. But to save steps, I will just use standard Flutter Text widgets.

class TermsAndConditionsStep extends StatefulWidget {
  final bool isAgreed;
  final ValueChanged<bool> onAgreedChanged;

  const TermsAndConditionsStep({
    super.key,
    required this.isAgreed,
    required this.onAgreedChanged,
  });

  @override
  State<TermsAndConditionsStep> createState() => _TermsAndConditionsStepState();
}

class _TermsAndConditionsStepState extends State<TermsAndConditionsStep> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_hasScrolledToBottom) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      setState(() {
        _hasScrolledToBottom = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Title Area
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Review Our Terms",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Please read the terms and conditions carefully.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Scrollable Content
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Simplified Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.secondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Quick Summary",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            TermsContent.simplified,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      TermsContent.comprehensive,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 80), // Padding for easy scrolling
                  ],
                ),
              ),
            ),
          ),
        ),

        // Checkbox Area
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              if (!_hasScrolledToBottom)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Please scroll to the bottom to agree",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              InkWell(
                onTap: _hasScrolledToBottom
                    ? () => widget.onAgreedChanged(!widget.isAgreed)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: widget.isAgreed
                          ? colorScheme.primary
                          : colorScheme.outline,
                      width: widget.isAgreed ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: widget.isAgreed
                        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: widget.isAgreed,
                        onChanged: _hasScrolledToBottom
                            ? (v) => widget.onAgreedChanged(v ?? false)
                            : null,
                        activeColor: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "I have read and agree to the Terms and Conditions",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _hasScrolledToBottom
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 90), // Space for the main FAB/Button
            ],
          ),
        ),
      ],
    );
  }
}
