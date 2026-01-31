import 'package:duruha/core/theme/app_theme.dart';
import 'package:duruha/features/auth/presentation/login_screen.dart';
import 'package:duruha/features/auth/presentation/signup_screen.dart';

import 'package:duruha/features/farmer/shared/presentation/create_pledge_screen.dart';
import 'package:duruha/features/landing/presentation/landing_screen.dart';
import 'package:duruha/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/features/profile/presentation/profile_screen.dart';
import 'package:duruha/features/consumer/features/profile/presentation/profile.dart';
import 'package:duruha/features/farmer/features/farm/presentation/farmer_dashboard_screen.dart';
import 'package:duruha/features/farmer/features/farm/presentation/crop_study_screen.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_navigation.dart';
import 'package:duruha/features/farmer/features/crops/presentation/farmer_crops_screen.dart';
import 'package:duruha/features/farmer/features/crops/presentation/crop_detail_screen.dart';
import 'package:duruha/features/farmer/features/monitor/presentation/pledge_monitor_screen.dart';
import 'package:duruha/features/farmer/features/monitor/presentation/pledge_detail_screen.dart';
import 'package:duruha/features/farmer/features/biz/presentation/biz_screen.dart';
import 'package:duruha/features/farmer/features/programs/presentation/programs_screen.dart';
import 'package:duruha/features/farmer/features/profile/presentation/ratings_screen.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

// Placeholder for missing screens
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(title)));
}

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
      builder: (_, mode, _) {
        return MaterialApp(
          title: 'Duruha',
          theme: DuruhaTheme.lightTheme,
          darkTheme: DuruhaTheme.darkTheme,
          themeMode: mode,
          initialRoute: '/',
          routes: {
            '/': (context) => const LandingScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
          },
          onGenerateRoute: (settings) {
            final args = settings.arguments;
            final routeName = settings.name ?? '';
            Widget? screen;
            switch (routeName) {
              case '/home':
                if (args is UserProfile) {
                  if (args.role == UserRole.farmer) {
                    screen = const FarmerDashboardScreen();
                  } else {
                    screen = _buildPlaceholderScreen(
                      {'role': 'Consumer', 'name': args.name},
                      '/home',
                      'Market',
                    );
                  }
                } else if (args is Map<String, dynamic>) {
                  final role = args['role'] ?? 'User';
                  if (role == 'Farmer') {
                    screen = const FarmerDashboardScreen();
                  } else {
                    screen = _buildPlaceholderScreen(args, '/home', 'Market');
                  }
                }
                break;
              case '/profile':
                if (args is UserProfile) {
                  if (args.role == UserRole.farmer) {
                    screen = FarmerProfileScreen(
                      userData: {
                        'role': 'Farmer',
                        'name': args.name,
                        'id': args.id,
                      },
                    );
                  } else {
                    screen = ConsumerProfileScreen(
                      userData: {
                        'role': 'Consumer',
                        'name': args.name,
                        'id': args.id,
                      },
                    );
                  }
                } else if (args is Map<String, dynamic>) {
                  final role = args['role'] ?? 'User';
                  if (role == 'Farmer') {
                    screen = FarmerProfileScreen(userData: args);
                  } else {
                    screen = ConsumerProfileScreen(userData: args);
                  }
                }
                break;
              case '/orders':
                screen = _buildPlaceholderScreen(
                  args is Map<String, dynamic> ? args : {},
                  routeName,
                  'Orders',
                );
                break;
              case '/inventory':
                screen = _buildPlaceholderScreen(
                  args is Map<String, dynamic> ? args : {},
                  routeName,
                  'Inventory',
                );
                break;

              case '/farmer/farm':
                screen = const FarmerDashboardScreen();
                break;
              case '/farmer/pledge/create':
                screen = const FarmerCreatePledgeScreen();
                break;
              case '/farmer/pledge/study':
                if (args is String) {
                  screen = CropStudyScreen(cropId: args);
                }
                break;
              case '/farmer/crops':
                screen = const FarmerCropsScreen();
                break;
              case '/farmer/biz':
                screen = const FarmerBizScreen();
                break;
              case '/farmer/monitor':
                screen = const MonitorPledgeScreen();
                break;
              case '/farmer/programs':
                screen = const FarmerProgramsScreen();
                break;
              case '/farmer/profile/ratings':
                screen = const FarmerProfileRatingsScreen();
                break;
              default:
                if (routeName.startsWith('/farmer/biz/monitor/')) {
                  final id = routeName.replaceFirst('/farmer/biz/monitor/', '');
                  final pledge = args is HarvestPledge ? args : null;
                  screen = PledgeDetailScreen(pledgeId: id, pledge: pledge);
                } else if (routeName.startsWith('/farmer/biz/crops/')) {
                  final id = routeName.replaceFirst('/farmer/biz/crops/', '');
                  screen = CropDetailScreen(cropId: id);
                } else {
                  //  print('Navigating to default: $routeName');
                }
            }
            if (screen != null) {
              return PageRouteBuilder(
                settings: settings,
                pageBuilder: (_, _, _) => screen!,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              );
            }
            return null;
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
    var role = args['role'] as String? ?? 'User';
    final name = args['name'] as String? ?? 'Friend';

    // If role is user, we might want to default to consumer navigation if it's the default
    if (role == 'User') role = 'Consumer';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text("$title Screen\nRole: $role")),
      bottomNavigationBar: role == 'Farmer'
          ? FarmerNavigation(name: name, currentRoute: route)
          : ConsumerNavigation(name: name, currentRoute: route),
    );
  }
}
