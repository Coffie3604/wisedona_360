import 'package:flutter/material.dart';

import '../../core/data/app_scope.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

/// A single over-the-counter medicine available for delivery.
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    required this.emoji,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final String unit;
  final String emoji;
}

/// Pharmacy: browse medicines by category and order for delivery.
class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  static const List<Medicine> medicines = [
    Medicine(
      id: 'm1',
      name: 'Paracetamol 500mg',
      category: 'Pain Relief',
      price: 12,
      unit: 'pack of 20',
      emoji: '💊',
    ),
    Medicine(
      id: 'm2',
      name: 'Ibuprofen 400mg',
      category: 'Pain Relief',
      price: 18,
      unit: 'pack of 16',
      emoji: '💊',
    ),
    Medicine(
      id: 'm3',
      name: 'Vitamin C 1000mg',
      category: 'Vitamins',
      price: 35,
      unit: 'pack of 30',
      emoji: '🍊',
    ),
    Medicine(
      id: 'm4',
      name: 'Multivitamin Syrup',
      category: 'Vitamins',
      price: 42,
      unit: '200ml bottle',
      emoji: '🧴',
    ),
    Medicine(
      id: 'm5',
      name: 'Cough Syrup',
      category: 'Cold & Flu',
      price: 28,
      unit: '100ml bottle',
      emoji: '🧴',
    ),
    Medicine(
      id: 'm6',
      name: 'Antiseptic Wipes',
      category: 'First Aid',
      price: 15,
      unit: 'pack of 40',
      emoji: '🩹',
    ),
    Medicine(
      id: 'm7',
      name: 'Digital Thermometer',
      category: 'First Aid',
      price: 65,
      unit: 'each',
      emoji: '🌡️',
    ),
    Medicine(
      id: 'm8',
      name: 'Oral Rehydration Salts',
      category: 'First Aid',
      price: 10,
      unit: 'pack of 5',
      emoji: '💧',
    ),
  ];

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  String _category = 'All';
  final Map<String, int> _cart = {};

  List<String> get _categories {
    final set = <String>{'All'};
    for (final m in PharmacyScreen.medicines) {
      set.add(m.category);
    }
    return set.toList();
  }

  List<Medicine> get _filtered => _category == 'All'
      ? PharmacyScreen.medicines
      : PharmacyScreen.medicines.where((m) => m.category == _category).toList();

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  double get _cartTotal => _cart.entries.fold(0.0, (sum, e) {
    final med = PharmacyScreen.medicines.firstWhere((m) => m.id == e.key);
    return sum + med.price * e.value;
  });

  void _add(Medicine med) {
    setState(() => _cart[med.id] = (_cart[med.id] ?? 0) + 1);
  }

  void _remove(Medicine med) {
    setState(() {
      final next = (_cart[med.id] ?? 0) - 1;
      if (next <= 0) {
        _cart.remove(med.id);
      } else {
        _cart[med.id] = next;
      }
    });
  }

  void _checkout() {
    if (_cart.isEmpty) return;
    final repo = AppScope.of(context);
    final total = _cartTotal;
    final count = _cartCount;
    final ok = repo.charge(
      total,
      title: 'Pharmacy Order',
      subtitle: '$count items',
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
        title: 'Pharmacy Order',
        subtitle: '$count items',
        kind: ActivityKind.mart,
        timestamp: DateTime.now(),
        amount: total,
      ),
    );
    setState(_cart.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order placed — ₵${total.toStringAsFixed(2)}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  final selected = c == _category;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = c),
                    selectedColor: AppColors.primary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final med = _filtered[i];
                  final qty = _cart[med.id] ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            med.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${med.unit} · ₵${med.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (qty == 0)
                          IconButton.filled(
                            onPressed: () => _add(med),
                            icon: const Icon(Icons.add, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                          )
                        else
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _remove(med),
                                icon: const Icon(Icons.remove_circle_outline),
                                color: AppColors.primary,
                              ),
                              Text(
                                '$qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _add(med),
                                icon: const Icon(Icons.add_circle_outline),
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: FilledButton(
                  onPressed: _checkout,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    'Checkout · $_cartCount items · '
                    '₵${_cartTotal.toStringAsFixed(2)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
