import 'package:flutter/material.dart';

import '../../core/data/app_scope.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../profile/profile_screen.dart';

/// Home tab: greeting, wallet summary, quick actions and recent activity.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final user = repo.user;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async =>
              Future<void>.delayed(const Duration(milliseconds: 400)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _Header(name: user?.name ?? 'Guest'),
              const SizedBox(height: 20),
              _WalletCard(balance: repo.balance, onTap: () => onNavigate(4)),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'What would you like to do?',
                subtitle: 'Four services, one app',
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  ActionCard(
                    icon: Icons.local_taxi,
                    title: 'Book a Ride',
                    description: 'Get around Accra',
                    color: AppColors.primary,
                    onTap: () => onNavigate(1),
                  ),
                  ActionCard(
                    icon: Icons.delivery_dining,
                    title: 'Book Delivery',
                    description: 'Send a parcel',
                    color: AppColors.highlight,
                    onTap: () => onNavigate(2),
                  ),
                  ActionCard(
                    icon: Icons.storefront,
                    title: 'WiseMart',
                    description: 'Groceries & more',
                    color: AppColors.accent,
                    onTap: () => onNavigate(3),
                  ),
                  ActionCard(
                    icon: Icons.account_balance_wallet,
                    title: 'My Wallet',
                    description: 'Top up & pay',
                    color: const Color(0xFF7C3AED),
                    onTap: () => onNavigate(4),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Recent activity',
                subtitle: 'Your latest trips and orders',
              ),
              if (repo.activity.isEmpty)
                const EmptyState(
                  icon: Icons.history,
                  title: 'No activity yet',
                  message:
                      'Your rides, deliveries and orders will appear here.',
                )
              else
                ...repo.activity
                    .take(5)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActivityTile(item: item),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Where are we going today?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ProfileScreen(onSignOut: () => Navigator.of(context).pop()),
              ),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(
                Icons.account_circle_outlined,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.balance, required this.onTap});

  final double balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Wallet balance',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.account_balance_wallet,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cedis(balance),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  _Pill(label: 'Top up', icon: Icons.add),
                  SizedBox(width: 10),
                  _Pill(label: 'Pay', icon: Icons.qr_code),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  IconData get _icon => switch (item.kind) {
    ActivityKind.ride => Icons.local_taxi,
    ActivityKind.delivery => Icons.delivery_dining,
    ActivityKind.mart => Icons.storefront,
    ActivityKind.wallet => Icons.account_balance_wallet,
  };

  Color get _color => switch (item.kind) {
    ActivityKind.ride => AppColors.primary,
    ActivityKind.delivery => AppColors.highlight,
    ActivityKind.mart => AppColors.accent,
    ActivityKind.wallet => const Color(0xFF7C3AED),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_icon, size: 20, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.subtitle} • ${relativeTime(item.timestamp)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (item.amount != null)
            Text(
              cedis(item.amount!),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
