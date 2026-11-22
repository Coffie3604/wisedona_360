import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../delivery/delivery_screen.dart';
import '../home/home_screen.dart';
import '../mart/mart_screen.dart';
import '../ride/ride_screen.dart';
import '../pharmacy/pharmacy_screen.dart';

/// Bottom-navigation shell hosting the five main tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onNavigate: _go),
      const RideScreen(),
      const DeliveryScreen(),
      const MartScreen(),
      const PharmacyScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_taxi_outlined),
            selectedIcon: Icon(Icons.local_taxi, color: AppColors.primary),
            label: 'Ride',
          ),
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining, color: AppColors.primary),
            label: 'Delivery',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: AppColors.primary),
            label: 'WiseMart',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_outlined),
            selectedIcon: Icon(Icons.local_pharmacy, color: AppColors.primary),
            label: 'Pharmacy',
          ),
        ],
      ),
    );
  }
}
