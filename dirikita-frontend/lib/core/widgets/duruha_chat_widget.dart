import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:duruha/supabase_config.dart';
import 'package:duruha/shared/user/domain/user_models.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';

/// A full-screen Tawk.to live-chat screen using InAppWebView with the
/// Tawk.to JavaScript API to pass visitor information in Secure Mode.
class DuruhaChatScreen extends StatefulWidget {
  const DuruhaChatScreen({super.key});

  @override
  State<DuruhaChatScreen> createState() => _DuruhaChatScreenState();
}

class _DuruhaChatScreenState extends State<DuruhaChatScreen> {
  static const _tawkPropertyId = '69b223a48035e41c3b44f700';
  static const _tawkWidgetId = '1jjg5nupm';

  /// The Tawk.to API Secret provided for Secure Mode.
  static const _tawkSecret = 'de3e836348c28c4dd5f2ee64fb4d6db372e10a8e';

  UserProfile? _userProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await supabase.rpc(
        'manage_profile',
        params: {'p_mode': 'get'},
      );
      if (mounted) {
        setState(() {
          _userProfile = UserProfile.fromJson(
            Map<String, dynamic>.from(response as Map),
          );
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('DuruhaChatScreen: failed to fetch user profile — $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  /// Calculates the HMAC-SHA256 hash required for Tawk.to Secure Mode.
  String _calculateHash(String email) {
    final key = utf8.encode(_tawkSecret);
    final bytes = utf8.encode(email);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  String _buildTawkHtml() {
    final profile = _userProfile;
    final id = profile?.id;
    final name = profile != null
        ? '${profile.role?.name.toUpperCase() ?? 'USER'} - ${profile.name}'
        : null;

    // Use a consistent email for identification, matching the one used for the hash
    final String email;
    final String? profileEmail = profile?.email;
    final String? profilePhone = profile?.phone;

    if (profileEmail != null && profileEmail.isNotEmpty) {
      email = profileEmail;
    } else if (profilePhone != null && profilePhone.isNotEmpty) {
      email = '$profilePhone@duruha.com';
    } else {
      email = '${profile?.id ?? 'guest'}@duruha.com';
    }

    final hash = email.isNotEmpty ? _calculateHash(email) : '';

    final role = profile?.role?.name.toUpperCase() ?? 'USER';

    // Use window.Tawk_API.setAttributes for visitor identification
    // and onChatStarted for session tagging.
    final setAttributes = (id != null || name != null || email.isNotEmpty)
        ? '''
      window.Tawk_API.onLoad = function () {
        window.Tawk_API.setAttributes({
          ${id != null ? "'id': '${_jsEscape(id)}'," : ''}
          ${name != null ? "'name': '${_jsEscape(name)}'," : ''}
          ${email.isNotEmpty ? "'email': '${_jsEscape(email)}'," : ''}
          ${hash.isNotEmpty ? "'hash': '$hash'," : ''}
        }, function(error) {
          if (error) {
            console.error('Tawk.to setAttributes error:', error);
          }
        });
      };


'''
        : '';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background-color: #FFFFFF; }
  </style>
</head>
<body>
<script>
  var Tawk_API = Tawk_API || {};
  var Tawk_LoadStart = new Date();
  
  $setAttributes
  (function(){
    var s1 = document.createElement("script");
    var s0 = document.getElementsByTagName("script")[0];
    s1.async = true;
    s1.src = 'https://embed.tawk.to/$_tawkPropertyId/$_tawkWidgetId';
    s1.charset = 'UTF-8';
    s1.setAttribute('crossorigin','*');
    s0.parentNode.insertBefore(s1, s0);
  })();

  
</script>
</body>
</html>
''';
  }

  /// Minimal JS string escaping for single-quoted strings.
  String _jsEscape(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScaffold(
      appBarTitle: 'Help & Support',
      body: _isLoadingProfile
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : InAppWebView(
              initialData: InAppWebViewInitialData(
                data: _buildTawkHtml(),
                mimeType: 'text/html',
                encoding: 'utf-8',
                baseUrl: WebUri('https://tawk.to'),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,
                // Ensure we don't restore old session state automatically
                clearCache: true,
                clearSessionCache: true,
                disableDefaultErrorPage: true,
                incognito:
                    true, // Use incognito mode if supported for better isolation
              ),
              onWebViewCreated: (controller) async {
                // Safely clear cookies to isolate user sessions
                try {
                  final cookieManager = CookieManager.instance();
                  await cookieManager.deleteAllCookies();
                } catch (e) {
                  debugPrint('DuruhaChatScreen: failed to clear cookies — $e');
                }
              },
              onReceivedError: (controller, request, error) {
                debugPrint(
                  'DuruhaChatScreen: WebView error — ${error.description}',
                );
              },
            ),
    );
  }
}
