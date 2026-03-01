import 'dart:async';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/theme/app_theme.dart';
import 'package:duruha/features/auth/presentation/login_screen.dart';
import 'package:duruha/features/auth/presentation/signup_screen.dart';
import 'package:duruha/features/auth/presentation/otp_verification_screen.dart';
import 'package:duruha/features/admin/dashboard/presentation/admin_main_screen.dart';
import 'package:duruha/features/admin/produce/presentation/admin_produce_screen.dart';
import 'package:duruha/features/admin/price_calculator/presentation/price_calculator_screen.dart';
import 'package:duruha/features/admin/settings/presentation/admin_settings_screen.dart';
import 'package:duruha/features/farmer/features/manage/offers/presentation/offer_detail_loader_screen.dart';
import 'package:duruha/features/consumer/features/manage/presentation/order_details_screen.dart';
import 'package:duruha/features/consumer/features/subscription/pricelock/presentation/price_lock_subscription_details_screen.dart';
import 'package:duruha/features/consumer/features/subscription/pricelock/presentation/price_lock_subscriptions_screen.dart';
import 'package:duruha/features/consumer/features/subscription/presentation/subscriptions_hub_screen.dart';
import 'package:duruha/features/consumer/features/shop/presentation/shop_screen.dart';
import 'package:duruha/features/consumer/features/profile/presentation/profile_screen.dart';
import 'package:duruha/features/landing/presentation/landing_screen.dart';
import 'package:duruha/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/features/profile/presentation/profile_screen.dart';
import 'package:duruha/features/farmer/features/main/presentation/main_screen.dart';
import 'package:duruha/features/farmer/features/main/presentation/crop_study_screen.dart';

import 'package:duruha/features/farmer/features/sales/presentation/sales_screen.dart';
import 'package:duruha/features/farmer/features/manage/shared/presentation/manage_screen.dart';
import 'package:duruha/features/farmer/features/manage/pledge/presentation/pledge_detail_screen.dart';
import 'package:duruha/features/farmer/features/biz/presentation/biz_screen.dart';
import 'package:duruha/features/farmer/features/programs/presentation/programs_screen.dart';
import 'package:duruha/features/farmer/features/tx/presentation/transaction_create_screen.dart';
import 'package:duruha/features/consumer/features/tx/presentation/transaction_create_screen.dart'
    as consumer_tx;
import 'package:duruha/features/consumer/features/manage/presentation/manage_screen.dart';
import 'package:duruha/features/farmer/features/profile/presentation/ratings_screen.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/subscription/presentation/subscriptions_hub_screen.dart' as farmer_hub;
import 'package:duruha/features/farmer/features/subscription/pricelock/presentation/farmer_price_lock_subscriptions_screen.dart';
import 'package:duruha/features/farmer/features/subscription/pricelock/presentation/farmer_price_lock_subscription_details_screen.dart';
import 'package:duruha/shared/produce/presentation/produce_detailed_screen.dart';
import 'package:duruha/shared/user/domain/user_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  final UserRole? requiredRole;
  const ProtectedScreen({super.key, required this.child, this.requiredRole});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: SessionService.getSavedUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
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

        // Role check
        if (requiredRole != null) {
          final isAuthorized =
              (requiredRole == UserRole.farmer && user.isFarmer) ||
              (requiredRole == UserRole.consumer && user.isConsumer) ||
              (requiredRole == UserRole.admin && user.isAdmin);

          if (!isAuthorized) {
            debugPrint(
              "🚫 [AUTH] Role mismatch. Required: $requiredRole, User: ${user.role}",
            );
            Future.microtask(() {
              if (context.mounted) {
                // Redirect to appropriate home based on user's actual role
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                  arguments: user,
                );
              }
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        }

        return child;
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
    try {
      final loggedIn = await SessionService.isLoggedIn();
      if (!loggedIn) {
        debugPrint("ℹ️ [SPLASH] No active session. Returning to landing.");
        if (mounted) Navigator.pushReplacementNamed(context, '/');
        return;
      }

      final user = await SessionService.getSavedUser();
      if (mounted) {
        if (user != null) {
          debugPrint("✅ [SPLASH] Session valid. User: ${user.name}");
          Navigator.pushReplacementNamed(context, '/home', arguments: user);
        } else {
          debugPrint(
            "⚠️ [SPLASH] Session found but profile could not be synced. Returning to landing.",
          );
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } catch (e) {
      debugPrint(
        "❌ [SPLASH] Error checking session: $e. Returning to landing.",
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

void main() {
  Zone? appZone;

  // Ensure we have a zone to catch all errors
  runZonedGuarded(
    () async {
      appZone = Zone.current;
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint("🚀 [MAIN] Starting ultra-safe initialization...");

      // 1. Load Dotenv with timeout
      try {
        await dotenv
            .load(fileName: ".env")
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint("⏰ [MAIN] Dotenv load timed out.");
                throw Exception("Dotenv Timeout");
              },
            );
        debugPrint("✅ [MAIN] Dotenv loaded.");
      } catch (e) {
        debugPrint("⚠️ [MAIN] Dotenv failed: $e");
      }

      // 2. Initialize Supabase
      try {
        final url = dotenv.env['SUPABASE_URL'] ?? "";
        final key = dotenv.env['SUPABASE_ANON_KEY'] ?? "";

        await Supabase.initialize(url: url, anonKey: key);
        debugPrint("✅ [MAIN] Supabase initialized.");
      } catch (e) {
        debugPrint("❌ [MAIN] Supabase init failed: $e");
      }

      // 3. Initialize Theme with timeout
      try {
        final theme = await SessionService.getThemePreference().timeout(
          const Duration(seconds: 2),
          onTimeout: () => ThemeMode.system,
        );
        DuruhaApp.themeNotifier.value = theme;
        debugPrint("✅ [MAIN] Theme initialized.");
      } catch (e) {
        debugPrint("⚠️ [MAIN] Theme init failed: $e");
      }

      runApp(const DuruhaApp());
    },
    (error, stack) {
      debugPrint("‼️ [CRITICAL] Uncaught error in main zone: $error");
      debugPrint(stack.toString());

      (appZone ?? Zone.current).run(() {
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Container(
                color: Colors.orange,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Startup Error:\n$error",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      });
    },
  );
}

// Fallback widget for /home when arguments are null
class RoleBasedHome extends StatelessWidget {
  const RoleBasedHome({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: SessionService.getSavedUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          Future.microtask(() {
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/');
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user.isFarmer) {
          return const FarmerMainScreen();
        } else if (user.isConsumer) {
          return ConsumerShopScreen();
        } else if (user.isAdmin) {
          return const AdminMainScreen();
        } else {
          // Fallback if role is null or unrecognized
          return ConsumerShopScreen();
        }
      },
    );
  }
}

class DuruhaApp extends StatelessWidget {
  const DuruhaApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  @override
  Widget build(BuildContext context) {
    debugPrint("🏗️ [DURUHA APP] Building main app widget tree...");
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
            '/verify-otp': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as String;
              return OtpVerificationScreen(email: args);
            },
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
              case '/home':
                if (args is UserProfile) {
                  if (args.role == UserRole.farmer) {
                    screen = _protected(
                      const FarmerMainScreen(),
                      role: UserRole.farmer,
                    );
                  } else if (args.role == UserRole.admin) {
                    screen = _protected(
                      const AdminMainScreen(),
                      role: UserRole.admin,
                    );
                  } else {
                    screen = _protected(
                      ConsumerShopScreen(),
                      role: UserRole.consumer,
                    );
                  }
                } else if (args is Map<String, dynamic>) {
                  final String role = (args['role'] ?? '')
                      .toString()
                      .toUpperCase();
                  if (role == 'FARMER') {
                    screen = _protected(
                      const FarmerMainScreen(),
                      role: UserRole.farmer,
                    );
                  } else {
                    screen = _protected(
                      ConsumerShopScreen(),
                      role: UserRole.consumer,
                    );
                  }
                } else {
                  // Fallback for direct navigation to /home
                  screen = const RoleBasedHome();
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
                      role: UserRole.farmer,
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
                      role: UserRole.consumer,
                    );
                  }
                } else if (args is Map<String, dynamic>) {
                  final String role = (args['role'] ?? '')
                      .toString()
                      .toUpperCase();
                  if (role == 'FARMER') {
                    screen = _protected(
                      FarmerProfileScreen(userData: args),
                      role: UserRole.farmer,
                    );
                  } else {
                    screen = _protected(
                      ConsumerProfileScreen(userData: args),
                      role: UserRole.consumer,
                    );
                  }
                }
                break;
              default:
                if (routeName.startsWith('/produce/')) {
                  final id = routeName.replaceFirst('/produce/', '');
                  screen = _protected(ProduceDetailedScreen(produceId: id));
                }
            }

            if (routeName.startsWith('/admin/')) {
              screen = _getAdminScreens(settings);
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
  Widget _protected(Widget child, {UserRole? role}) =>
      ProtectedScreen(requiredRole: role, child: child);

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
      case '/consumer/shop':
        return _protected(ConsumerShopScreen(), role: UserRole.consumer);
      case '/consumer/manage':
        return _protected(
          const ConsumerManageScreen(),
          role: UserRole.consumer,
        );
      case '/consumer/manage/order':
        if (args is Map<String, dynamic>) {
          return _protected(
            OrderDetailsScreen(match: args['match'], action: args['action']),
            role: UserRole.consumer,
          );
        } else if (args is String) {
          return _protected(
            OrderDetailsScreen(orderId: args),
            role: UserRole.consumer,
          );
        }
        break;
      case '/consumer/tx/create':
        if (args is Map<String, dynamic>) {
          final ids = (args['ids'] as List).cast<String>();
          final mode = args['mode'] as String;
          return _protected(
            consumer_tx.TransactionCreateScreen(
              selectedCropIds: ids,
              mode: mode,
            ),
            role: UserRole.consumer,
          );
        }
        break;
      case '/consumer/subscriptions/pricelock_details':
        if (args is String) {
          return _protected(
            PriceLockSubscriptionDetailsScreen(cplsId: args),
            role: UserRole.consumer,
          );
        }
        break;
      case '/consumer/subscriptions/pricelock':
        return _protected(
          const PriceLockSubscriptionsScreen(),
          role: UserRole.consumer,
        );
      case '/consumer/subscriptions':
        return _protected(
          const SubscriptionsHubScreen(),
          role: UserRole.consumer,
        );
    }
    return null;
  }

  Widget? _getAdminScreens(RouteSettings settings) {
    final routeName = settings.name ?? '';

    switch (routeName) {
      case '/admin/dashboard':
      case '/admin/main':
        return _protected(const AdminMainScreen(), role: UserRole.admin);
      case '/admin/produce':
        return _protected(const AdminProduceScreen(), role: UserRole.admin);
      case '/admin/calculator':
        return _protected(const PriceCalculatorScreen(), role: UserRole.admin);
      case '/admin/settings':
        return _protected(const AdminSettingsScreen(), role: UserRole.admin);
    }
    return null;
  }

  Widget? _getFarmerScreens(RouteSettings settings) {
    final args = settings.arguments;
    final routeName = settings.name ?? '';

    switch (routeName) {
      case '/farmer/main':
        return _protected(const FarmerMainScreen(), role: UserRole.farmer);
      case '/farmer/pledge/study':
        if (args is String) {
          return _protected(
            CropStudyScreen(cropId: args),
            role: UserRole.farmer,
          );
        }
        break;
      case '/farmer/sales':
        return _protected(const FarmerSalesScreen(), role: UserRole.farmer);
      case '/farmer/biz':
        return _protected(const FarmerBizScreen(), role: UserRole.farmer);
      case '/farmer/manage':
        return _protected(const ManageScreen(), role: UserRole.farmer);
      case '/farmer/manage/offer':
        if (args is String) {
          return _protected(
            OfferDetailLoaderScreen(offerId: args),
            role: UserRole.farmer,
          );
        }
        break;
      case '/farmer/tx/create':
        if (args is Map<String, dynamic>) {
          final ids = args['ids'] as List<String>;
          final mode = args['mode'] as String;
          return _protected(
            TransactionCreateScreen(selectedCropIds: ids, mode: mode),
            role: UserRole.farmer,
          );
        }
        break;
      case '/farmer/subscriptions':
        return _protected(
          const farmer_hub.SubscriptionsHubScreen(),
          role: UserRole.farmer,
        );
      case '/farmer/subscriptions/pricelock':
        return _protected(
          const FarmerPriceLockSubscriptionsScreen(),
          role: UserRole.farmer,
        );
      case '/farmer/subscriptions/pricelock_details':
        if (args is String) {
          return _protected(
            FarmerPriceLockSubscriptionDetailsScreen(fplsId: args),
            role: UserRole.farmer,
          );
        }
        break;
      case '/farmer/programs':
        return _protected(const FarmerProgramsScreen(), role: UserRole.farmer);
      case '/farmer/profile/ratings':
        return _protected(
          const FarmerProfileRatingsScreen(),
          role: UserRole.farmer,
        );
      case '/farmer/biz/crops/':
        if (args is String) {
          // return _protected(CropDetailScreen(cropId: args));
        }
        break;
      default:
        if (routeName.startsWith('/farmer/monitor/')) {
          final id = routeName.replaceFirst('/farmer/monitor/', '');
          final pledge = args is HarvestPledge ? args : null;
          return _protected(
            PledgeDetailScreen(pledgeId: id, pledge: pledge),
            role: UserRole.farmer,
          );
        }
    }
    return null;
  }
}
