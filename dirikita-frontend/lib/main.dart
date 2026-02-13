import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/theme/app_theme.dart';
import 'package:duruha/features/auth/presentation/login_screen.dart';
import 'package:duruha/features/auth/presentation/signup_screen.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';

import 'package:duruha/features/consumer/features/market/presentation/market_screen.dart';
import 'package:duruha/features/consumer/features/market/presentation/market_state.dart';
import 'package:duruha/features/consumer/features/market/presentation/order_screen.dart';
import 'package:duruha/features/consumer/features/market/presentation/payment_screen.dart';
import 'package:duruha/features/consumer/features/orders/presentation/orders_screen.dart';
import 'package:duruha/features/consumer/features/profile/presentation/profile_screen.dart';
import 'package:duruha/features/landing/presentation/landing_screen.dart';
import 'package:duruha/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/features/profile/presentation/profile_screen.dart';
import 'package:duruha/features/farmer/features/main/presentation/main_screen.dart';
import 'package:duruha/features/farmer/features/main/presentation/crop_study_screen.dart';

import 'package:duruha/features/farmer/features/sales/presentation/sales_screen.dart';
import 'package:duruha/features/farmer/features/manage/presentation/manage_screen.dart';
import 'package:duruha/features/farmer/features/manage/presentation/pledge_detail_screen.dart';
import 'package:duruha/features/farmer/features/biz/presentation/biz_screen.dart';
import 'package:duruha/features/farmer/features/programs/presentation/programs_screen.dart';
import 'package:duruha/features/farmer/features/tx/presentation/transaction_create_screen.dart';
import 'package:duruha/features/farmer/features/profile/presentation/ratings_screen.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/shared/produce/presentation/produce_detailed_screen.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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

void main() async {
  await Supabase.initialize(
    url: 'https://zovkuqlrejlcgjsjanyp.supabase.co',
    anonKey: 'sb_publishable_g0FiMD-sceVNIhF94-Unhg_DS1X2bTd',
  );
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

            // 1. Try Consumer Routes
            screen = _getConsumerScreens(settings);
            if (screen != null) return _buildRoute(settings, screen);

            // 2. Try Farmer Routes
            screen = _getFarmerScreens(settings);
            if (screen != null) return _buildRoute(settings, screen);

            // 3. Handle Shared/Top-level Routes
            switch (routeName) {
              case '/':
              case '/home':
                if (args is UserProfile) {
                  if (args.role == UserRole.farmer) {
                    screen = _protected(const FarmerMainScreen());
                  } else {
                    screen = _protected(
                      MarketScreen(
                        userData: {'role': 'Consumer', 'name': args.name},
                      ),
                    );
                  }
                } else if (args is Map<String, dynamic>) {
                  final role = args['role'] ?? 'User';
                  if (role == 'Farmer') {
                    screen = _protected(const FarmerMainScreen());
                  } else {
                    screen = _protected(MarketScreen(userData: args));
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
              default:
                if (routeName.startsWith('/produce/')) {
                  final id = routeName.replaceFirst('/produce/', '');
                  screen = _protected(ProduceDetailedScreen(produceId: id));
                }
            }

            if (screen != null) {
              return _buildRoute(settings, screen);
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

  // Helper to build the page route
  PageRouteBuilder _buildRoute(RouteSettings settings, Widget screen) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, _, _) => screen,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  Widget? _getConsumerScreens(RouteSettings settings) {
    final args = settings.arguments;
    final routeName = settings.name ?? '';

    switch (routeName) {
      case '/consumer/market':
        if (args is UserProfile) {
          return _protected(
            MarketScreen(userData: {'role': 'Consumer', 'name': args.name}),
          );
        } else if (args is Map<String, dynamic>) {
          return _protected(MarketScreen(userData: args));
        }
        break;
      case '/consumer/orders':
        if (args is UserProfile) {
          return _protected(
            ConsumerOrdersScreen(
              userData: {'role': 'Consumer', 'name': args.name},
            ),
          );
        } else if (args is Map<String, dynamic>) {
          return _protected(ConsumerOrdersScreen(userData: args));
        }
        break;
      case '/consumer/market/order':
        if (args is Map<String, dynamic>) {
          final marketState = args['marketState'] as MarketState?;
          final userData = args['userData'] as Map<String, dynamic>? ?? {};
          if (marketState != null) {
            return _protected(
              OrderScreen(marketState: marketState, userData: userData),
            );
          }
        }
        break;
      case '/consumer/market/order/pay':
        if (args is Map<String, dynamic>) {
          final order = args['order'] as MarketOrder?;
          final userData = args['userData'] as Map<String, dynamic>? ?? {};
          final marketState = args['marketState'] as MarketState?;
          if (order != null && marketState != null) {
            return _protected(
              PaymentScreen(
                order: order,
                userData: userData,
                marketState: marketState,
              ),
            );
          }
        }
        break;
    }
    return null;
  }

  Widget? _getFarmerScreens(RouteSettings settings) {
    final args = settings.arguments;
    final routeName = settings.name ?? '';

    switch (routeName) {
      case '/farmer/main':
        return _protected(const FarmerMainScreen());
      case '/farmer/pledge/study':
        if (args is String) {
          return _protected(CropStudyScreen(cropId: args));
        }
        break;
      case '/farmer/sales':
        return _protected(const FarmerSalesScreen());
      case '/farmer/biz':
        return _protected(const FarmerBizScreen());
      case '/farmer/manage':
        return _protected(const ManageScreen());
      case '/farmer/tx/create':
        if (args is Map<String, dynamic>) {
          final ids = args['ids'] as List<String>;
          final mode = args['mode'] as String;
          return _protected(
            TransactionCreateScreen(selectedCropIds: ids, mode: mode),
          );
        }
        break;
      case '/farmer/programs':
        return _protected(const FarmerProgramsScreen());
      case '/farmer/profile/ratings':
        return _protected(const FarmerProfileRatingsScreen());
      case '/farmer/biz/crops/':
        if (args is String) {
          // return _protected(CropDetailScreen(cropId: args));
        }
        break;
      default:
        if (routeName.startsWith('/farmer/monitor/')) {
          final id = routeName.replaceFirst('/farmer/monitor/', '');
          final pledge = args is HarvestPledge ? args : null;
          return _protected(PledgeDetailScreen(pledgeId: id, pledge: pledge));
        }
    }
    return null;
  }
}
