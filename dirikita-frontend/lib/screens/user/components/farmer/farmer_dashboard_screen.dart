import 'package:duruha/screens/user/components/user_navigation_bar.dart';
import 'package:duruha/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class FarmerDashboardScreen extends StatelessWidget {
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Dashboard')),
      bottomNavigationBar: UserNavigationBar(
        role: 'Farmer',
        name: 'Elly Farmer',
        currentRoute: '/farmer/dashboard',
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome, Farmer!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DuruhaButton(
              onPressed: () {
                Navigator.pushNamed(context, '/farmer/pledge/create');
              },
              text: 'Pledge',
            ),
          ],
        ),
      ),
    );
  }
}
