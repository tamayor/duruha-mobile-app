import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/theme/app_theme.dart';
import 'package:duruha/features/auth/presentation/login_screen.dart';
import 'package:duruha/features/auth/presentation/signup_screen.dart';
import 'package:duruha/features/consumer/features/profile/presentation/profile_screen.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';

import 'package:duruha/features/farmer/shared/presentation/create_pledge_screen.dart';
import 'package:duruha/features/landing/presentation/landing_screen.dart';
import 'package:duruha/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/features/profile/presentation/profile_screen.dart';
import 'package:duruha/features/farmer/features/farm/presentation/dashboard_screen.dart';
import 'package:duruha/features/farmer/features/farm/presentation/crop_study_screen.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/features/farmer/features/crops/presentation/crops_screen.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(title)));
  }
}

class ProtectedScreen extends StatelessWidget {
  final Widget child;
  const ProtectedScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SessionService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return child;
        } else {
          // Redirect to Landing if not logged in
          Future.microtask(() {
            if (context.mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Check for expiry first
    await SessionService.clearIfExpired();

    final user = await SessionService.getSavedUser();
    if (mounted) {
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home', arguments: user);
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
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
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/': (context) => const LandingScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/onboarding': (context) =>
                const ProtectedScreen(child: OnboardingScreen()),
          },
          onGenerateRoute: (settings) {
            final args = settings.arguments;
            final routeName = settings.name ?? '';
            Widget? screen;
            switch (routeName) {
              case '/home':
                if (args is UserProfile) {
                  if (args.role == UserRole.farmer) {
                    screen = _protected(const FarmerDashboardScreen());
                  } else {
                    screen = _protected(
                      _buildPlaceholderScreen(
                        {'role': 'Consumer', 'name': args.name},
                        '/market',
                        'Market',
                      ),
                    );
                  }
                } else if (args is Map<String, dynamic>) {
                  final role = args['role'] ?? 'User';
                  if (role == 'Farmer') {
                    screen = _protected(const FarmerDashboardScreen());
                  } else {
                    screen = _protected(
                      _buildPlaceholderScreen(args, '/home', 'Market'),
                    );
                  }
                }
                break;
              case '/profile':
                if (args is UserProfile) {
                  if (args.role == UserRole.farmer) {
                    screen = _protected(
                      FarmerProfileScreen(
                        userData: {
                          'role': 'Farmer',
                          'name': args.name,
                          'id': args.id,
                        },
                      ),
                    );
                  } else {
                    screen = _protected(
                      ConsumerProfileScreen(
                        userData: {
                          'role': 'Consumer',
                          'name': args.name,
                          'id': args.id,
                        },
                      ),
                    );
                  }
                } else if (args is Map<String, dynamic>) {
                  final role = args['role'] ?? 'User';
                  if (role == 'Farmer') {
                    screen = _protected(FarmerProfileScreen(userData: args));
                  } else {
                    screen = _protected(ConsumerProfileScreen(userData: args));
                  }
                }
                break;
              // case '/consumer/market':
              //   screen = _protected(ConsumerProfileScreen());
              //   break;
              case '/farmer/farm':
                screen = _protected(const FarmerDashboardScreen());
                break;
              case '/farmer/pledge/create':
                screen = _protected(const FarmerCreatePledgeScreen());
                break;
              case '/farmer/pledge/study':
                if (args is String) {
                  screen = _protected(CropStudyScreen(cropId: args));
                }
                break;
              case '/farmer/crops':
                screen = _protected(const FarmerCropsScreen());
                break;
              case '/farmer/biz':
                screen = _protected(const FarmerBizScreen());
                break;
              case '/farmer/monitor':
                screen = _protected(const MonitorPledgeScreen());
                break;
              case '/farmer/programs':
                screen = _protected(const FarmerProgramsScreen());
                break;
              case '/farmer/profile/ratings':
                screen = _protected(const FarmerProfileRatingsScreen());
                break;
              default:
                if (routeName.startsWith('/farmer/monitor/')) {
                  final id = routeName.replaceFirst('/farmer/monitor/', '');
                  final pledge = args is HarvestPledge ? args : null;
                  screen = _protected(
                    PledgeDetailScreen(pledgeId: id, pledge: pledge),
                  );
                } else if (routeName.startsWith('/farmer/crops/')) {
                  final id = routeName.replaceFirst('/farmer/crops/', '');
                  screen = _protected(CropDetailScreen(cropId: id));
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

  // Helper to wrap protected routes
  Widget _protected(Widget child) => ProtectedScreen(child: child);

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
