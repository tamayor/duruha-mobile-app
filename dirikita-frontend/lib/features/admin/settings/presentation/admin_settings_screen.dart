
import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/auth/data/auth_repository.dart';
import 'package:duruha/features/admin/shared/presentation/widgets/admin_navigation.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      final authRepo = AuthRepository();
      await authRepo.logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        DuruhaSnackBar.showError(
          context,
          'Failed to sign out. Please try again.',
        );
      }
    }
  }

  void _confirmSignOut(BuildContext context) async {
    final result = await DuruhaDialog.show(
      context: context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
      isDanger: true,
    );
    if (result == true && context.mounted) {
      _handleSignOut(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'Admin Settings',
      showBackButton: false,
      bottomNavigationBar: const AdminNavigation(
        currentRoute: '/admin/settings',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DuruhaTextEmphasis(text: 'Account'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: DuruhaInkwell(
                onTap: () => _confirmSignOut(context),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
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
    );
  }
}
