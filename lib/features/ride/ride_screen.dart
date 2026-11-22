import 'package:flutter/material.dart';

import '../../core/data/app_repository.dart';
import '../../core/data/app_scope.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// Book a Ride: pickup/dropoff, ride tiers, fare estimate and booking.
class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final _pickup = TextEditingController(text: 'East Legon, Accra');
  final _dropoff = TextEditingController();
  RideOption _selected = AppRepository.rideOptions.first;
  double _distanceKm = 8.0;

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (_dropoff.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination first')),
      );
      return;
    }
    final repo = AppScope.of(context);
    final fare = _selected.fareFor(_distanceKm);
    final ok = repo.charge(
      fare,
      title: 'Ride to ${_dropoff.text.trim()}',
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
        title: 'Ride to ${_dropoff.text.trim()}',
        subtitle: '${_selected.name} • ${_distanceKm.toStringAsFixed(1)} km',
        kind: ActivityKind.ride,
        timestamp: DateTime.now(),
        amount: fare,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selected.name} booked — ${cedis(fare)}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book a Ride',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _LocationCard(pickup: _pickup, dropoff: _dropoff),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Choose a ride',
            subtitle: 'Fares are estimates',
          ),
          ...AppRepository.rideOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RideTile(
                option: option,
                distanceKm: _distanceKm,
                selected: option.id == _selected.id,
                onTap: () => setState(() => _selected = option),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Distance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _distanceKm,
                  min: 1,
                  max: 40,
                  divisions: 39,
                  label: '${_distanceKm.toStringAsFixed(0)} km',
                  onChanged: (v) => setState(() => _distanceKm = v),
                ),
              ),
              Text(
                '${_distanceKm.toStringAsFixed(0)} km',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text(
                  'Estimated fare',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  cedis(_selected.fareFor(_distanceKm)),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _book,
            icon: const Icon(Icons.local_taxi),
            label: Text('Book ${_selected.name}'),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.pickup, required this.dropoff});

  final TextEditingController pickup;
  final TextEditingController dropoff;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: pickup,
                  decoration: const InputDecoration(
                    labelText: 'Pickup',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Divider(height: 20),
          ),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 14,
                color: AppColors.highlight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: dropoff,
                  decoration: const InputDecoration(
                    labelText: 'Where to?',
                    hintText: 'e.g. Osu, Accra',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile({
    required this.option,
    required this.distanceKm,
    required this.selected,
    required this.onTap,
  });

  final RideOption option;
  final double distanceKm;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (option.icon) {
    'plane' => Icons.flight,
    'car_xl' => Icons.airport_shuttle,
    'car_comfort' => Icons.directions_car_filled,
    _ => Icons.local_taxi,
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
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: AppColors.primary),
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
                      '${option.description} • ${option.etaMinutes} min away',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cedis(option.fareFor(distanceKm)),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${option.capacity} seats',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
