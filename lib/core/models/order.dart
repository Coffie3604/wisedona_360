/// Marketplace domain: orders, drivers, and the commission split.
///
/// These are the entities that make Wisedona a two-sided business rather than
/// a fare calculator: a rider places an [Order], a [Driver] accepts it, and
/// [CommissionSplit] records what the platform actually earns.
library;

/// What kind of work an order represents.
enum OrderKind { ride, delivery, mart, pharmacy }

/// Lifecycle of an order, from placement to settlement.
///
/// The order is only settled (money moves to the driver) once it reaches
/// [completed]; anything before that can still be cancelled without a payout.
enum OrderStatus {
  /// Placed by the customer, waiting for a driver to accept.
  pending,

  /// A driver has accepted and is on the way.
  accepted,

  /// The trip/delivery is in progress.
  inProgress,

  /// Finished; commission has been taken and the driver is owed a payout.
  completed,

  /// Cancelled before completion; the customer is refunded in full.
  cancelled,
}

/// A single piece of work placed through the platform.
class Order {
  const Order({
    required this.id,
    required this.customerId,
    required this.kind,
    required this.title,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.status,
    required this.createdAt,
    this.driverId,
    this.driverName,
    this.optionId,
    this.distanceKm = 0,
    this.commissionRate = defaultCommissionRate,
  });

  /// Platform take rate. 18% is the mid-point of what Bolt and Glovo charge in
  /// Ghana; it is stored per-order so historical orders keep the rate they
  /// were placed under even if the platform changes its pricing.
  static const double defaultCommissionRate = 0.18;

  final String id;
  final String customerId;
  final OrderKind kind;
  final String title;
  final String pickup;
  final String dropoff;

  /// What the customer pays, in cedis.
  final double fare;

  final OrderStatus status;
  final DateTime createdAt;
  final String? driverId;
  final String? driverName;
  final String? optionId;
  final double distanceKm;
  final double commissionRate;

  /// The platform's cut of [fare].
  double get commission => _round(fare * commissionRate);

  /// What the driver is owed after commission.
  double get driverPayout => _round(fare - commission);

  bool get isOpen =>
      status == OrderStatus.pending ||
      status == OrderStatus.accepted ||
      status == OrderStatus.inProgress;

  bool get isSettled =>
      status == OrderStatus.completed || status == OrderStatus.cancelled;

  Order copyWith({
    OrderStatus? status,
    String? driverId,
    String? driverName,
  }) =>
      Order(
        id: id,
        customerId: customerId,
        kind: kind,
        title: title,
        pickup: pickup,
        dropoff: dropoff,
        fare: fare,
        status: status ?? this.status,
        createdAt: createdAt,
        driverId: driverId ?? this.driverId,
        driverName: driverName ?? this.driverName,
        optionId: optionId,
        distanceKm: distanceKm,
        commissionRate: commissionRate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'kind': kind.name,
        'title': title,
        'pickup': pickup,
        'dropoff': dropoff,
        'fare': fare,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'driverId': driverId,
        'driverName': driverName,
        'optionId': optionId,
        'distanceKm': distanceKm,
        'commissionRate': commissionRate,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        customerId: json['customerId'] as String? ?? '',
        kind: OrderKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => OrderKind.ride,
        ),
        title: json['title'] as String? ?? '',
        pickup: json['pickup'] as String? ?? '',
        dropoff: json['dropoff'] as String? ?? '',
        fare: (json['fare'] as num?)?.toDouble() ?? 0,
        status: OrderStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => OrderStatus.pending,
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        driverId: json['driverId'] as String?,
        driverName: json['driverName'] as String?,
        optionId: json['optionId'] as String?,
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
        commissionRate: (json['commissionRate'] as num?)?.toDouble() ??
            defaultCommissionRate,
      );
}

/// A driver on the supply side of the marketplace.
class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.vehicle,
    required this.plate,
    this.rating = 5.0,
    this.tripsCompleted = 0,
    this.isOnline = false,
    this.verified = false,
  });

  final String id;
  final String name;
  final String vehicle;
  final String plate;
  final double rating;
  final int tripsCompleted;
  final bool isOnline;

  /// Whether the driver has passed KYC. Unverified drivers cannot be assigned
  /// orders — this is the compliance gate, not a cosmetic flag.
  final bool verified;

  Driver copyWith({bool? isOnline, int? tripsCompleted}) => Driver(
        id: id,
        name: name,
        vehicle: vehicle,
        plate: plate,
        rating: rating,
        tripsCompleted: tripsCompleted ?? this.tripsCompleted,
        isOnline: isOnline ?? this.isOnline,
        verified: verified,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'vehicle': vehicle,
        'plate': plate,
        'rating': rating,
        'tripsCompleted': tripsCompleted,
        'isOnline': isOnline,
        'verified': verified,
      };

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        vehicle: json['vehicle'] as String? ?? '',
        plate: json['plate'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        tripsCompleted: (json['tripsCompleted'] as num?)?.toInt() ?? 0,
        isOnline: json['isOnline'] as bool? ?? false,
        verified: json['verified'] as bool? ?? false,
      );
}

/// The money split for one settled order.
///
/// Kept as its own record so the platform's earnings are auditable
/// independently of the order document.
class CommissionSplit {
  const CommissionSplit({
    required this.orderId,
    required this.gross,
    required this.commission,
    required this.driverPayout,
    required this.rate,
    required this.settledAt,
  });

  final String orderId;
  final double gross;
  final double commission;
  final double driverPayout;
  final double rate;
  final DateTime settledAt;

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'gross': gross,
        'commission': commission,
        'driverPayout': driverPayout,
        'rate': rate,
        'settledAt': settledAt.toIso8601String(),
      };

  factory CommissionSplit.fromJson(Map<String, dynamic> json) =>
      CommissionSplit(
        orderId: json['orderId'] as String,
        gross: (json['gross'] as num?)?.toDouble() ?? 0,
        commission: (json['commission'] as num?)?.toDouble() ?? 0,
        driverPayout: (json['driverPayout'] as num?)?.toDouble() ?? 0,
        rate: (json['rate'] as num?)?.toDouble() ?? 0,
        settledAt:
            DateTime.tryParse(json['settledAt'] as String? ?? '') ??
                DateTime.now(),
      );
}

/// Rounds to whole pesewas, matching the wallet's rounding rule.
double _round(double value) => (value * 100).roundToDouble() / 100;
