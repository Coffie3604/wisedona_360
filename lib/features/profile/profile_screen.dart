import 'package:flutter/material.dart';

import '../../core/data/app_scope.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// Profile & settings, reachable from the home header.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final user = repo.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    (user?.name.isNotEmpty ?? false)
                        ? user!.name[0].toUpperCase()
                        : 'W',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Guest',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.phone ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _Tile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Wallet balance',
            trailing: cedis(repo.balance),
          ),
          _Tile(
            icon: Icons.local_taxi_outlined,
            title: 'Total rides',
            trailing:
                '${repo.activity.where((a) => a.kind == ActivityKind.ride).length}',
          ),
          _Tile(
            icon: Icons.delivery_dining_outlined,
            title: 'Total deliveries',
            trailing:
                '${repo.activity.where((a) => a.kind == ActivityKind.delivery).length}',
          ),
          const SizedBox(height: 20),
          _Tile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            trailing: 'On',
          ),
          _Tile(
            icon: Icons.help_outline,
            title: 'Help & support',
            trailing: '',
          ),
          _Tile(
            icon: Icons.info_outline,
            title: 'About Wisedona',
            trailing: 'v1.0.0',
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await repo.signOut();
              onSignOut();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
