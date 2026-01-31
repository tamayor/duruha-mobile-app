import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class OnboardingSuccessView extends StatelessWidget {
  final String? generatedId;
  final String firstName;
  final String userRole;
  final VoidCallback onEnterDashboard;

  const OnboardingSuccessView({
    super.key,
    required this.generatedId,
    required this.firstName,
    required this.userRole,
    required this.onEnterDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (generatedId == null) ...[
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Creating Profile...",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ] else ...[
              // Success Ticket
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: colorScheme.onPrimary,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Registration Complete",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  "Welcome aboard, $firstName!",
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            "YOUR MEMBER ID",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: colorScheme.onSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outline,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: SelectableText(
                              generatedId!,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: colorScheme.onSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Please save this ID. It will be used for your first login and verification.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: DuruhaButton(
                  onPressed: onEnterDashboard,
                  text: 'ENTER DASHBOARD',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
