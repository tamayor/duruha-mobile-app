import 'package:flutter/material.dart';
import 'package:duruha/screens/user/components/user_navigation_bar.dart';

class HomeScreen extends StatelessWidget {
  final String role;
  final String name;

  const HomeScreen({super.key, required this.role, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Duruha Dashboard"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              role == 'Farmer' ? Icons.agriculture : Icons.shopping_basket,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              "Welcome, $name!",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Role: $role",
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "This is your personalized dashboard.",
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      bottomNavigationBar: UserNavigationBar(
        role: role,
        name: name,
        currentRoute: '/home',
      ),
    );
  }
}
