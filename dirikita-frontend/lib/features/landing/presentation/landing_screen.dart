import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final args = ModalRoute.of(context)?.settings.arguments;
    Map<String, dynamic>? userArgs;
    if (args is Map<String, dynamic>) {
      userArgs = args;
    } else if (args is Map) {
      userArgs = Map<String, dynamic>.from(args);
    }

    if (userArgs != null) {
      // Redirect to dashboard if role/name is present
      // We use addPostFrameCallback to avoid navigation during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home', arguments: userArgs);
      });
      // Return a loading indicator or empty container while redirecting
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 1. Use a soft background color for an organic feel
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),

                        // --- HERO SECTION ---
                        Center(
                          child: Container(
                            // 2. Add a soft shadow behind the logo
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.asset(
                                'assets/logo.png',
                                height: 50,
                                width: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          'DURUHA',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w900, // Thicker font
                            letterSpacing: 4.0,
                            color: theme
                                .colorScheme
                                .onPrimary, // Use primary green
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'DEMOCRATIZING THE HARVEST',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimary.withValues(
                              alpha: .8,
                            ),
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 60),

                        // --- BEYOND TRADE DIVIDER ---
                        Row(
                          children: [
                            Expanded(child: Divider(color: theme.dividerColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Text(
                                "B E Y O N D   T R A D E",
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: theme.dividerColor)),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // --- MAIN MESSAGE SECTION ---
                        // 3. Highlight this section with a visual cue
                        _buildSectionTitle(context, 'NO LONGER STRANGERS'),
                        const SizedBox(height: 20),
                        Text(
                          "but partners.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Connecting the hands that nurture the soil directly to the hands that nourish the home.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- WEBSITE LINK ---
                        Center(
                          child: InkWell(
                            onTap: () async {
                              final Uri url = Uri.parse('https://duruha.com');
                              if (!await launchUrl(url)) {
                                throw Exception('Could not launch $url');
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.link,
                                    size: 16,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "duruha.com",
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor:
                                          theme.colorScheme.onPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- BOTTOM ACTION BUTTONS ---
                Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DuruhaButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        text: "ENTER THE GUILD",
                      ),
                      const SizedBox(height: 16),
                      DuruhaButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/signup'),
                        text: "JOIN THE REVOLUTION",
                        isOutline: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- THEME TOGGLE ---
          Positioned(
            top:
                50, // Moved down to be within SafeArea visually if not wrapped, but we are inside scaffold
            right: 20,
            child: SafeArea(child: DuruhaThemeToggleButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
