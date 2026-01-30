import 'package:duruha/screens/landing_screen.dart';
import 'package:duruha/screens/user/profile_screen.dart';
import 'package:duruha/screens/auth/login_screen.dart';
import 'package:duruha/screens/auth/signup_screen.dart';
import 'package:duruha/screens/onboarding/onboarding_screen.dart';
import 'package:duruha/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'package:duruha/screens/user/home_screen.dart';
import 'package:duruha/screens/user/components/user_navigation_bar.dart';
import 'package:duruha/screens/user/components/farmer/farmer_crops_screen.dart';
import 'package:duruha/screens/user/components/farmer/farmer_dashboard_screen.dart';
import 'package:duruha/screens/user/components/farmer/farmer_create_pledge_screen.dart';

void main() {
  runApp(const DuruhaApp());
}

class DuruhaApp extends StatelessWidget {
  const DuruhaApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Duruha',
          theme: DuruhaTheme.lightTheme,
          darkTheme: DuruhaTheme.darkTheme,
          themeMode: mode,

          // Change initialRoute to '/' which is now the LandingScreen
          initialRoute: '/',

          routes: {
            '/': (context) => const LandingScreen(), // The new default screen
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
          },
          onGenerateRoute: (settings) {
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final routeName = settings.name ?? '';

            Widget? screen;
            switch (routeName) {
              case '/home':
                screen = HomeScreen(
                  role: args['role'] ?? 'User',
                  name: args['name'] ?? 'Friend',
                );
                break;
              case '/profile':
                screen = ProfileScreen(userData: args);
                break;
              case '/orders':
                screen = _buildPlaceholderScreen(args, routeName, 'Orders');
                break;
              case '/inventory':
                screen = _buildPlaceholderScreen(args, routeName, 'Inventory');
                break;
              case '/farmer/crops':
                screen = FarmerCropsScreen();
                break;
              case '/farmer/dashboard':
                screen = FarmerDashboardScreen();
                break;
              case '/farmer/pledge/create':
                screen = FarmerCreatePledgeScreen();
                break;
            }

            if (screen != null) {
              return PageRouteBuilder(
                settings: settings,
                pageBuilder: (_, __, ___) => screen!,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              );
            }
            return null; // Let unknown routes be handled by onUnknownRoute or error
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  Widget _buildPlaceholderScreen(
    Map<String, dynamic> args,
    String route,
    String title,
  ) {
    final role = args['role'] as String? ?? 'User';
    final name = args['name'] as String? ?? 'Friend';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text("$title Screen\nRole: $role")),
      bottomNavigationBar: UserNavigationBar(
        role: role,
        name: name,
        currentRoute: route,
      ),
    );
  }
}
