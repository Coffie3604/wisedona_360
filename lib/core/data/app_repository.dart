import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/auth_service.dart';
import '../models/models.dart';

/// In-memory data source for the Wisedona app.
///
/// The original PWA hardcoded every value in markup. This class is the single
/// seam where a real backend (Firebase Auth + Firestore, or a REST API) plugs
/// in: swap the bodies for network calls and the UI needs no changes.
class AppRepository extends ChangeNotifier {
  AppRepository();

  static const _kBalance = 'wallet.balance';
  static const _kUser = 'session.user';
  static const _kActivity = 'history.activity';
  static const _kTransactions = 'wallet.transactions';

  SharedPreferences? _prefs;

  /// Resolves the preferences store, caching it after the first call.
  ///
  /// Every write goes through here rather than reading `_prefs` directly, so a
  /// repository that is used before [load] still persists correctly.
  Future<SharedPreferences?> _store() async {
    if (_prefs != null) return _prefs;
    try {
      return _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('AppRepository._store failed: $e');
      return null;
    }
  }

  /// Loads persisted state. Safe to call once at startup; failures are
  /// swallowed so a corrupt store never blocks the app from launching.
  Future<void> load() async {
    try {
      _prefs = await _store();
      final rawUser = _prefs!.getString(_kUser);
      if (rawUser != null) {
        final map = jsonDecode(rawUser) as Map<String, dynamic>;
        _user = AppUser(
          id: map['id'] as String,
          name: map['name'] as String,
          phone: map['phone'] as String,
          email: map['email'] as String,
        );
      }
      final savedBalance = _prefs!.getDouble(_kBalance);
      if (savedBalance != null && savedBalance.isFinite) {
        _balance = _roundCedis(savedBalance);
      }
      _restoreList(_kActivity, _activity, ActivityItem.fromJson);
      _restoreList(_kTransactions, _transactions, WalletTransaction.fromJson);
    } catch (e) {
      debugPrint('AppRepository.load failed: $e');
    }
    notifyListeners();
  }

  /// Replaces [target] with the persisted records under [key].
  ///
  /// A single malformed record must not discard the whole history, so each
  /// entry is decoded independently and bad ones are skipped.
  void _restoreList<T>(
    String key,
    List<T> target,
    T Function(Map<String, dynamic>) decode,
  ) {
    final raw = _prefs?.getString(key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final restored = <T>[];
      for (final entry in decoded) {
        try {
          restored.add(decode(entry as Map<String, dynamic>));
        } catch (e) {
          debugPrint('AppRepository._restoreList skipped record: $e');
        }
      }
      if (restored.isNotEmpty) {
        target
          ..clear()
          ..addAll(restored);
      }
    } catch (e) {
      debugPrint('AppRepository._restoreList($key) failed: $e');
    }
  }

  Future<void> _persistList(
    String key,
    List<Map<String, dynamic>> Function() encode,
  ) async {
    try {
      final prefs = await _store();
      await prefs?.setString(key, jsonEncode(encode()));
    } catch (e) {
      debugPrint('AppRepository._persistList($key) failed: $e');
    }
  }

  Future<void> _persistUser() async {
    try {
      final prefs = await _store();
      if (prefs == null) return;
      final user = _user;
      if (user == null) {
        await prefs.remove(_kUser);
      } else {
        await prefs.setString(
          _kUser,
          jsonEncode({
            'id': user.id,
            'name': user.name,
            'phone': user.phone,
            'email': user.email,
          }),
        );
      }
    } catch (e) {
      debugPrint('AppRepository._persistUser failed: $e');
    }
  }

  Future<void> _persistBalance() async {
    try {
      final prefs = await _store();
      await prefs?.setDouble(_kBalance, _balance);
    } catch (e) {
      debugPrint('AppRepository._persistBalance failed: $e');
    }
  }

  // ---------------------------------------------------------------- session

  AppUser? _user;
  AppUser? get user => _user;
  bool get isSignedIn => _user != null;

  /// Optional Firebase Auth backend. When null the repository runs in local
  /// demo mode, which keeps widget tests and offline development working.
  AuthService? _auth;
  set authService(AuthService? value) => _auth = value;

  /// Mirrors a Firebase [User] into the local [AppUser] model.
  void syncFromFirebase(User? fbUser) {
    if (fbUser == null) {
      if (_user == null) return;
      _user = null;
      _persistUser();
      notifyListeners();
      return;
    }
    _user = AppUser(
      id: fbUser.uid,
      name: fbUser.displayName?.trim().isNotEmpty == true
          ? fbUser.displayName!.trim()
          : (fbUser.email?.split('@').first ?? 'Wisedona user'),
      phone: fbUser.phoneNumber ?? '',
      email: fbUser.email ?? '',
    );
    _persistUser();
    notifyListeners();
  }

  /// Signs in. Returns `null` on success or an error message.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      // Local demo mode: accept any well-formed credentials.
      if (email.trim().isEmpty || password.length < 4) {
        return 'Enter a valid email and a password of 4+ characters.';
      }
      _user = AppUser(
        id: 'local_user',
        name: email.split('@').first,
        phone: '',
        email: email.trim(),
      );
      await _persistUser();
      notifyListeners();
      return null;
    }
    final error = await auth.signIn(email: email, password: password);
    if (error == null) syncFromFirebase(auth.currentUser);
    return error;
  }

  /// Registers a new account. Returns `null` on success or an error message.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      if (name.trim().isEmpty || email.trim().isEmpty || password.length < 4) {
        return 'Fill in every field (password 4+ characters).';
      }
      _user = AppUser(
        id: 'local_user',
        name: name.trim(),
        phone: '',
        email: email.trim(),
      );
      await _persistUser();
      notifyListeners();
      return null;
    }
    final error = await auth.register(
      name: name,
      email: email,
      password: password,
    );
    if (error == null) syncFromFirebase(auth.currentUser);
    return error;
  }

  Future<String?> sendPasswordReset(String email) async {
    final auth = _auth;
    if (auth == null) return null;
    return auth.sendPasswordReset(email);
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    _user = null;
    await _persistUser();
    notifyListeners();
  }

  // ----------------------------------------------------------------- wallet

  double _balance = 245.50;
  double get balance => _balance;

  /// Rounds a cedi amount to whole pesewas.
  ///
  /// Binary floating point cannot represent 0.1 exactly, so repeated
  /// additions drift (245.50 + 0.1 + 0.2 => 245.79999999999998). Every
  /// balance mutation funnels through here so the wallet never shows or
  /// persists a sub-pesewa remainder.
  static double _roundCedis(double value) =>
      (value * 100).roundToDouble() / 100;

  final List<WalletTransaction> _transactions = [
    WalletTransaction(
      id: 't1',
      title: 'Ride to Airport',
      subtitle: 'Completed',
      amount: 45.00,
      type: TransactionType.debit,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    WalletTransaction(
      id: 't2',
      title: 'Wallet Top-up',
      subtitle: 'MTN Mobile Money',
      amount: 200.00,
      type: TransactionType.credit,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    WalletTransaction(
      id: 't3',
      title: 'WiseMart Order',
      subtitle: 'Groceries',
      amount: 87.50,
      type: TransactionType.debit,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
    WalletTransaction(
      id: 't4',
      title: 'Delivery Payment',
      subtitle: 'Parcel to Osu',
      amount: 25.00,
      type: TransactionType.debit,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);

  void topUp(double amount) {
    if (!amount.isFinite || amount <= 0) return;
    _balance = _roundCedis(_balance + amount);
    _transactions.insert(
      0,
      WalletTransaction(
        id: 't_${DateTime.now().microsecondsSinceEpoch}',
        title: 'Wallet Top-up',
        subtitle: 'Mobile Money',
        amount: amount,
        type: TransactionType.credit,
        timestamp: DateTime.now(),
      ),
    );
    _persistBalance();
    _persistTransactions();
    notifyListeners();
  }

  bool charge(double amount, {required String title, String subtitle = ''}) {
    if (!amount.isFinite || amount <= 0 || amount > _balance) return false;
    _balance = _roundCedis(_balance - amount);
    _transactions.insert(
      0,
      WalletTransaction(
        id: 't_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        subtitle: subtitle,
        amount: amount,
        type: TransactionType.debit,
        timestamp: DateTime.now(),
      ),
    );
    _persistBalance();
    _persistTransactions();
    notifyListeners();
    return true;
  }

  // --------------------------------------------------------------- activity

  final List<ActivityItem> _activity = [
    ActivityItem(
      id: 'a1',
      title: 'Ride to Airport',
      subtitle: 'Completed • 12.4 km',
      kind: ActivityKind.ride,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      amount: 45.00,
    ),
    ActivityItem(
      id: 'a2',
      title: 'Parcel Delivery',
      subtitle: 'Delivered to Osu',
      kind: ActivityKind.delivery,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      amount: 25.00,
    ),
    ActivityItem(
      id: 'a3',
      title: 'WiseMart Order',
      subtitle: '8 items',
      kind: ActivityKind.mart,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      amount: 87.50,
    ),
  ];

  List<ActivityItem> get activity => List.unmodifiable(_activity);

  void recordActivity(ActivityItem item) {
    _activity.insert(0, item);
    _persistActivity();
    notifyListeners();
  }

  Future<void> _persistActivity() => _persistList(
        _kActivity,
        () => _activity.map((a) => a.toJson()).toList(),
      );

  Future<void> _persistTransactions() => _persistList(
        _kTransactions,
        () => _transactions.map((t) => t.toJson()).toList(),
      );

  // ------------------------------------------------------------------ cart

  final Map<String, CartLine> _cart = {};

  List<CartLine> get cartLines => List.unmodifiable(_cart.values);
  int get cartCount => _cart.values.fold(0, (sum, l) => sum + l.quantity);
  double get cartTotal =>
      _roundCedis(_cart.values.fold(0.0, (sum, l) => sum + l.subtotal));

  void addToCart(Product product) {
    final existing = _cart[product.id];
    _cart[product.id] = existing == null
        ? CartLine(product: product, quantity: 1)
        : existing.copyWith(quantity: existing.quantity + 1);
    notifyListeners();
  }

  void removeFromCart(Product product) {
    final existing = _cart[product.id];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = existing.copyWith(quantity: existing.quantity - 1);
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------ static data

  static const List<RideOption> rideOptions = [
    RideOption(
      id: 'economy',
      name: 'WiseEconomy',
      description: 'Affordable everyday rides',
      icon: 'car',
      baseFare: 8.00,
      perKm: 2.50,
      etaMinutes: 4,
      capacity: 4,
    ),
    RideOption(
      id: 'comfort',
      name: 'WiseComfort',
      description: 'Newer cars, extra legroom',
      icon: 'car_comfort',
      baseFare: 12.00,
      perKm: 3.50,
      etaMinutes: 6,
      capacity: 4,
    ),
    RideOption(
      id: 'xl',
      name: 'WiseXL',
      description: 'Up to 6 passengers',
      icon: 'car_xl',
      baseFare: 18.00,
      perKm: 4.50,
      etaMinutes: 8,
      capacity: 6,
    ),
    RideOption(
      id: 'airport',
      name: 'Airport Run',
      description: 'Fixed fare to Kotoka (ACC)',
      icon: 'plane',
      baseFare: 60.00,
      perKm: 0.00,
      etaMinutes: 10,
      capacity: 4,
    ),
  ];

  static const List<DeliveryOption> deliveryOptions = [
    DeliveryOption(
      id: 'bike',
      name: 'WiseBike',
      description: 'Small parcels, fastest',
      icon: 'bike',
      baseFare: 15.00,
      etaMinutes: 25,
    ),
    DeliveryOption(
      id: 'car',
      name: 'WiseCar',
      description: 'Medium boxes up to 20 kg',
      icon: 'car',
      baseFare: 30.00,
      etaMinutes: 40,
    ),
    DeliveryOption(
      id: 'van',
      name: 'WiseVan',
      description: 'Bulk items up to 200 kg',
      icon: 'van',
      baseFare: 75.00,
      etaMinutes: 60,
    ),
  ];

  static const List<Product> products = [
    Product(
      id: 'p1',
      name: 'Rice (5 kg)',
      category: 'Staples',
      price: 62.00,
      unit: 'bag',
      emoji: '🍚',
    ),
    Product(
      id: 'p2',
      name: 'Cooking Oil (2 L)',
      category: 'Staples',
      price: 48.50,
      unit: 'bottle',
      emoji: '🫗',
    ),
    Product(
      id: 'p3',
      name: 'Tomatoes',
      category: 'Produce',
      price: 18.00,
      unit: 'kg',
      emoji: '🍅',
    ),
    Product(
      id: 'p4',
      name: 'Plantain',
      category: 'Produce',
      price: 22.00,
      unit: 'bunch',
      emoji: '🍌',
    ),
    Product(
      id: 'p5',
      name: 'Fresh Tilapia',
      category: 'Protein',
      price: 55.00,
      unit: 'kg',
      emoji: '🐟',
    ),
    Product(
      id: 'p6',
      name: 'Chicken (whole)',
      category: 'Protein',
      price: 70.00,
      unit: 'bird',
      emoji: '🍗',
    ),
    Product(
      id: 'p7',
      name: 'Bottled Water (pack)',
      category: 'Drinks',
      price: 25.00,
      unit: 'pack',
      emoji: '💧',
    ),
    Product(
      id: 'p8',
      name: 'Sachet Water',
      category: 'Drinks',
      price: 12.00,
      unit: 'bag',
      emoji: '🥤',
    ),
  ];

  static const List<SavedPlace> savedPlaces = [
    SavedPlace(label: 'Home', address: 'East Legon, Accra', icon: 'home'),
    SavedPlace(label: 'Work', address: 'Airport City, Accra', icon: 'work'),
    SavedPlace(label: 'Kotoka Airport', address: 'Accra (ACC)', icon: 'plane'),
  ];
}
