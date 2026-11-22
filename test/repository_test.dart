import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wisedona_360/core/data/app_repository.dart';
import 'package:wisedona_360/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('session', () {
    test('signIn rejects a short password', () async {
      final repo = AppRepository();
      final error = await repo.signIn(
        email: 'ama@example.com',
        password: '123',
      );
      expect(error, isNotNull);
      expect(repo.isSignedIn, isFalse);
    });

    test('signIn succeeds and persists across a reload', () async {
      final repo = AppRepository();
      final error = await repo.signIn(
        email: 'ama@example.com',
        password: 'secret',
      );
      expect(error, isNull);
      expect(repo.user!.email, 'ama@example.com');

      final restored = AppRepository();
      await restored.load();
      expect(restored.isSignedIn, isTrue);
      expect(restored.user!.email, 'ama@example.com');
    });

    test('register rejects an empty name', () async {
      final repo = AppRepository();
      final error = await repo.register(
        name: '  ',
        email: 'ama@example.com',
        password: 'secret',
      );
      expect(error, isNotNull);
      expect(repo.isSignedIn, isFalse);
    });

    test('signOut clears the persisted session', () async {
      final repo = AppRepository();
      await repo.signIn(email: 'ama@example.com', password: 'secret');
      await repo.signOut();

      final restored = AppRepository();
      await restored.load();
      expect(restored.isSignedIn, isFalse);
    });
  });

  group('wallet', () {
    test('topUp increases the balance and records a credit', () {
      final repo = AppRepository();
      final before = repo.balance;
      repo.topUp(50);

      expect(repo.balance, before + 50);
      expect(repo.transactions.first.isCredit, isTrue);
      expect(repo.transactions.first.amount, 50);
    });

    test('topUp ignores non-positive amounts', () {
      final repo = AppRepository();
      final before = repo.balance;
      repo.topUp(0);
      repo.topUp(-10);
      expect(repo.balance, before);
    });

    test('charge refuses to overdraw', () {
      final repo = AppRepository();
      expect(repo.charge(repo.balance + 1, title: 'Too much'), isFalse);
      expect(repo.balance, 245.50);
    });

    test('charge debits and records a transaction', () {
      final repo = AppRepository();
      expect(repo.charge(45, title: 'Ride to Airport'), isTrue);
      expect(repo.balance, 200.50);
      expect(repo.transactions.first.title, 'Ride to Airport');
      expect(repo.transactions.first.isCredit, isFalse);
    });

    test('topUp ignores non-finite amounts', () {
      final repo = AppRepository();
      final before = repo.balance;
      repo.topUp(double.nan);
      repo.topUp(double.infinity);
      repo.topUp(double.negativeInfinity);
      expect(repo.balance, before);
    });

    test('charge rejects non-finite amounts without touching the balance', () {
      final repo = AppRepository();
      final before = repo.balance;
      expect(repo.charge(double.nan, title: 'NaN'), isFalse);
      expect(repo.charge(double.infinity, title: 'Inf'), isFalse);
      expect(repo.balance, before);
      expect(repo.transactions.first.title, isNot('NaN'));
    });

    test('balance stays exact to the pesewa across repeated mutations', () {
      final repo = AppRepository();
      repo.topUp(0.1);
      repo.topUp(0.2);
      // 245.50 + 0.1 + 0.2 drifts to 245.79999999999998 without rounding.
      expect(repo.balance, 245.80);

      expect(repo.charge(0.3, title: 'Exact'), isTrue);
      expect(repo.balance, 245.50);
    });

    test('balance survives a reload', () async {
      final repo = AppRepository();
      repo.topUp(100);
      // topUp persists fire-and-forget; let the write land.
      await Future<void>.delayed(Duration.zero);

      final restored = AppRepository();
      await restored.load();
      expect(restored.balance, 345.50);
    });
  });

  group('cart', () {
    test('adding the same product increments quantity', () {
      final repo = AppRepository();
      final product = AppRepository.products.first;

      repo.addToCart(product);
      repo.addToCart(product);

      expect(repo.cartCount, 2);
      expect(repo.cartLines.single.quantity, 2);
      expect(repo.cartTotal, product.price * 2);
    });

    test('cartTotal is exact to the pesewa', () {
      final repo = AppRepository();
      // 48.50 x 3 = 145.50; naive float sums can land on 145.49999999999997.
      for (var i = 0; i < 3; i++) {
        repo.addToCart(AppRepository.products[1]);
      }
      expect(repo.cartTotal, 145.50);
    });

    test('removing the last unit drops the line', () {
      final repo = AppRepository();
      final product = AppRepository.products.first;

      repo.addToCart(product);
      repo.removeFromCart(product);

      expect(repo.cartLines, isEmpty);
      expect(repo.cartTotal, 0);
    });
  });

  group('activity', () {
    test('recordActivity puts the newest item first', () {
      final repo = AppRepository();
      final before = repo.activity.length;

      repo.recordActivity(
        ActivityItem(
          id: 'new',
          title: 'Test ride',
          subtitle: 'Completed',
          kind: ActivityKind.ride,
          timestamp: DateTime.now(),
        ),
      );

      expect(repo.activity.length, before + 1);
      expect(repo.activity.first.id, 'new');
    });
  });
}
