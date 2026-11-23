/// Firestore-backed persistence for orders, drivers, and commission records.
///
/// This is the backend the repository seam was left for. Every method degrades
/// gracefully: if Firestore is unavailable (offline, or no Firebase project
/// configured) the caller falls back to the local store rather than crashing.
library;

// Firestore exports its own `Order` (a query-ordering enum), which collides
// with our marketplace `Order` model. Hide theirs.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/order.dart';

/// Collection names, kept in one place so security rules and code agree.
class Collections {
  static const orders = 'orders';
  static const drivers = 'drivers';
  static const commissions = 'commissions';
  static const wallets = 'wallets';
  static const users = 'users';
}

/// Reads and writes marketplace state in Firestore.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  bool _available = true;

  /// False once a call has failed for a non-transient reason, so the UI can
  /// show "offline mode" instead of retrying forever.
  bool get isAvailable => _available;

  // ----------------------------------------------------------------- orders

  /// Publishes a new order so drivers on other devices can see it.
  Future<void> createOrder(Order order) async {
    await _guard('createOrder', () async {
      await _db
          .collection(Collections.orders)
          .doc(order.id)
          .set(order.toJson());
    });
  }

  /// Live stream of open orders for the driver feed.
  ///
  /// Only [OrderStatus.pending] orders are broadcast; once a driver accepts,
  /// the order leaves the public feed.
  Stream<List<Order>> watchOpenOrders() {
    return _db
        .collection(Collections.orders)
        .where('status', isEqualTo: OrderStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Order.fromJson(d.data()))
            .toList(growable: false))
        .handleError((Object e) {
      debugPrint('FirestoreService.watchOpenOrders failed: $e');
      _available = false;
      return <Order>[];
    });
  }

  /// Live stream of a customer's own orders, newest first.
  Stream<List<Order>> watchCustomerOrders(String customerId) {
    return _db
        .collection(Collections.orders)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Order.fromJson(d.data()))
            .toList(growable: false))
        .handleError((Object e) {
      debugPrint('FirestoreService.watchCustomerOrders failed: $e');
      _available = false;
      return <Order>[];
    });
  }

  /// Live stream of the orders assigned to one driver.
  Stream<List<Order>> watchDriverOrders(String driverId) {
    return _db
        .collection(Collections.orders)
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Order.fromJson(d.data()))
            .toList(growable: false))
        .handleError((Object e) {
      debugPrint('FirestoreService.watchDriverOrders failed: $e');
      _available = false;
      return <Order>[];
    });
  }

  /// Atomically claims an order for [driver].
  ///
  /// Uses a transaction so two drivers tapping "Accept" at the same moment
  /// cannot both win: the second read sees `status != pending` and aborts.
  /// Returns true if this driver got the order.
  Future<bool> acceptOrder({
    required String orderId,
    required String driverId,
    required String driverName,
  }) async {
    try {
      return await _db.runTransaction<bool>((tx) async {
        final ref = _db.collection(Collections.orders).doc(orderId);
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final data = snap.data()!;
        if (data['status'] != OrderStatus.pending.name) return false;
        tx.update(ref, {
          'status': OrderStatus.accepted.name,
          'driverId': driverId,
          'driverName': driverName,
        });
        return true;
      });
    } catch (e) {
      debugPrint('FirestoreService.acceptOrder failed: $e');
      _available = false;
      return false;
    }
  }

  /// Moves an order to [status].
  Future<void> updateStatus(String orderId, OrderStatus status) async {
    await _guard('updateStatus', () async {
      await _db.collection(Collections.orders).doc(orderId).update({
        'status': status.name,
      });
    });
  }

  // ---------------------------------------------------------------- drivers

  Future<void> upsertDriver(Driver driver) async {
    await _guard('upsertDriver', () async {
      await _db
          .collection(Collections.drivers)
          .doc(driver.id)
          .set(driver.toJson(), SetOptions(merge: true));
    });
  }

  /// Drivers who are online and KYC-verified — the only ones eligible for
  /// dispatch.
  Stream<List<Driver>> watchAvailableDrivers() {
    return _db
        .collection(Collections.drivers)
        .where('isOnline', isEqualTo: true)
        .where('verified', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Driver.fromJson(d.data()))
            .toList(growable: false))
        .handleError((Object e) {
      debugPrint('FirestoreService.watchAvailableDrivers failed: $e');
      _available = false;
      return <Driver>[];
    });
  }

  // -------------------------------------------------------------- commission

  /// Records the platform's cut for a completed order.
  Future<void> recordCommission(CommissionSplit split) async {
    await _guard('recordCommission', () async {
      await _db
          .collection(Collections.commissions)
          .doc(split.orderId)
          .set(split.toJson());
    });
  }

  /// Total commission earned, summed client-side.
  ///
  /// Fine at prototype scale; a production build would keep a running total
  /// in a `stats/` document updated by a Cloud Function.
  Future<double> totalCommission() async {
    try {
      final snap = await _db.collection(Collections.commissions).get();
      return snap.docs.fold<double>(
        0,
        (running, d) =>
            running + ((d.data()['commission'] as num?)?.toDouble() ?? 0),
      );
    } catch (e) {
      debugPrint('FirestoreService.totalCommission failed: $e');
      _available = false;
      return 0;
    }
  }

  // ----------------------------------------------------------------- wallet

  /// Mirrors the wallet balance to Firestore so it survives a reinstall.
  Future<void> saveBalance(String userId, double balance) async {
    await _guard('saveBalance', () async {
      await _db.collection(Collections.wallets).doc(userId).set({
        'balance': balance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Reads the persisted balance, or null if the user has no wallet yet.
  Future<double?> loadBalance(String userId) async {
    try {
      final snap =
          await _db.collection(Collections.wallets).doc(userId).get();
      if (!snap.exists) return null;
      return (snap.data()?['balance'] as num?)?.toDouble();
    } catch (e) {
      debugPrint('FirestoreService.loadBalance failed: $e');
      _available = false;
      return null;
    }
  }

  /// Appends a wallet transaction to the user's ledger.
  Future<void> recordTransaction(
    String userId,
    WalletTransaction tx,
  ) async {
    await _guard('recordTransaction', () async {
      await _db
          .collection(Collections.users)
          .doc(userId)
          .collection('transactions')
          .doc(tx.id)
          .set(tx.toJson());
    });
  }

  /// Runs [action], swallowing and logging failures so a backend outage never
  /// takes down the UI.
  Future<void> _guard(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('FirestoreService.$label failed: $e');
      _available = false;
    }
  }
}
