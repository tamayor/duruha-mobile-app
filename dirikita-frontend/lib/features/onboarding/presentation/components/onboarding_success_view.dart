import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class OnboardingSuccessView extends StatelessWidget {
  final String? generatedId; // Kept only to trigger the loading state
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
    final isFarmer = userRole.toLowerCase() == 'farmer';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. LOADING STATE
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
                "Finalizing Profile...",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ] else ...[
              // 2. WELCOME CARD (Success State)
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    // --- Card Header ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.onPrimary,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "You're All Set!",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Card Body ---
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            "Welcome, $firstName",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFarmer
                                      ? Icons.agriculture
                                      : Icons.shopping_basket,
                                  size: 16,
                                  color: colorScheme.secondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "$userRole Account",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          Text(
                            isFarmer
                                ? "Your digital farm is ready!"
                                : "Your market is ready!",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 3. ENTER DASHBOARD BUTTON
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
