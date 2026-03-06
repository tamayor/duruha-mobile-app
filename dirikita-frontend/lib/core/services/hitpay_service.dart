import 'package:app_links/app_links.dart';
import 'package:duruha/main.dart';
import 'package:duruha/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:duruha/shared/user/domain/user_models.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/features/consumer/features/manage/presentation/manage_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HitPayService {
  // Singleton pattern
  static final HitPayService _instance = HitPayService._internal();
  factory HitPayService() => _instance;
  HitPayService._internal();

  static bool isRedirecting = false;
  static String? pendingOrderId; // Store orderId to navigate to after payment
  static String? pendingAction =
      'payment-success'; // Store action for navigation

  final _appLinks = AppLinks();

  void init() {
    // 1. Listen for the deep link return from HitPay (while app is open)
    _appLinks.uriLinkStream.listen(_handleUri);

    // 2. Handle the link that launched the app (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) async {
    if (uri.scheme == 'duruha' && uri.host == 'payment-callback') {
      isRedirecting = true; // Signal to other screens to stop navigation
      debugPrint(
        "💳 [HITPAY] User returned to app via deep link. Waiting for session hydration... URI: $uri",
      );

      // Wait for a valid session before navigating.
      // We check every 500ms for up to 5 seconds.
      UserProfile? user;
      int attempts = 0;
      while (user == null && attempts < 10) {
        attempts++;
        user = await SessionService.getSavedUser();
        if (user == null) {
          debugPrint("⏳ [HITPAY] Waiting for session... attempt $attempts");
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (user != null && user.isConsumer) {
        debugPrint("✅ [HITPAY] Session ready. Navigating to order.");
        // Ensure user is fresh in session before navigating
        await SessionService.saveUser(user);

        // Navigate to order details if orderId is set, otherwise to manage
        final orderId = pendingOrderId;
        final action = pendingAction;
        final routeName = orderId != null
            ? '/consumer/manage/order'
            : '/consumer/manage';

        debugPrint(
          "🔄 [HITPAY] Navigating to $routeName with orderId: $orderId, action: $action",
        );

        if (orderId != null) {
          DuruhaApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            routeName,
            (route) => route.isFirst,
            arguments: {'orderId': orderId, 'action': action},
          );
        } else {
          DuruhaApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            routeName,
            (route) => route.isFirst,
          );
        }

        // Clear pending order ID and action after navigation
        pendingOrderId = null;
        pendingAction = 'payment-success';

        // Keep isRedirecting true longer to prevent interruption
        Future.delayed(const Duration(seconds: 4), () {
          isRedirecting = false;
        });
      } else {
        debugPrint(
          "❌ [HITPAY] Session hydration timed out or user is not a consumer. User may need to log in manually.",
        );
        isRedirecting = false; // Reset to allow manual navigation
      }
    }
  }

  /// Invokes the Supabase Edge Function to create a payment link and opens it.
  Future<void> pay({
    required double amount,
    required String referenceNumber,
    String currency = 'PHP',
    String? orderId,
    String action = 'payment-success',
  }) async {
    // Store orderId and action for use in the deep link callback
    if (orderId != null) {
      pendingOrderId = orderId;
      pendingAction = action;
      debugPrint(
        "💾 [HITPAY] Stored pending orderId: $orderId, action: $action",
      );
    }
    try {
      // Use the default supabase.functions.invoke which automatically handles auth headers.
      // We also simplify the body to just the essentials that were confirmed to work previously.
      final response = await supabase.functions.invoke(
        'hitpay-checkout',
        body: {
          'amount': amount,
          'reference_number': referenceNumber,
          'currency': currency,
        },
      );

      // 2. Launch system browser (HitPay checkout page)
      final url = response.data['url'] as String?;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('❌ [HITPAY] Could not launch payment URL: $url');
        }
      } else {
        final errorMsg = response.data is Map
            ? response.data['message']
            : 'Unknown error';
        debugPrint('❌ [HITPAY] Edge Function failed: $errorMsg');
        // We throw or return so the UI can notify the user
      }
    } catch (e) {
      debugPrint('❌ [HITPAY] Error invoking edge function: $e');
      rethrow;
    }
  }
}
