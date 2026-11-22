import 'package:flutter/material.dart';

import '../../core/data/app_repository.dart';
import '../../core/data/app_scope.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// Book Delivery: parcel details, recipient, tier selection and booking.
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _pickup = TextEditingController(text: 'East Legon, Accra');
  final _dropoff = TextEditingController();
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  DeliveryOption _selected = AppRepository.deliveryOptions.first;

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    _recipient.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (_dropoff.text.trim().isEmpty || _recipient.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter destination and recipient')),
      );
      return;
    }
    final repo = AppScope.of(context);
    final ok = repo.charge(
      _selected.baseFare,
      title: 'Delivery to ${_dropoff.text.trim()}',
      subtitle: _selected.name,
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
        title: 'Delivery to ${_dropoff.text.trim()}',
        subtitle: '${_selected.name} • ${_recipient.text.trim()}',
        kind: ActivityKind.delivery,
        timestamp: DateTime.now(),
        amount: _selected.baseFare,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_selected.name} booked — ${cedis(_selected.baseFare)}',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book Delivery',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const SectionHeader(
            title: 'Parcel details',
            subtitle: 'Where is it going?',
          ),
          TextField(
            controller: _pickup,
            decoration: const InputDecoration(
              labelText: 'Pickup address',
              prefixIcon: Icon(Icons.circle, size: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dropoff,
            decoration: const InputDecoration(
              labelText: 'Delivery address',
              hintText: 'e.g. Osu, Accra',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recipient,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Recipient name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Recipient phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Delivery type',
            subtitle: 'Pick the right vehicle',
          ),
          ...AppRepository.deliveryOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DeliveryTile(
                option: option,
                selected: option.id == _selected.id,
                onTap: () => setState(() => _selected = option),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _book,
            icon: const Icon(Icons.delivery_dining),
            label: Text(
              'Book ${_selected.name} — ${cedis(_selected.baseFare)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DeliveryOption option;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (option.icon) {
    'bike' => Icons.two_wheeler,
    'van' => Icons.local_shipping,
    _ => Icons.directions_car,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceAlt : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.highlight : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.highlight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: AppColors.highlight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${option.description} • ~${option.etaMinutes} min',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                cedis(option.baseFare),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
