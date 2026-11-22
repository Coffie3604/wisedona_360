/// Domain models for the Wisedona super-app.
///
/// These mirror the entities the original PWA hardcoded in markup, now
/// expressed as real types so they can be backed by a service layer.
library;

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.avatarUrl,
    this.rating = 5.0,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String? avatarUrl;
  final double rating;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// A ride tier offered on the Book a Ride screen.
class RideOption {
  const RideOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.baseFare,
    required this.perKm,
    required this.etaMinutes,
    required this.capacity,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final double baseFare;
  final double perKm;
  final int etaMinutes;
  final int capacity;

  double fareFor(double km) => baseFare + (perKm * km);
}

/// A delivery tier offered on the Book Delivery screen.
class DeliveryOption {
  const DeliveryOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.baseFare,
    required this.etaMinutes,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final double baseFare;
  final int etaMinutes;
}

/// A WiseMart product.
class Product {
  const Product({
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

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);
}

enum TransactionType { credit, debit }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final TransactionType type;
  final DateTime timestamp;

  bool get isCredit => type == TransactionType.credit;
}

enum ActivityKind { ride, delivery, mart, wallet }

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.timestamp,
    this.amount,
  });

  final String id;
  final String title;
  final String subtitle;
  final ActivityKind kind;
  final DateTime timestamp;
  final double? amount;
}

/// A saved place (home, work, etc.).
class SavedPlace {
  const SavedPlace({
    required this.label,
    required this.address,
    required this.icon,
  });

  final String label;
  final String address;
  final String icon;
}
