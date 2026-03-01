import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/admin/shared/presentation/widgets/admin_navigation.dart';

class AdminMainScreen extends StatelessWidget {
  const AdminMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DuruhaScaffold(
      appBarTitle: 'Admin Dashboard',
      showBackButton: false,
      bottomNavigationBar: AdminNavigation(currentRoute: '/admin/dashboard'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Welcome to the Admin Dashboard!'),
            ),
          ),
        ],
      ),
    );
  }
}
