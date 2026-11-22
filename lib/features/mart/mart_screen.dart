import 'package:flutter/material.dart';

import '../../core/data/app_repository.dart';
import '../../core/data/app_scope.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// WiseMart: grocery marketplace with category filter and cart.
class MartScreen extends StatefulWidget {
  const MartScreen({super.key});

  @override
  State<MartScreen> createState() => _MartScreenState();
}

class _MartScreenState extends State<MartScreen> {
  String _category = 'All';

  List<String> get _categories {
    final set = <String>{'All'};
    for (final p in AppRepository.products) {
      set.add(p.category);
    }
    return set.toList();
  }

  List<Product> get _filtered => _category == 'All'
      ? AppRepository.products
      : AppRepository.products.where((p) => p.category == _category).toList();

  void _checkout() {
    final repo = AppScope.of(context);
    if (repo.cartLines.isEmpty) return;
    final total = repo.cartTotal;
    final ok = repo.charge(
      total,
      title: 'WiseMart Order',
      subtitle: '${repo.cartCount} items',
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient wallet balance')),
      );
      return;
    }
    repo.recordActivity(
      ActivityItem(
        id: 'a_${DateTime.now().microsecondsSinceEpoch}',
        title: 'WiseMart Order',
        subtitle: '${repo.cartCount} items',
        kind: ActivityKind.mart,
        timestamp: DateTime.now(),
        amount: total,
      ),
    );
    repo.clearCart();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order placed — ${cedis(total)}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WiseMart',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Badge(
              isLabelVisible: repo.cartCount > 0,
              label: Text('${repo.cartCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final selected = cat == _category;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: AppColors.accent.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.accent : AppColors.divider,
                  ),
                  backgroundColor: AppColors.surface,
                  showCheckmark: false,
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final product = _filtered[i];
                final qty = repo.cartLines
                    .where((l) => l.product.id == product.id)
                    .fold(0, (sum, l) => sum + l.quantity);
                return _ProductCard(
                  product: product,
                  quantity: qty,
                  onAdd: () => repo.addToCart(product),
                  onRemove: () => repo.removeFromCart(product),
                );
              },
            ),
          ),
          if (repo.cartCount > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${repo.cartCount} items',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        cedis(repo.cartTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _checkout,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                      ),
                      child: const Text('Checkout'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Text(product.emoji, style: const TextStyle(fontSize: 44)),
            ),
          ),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'per ${product.unit}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  cedis(product.price),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              if (quantity == 0)
                _RoundButton(icon: Icons.add, onTap: onAdd)
              else
                Row(
                  children: [
                    _RoundButton(icon: Icons.remove, onTap: onRemove),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _RoundButton(icon: Icons.add, onTap: onAdd),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 16, color: AppColors.accent),
      ),
    );
  }
}
