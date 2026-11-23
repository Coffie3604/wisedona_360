import 'package:flutter_test/flutter_test.dart';
import 'package:wisedona_360/core/data/app_repository.dart';
import 'package:wisedona_360/core/models/order.dart';
import 'package:wisedona_360/core/payments/payment_gateway.dart';

void main() {
  late AppRepository repo;

  setUp(() async {
    repo = AppRepository();
    await repo.signIn(email: 'rider@wisedona.com', password: 'secret1');
  });

  group('top-up via payment gateway', () {
    test('does not credit the balance while the prompt is pending', () async {
      final before = repo.balance;
      final intent = await repo.startTopUp(amount: 50, phone: '0244123456');
      expect(intent.status, PaymentStatus.pending);
      expect(repo.balance, before, reason: 'pending must not move money');
    });

    test('credits exactly once when the provider confirms', () async {
      final before = repo.balance;
      final intent = await repo.startTopUp(amount: 50, phone: '0244123456');

      // The first verify is still pending (the customer has not approved yet),
      // so no money moves. The UI polls until the intent settles.
      final first = await repo.confirmTopUp(intent.reference);
      expect(first.status, PaymentStatus.pending);
      expect(repo.balance, before);

      final settled = await repo.confirmTopUp(intent.reference);
      expect(settled.status, PaymentStatus.succeeded);
      expect(repo.balance, closeTo(before + 50, 0.001));

      // Replaying the same reference must not double-credit.
      await repo.confirmTopUp(intent.reference);
      expect(repo.balance, closeTo(before + 50, 0.001));
    });

    test('a declined payment leaves the balance untouched', () async {
      repo.paymentGateway =
          MockPaymentGateway(outcome: PaymentStatus.failed, pendingPolls: 0);
      final before = repo.balance;
      final intent = await repo.startTopUp(amount: 50, phone: '0244123456');
      final settled = await repo.confirmTopUp(intent.reference);
      expect(settled.status, PaymentStatus.failed);
      expect(repo.balance, before);
    });

    test('rejects a non-positive amount', () async {
      expect(
        () => repo.startTopUp(amount: 0, phone: '0244123456'),
        throwsA(isA<PaymentException>()),
      );
    });
  });

  group('orders and commission', () {
    test('placing an order charges the customer', () async {
      final before = repo.balance;
      final order = await repo.placeOrder(
        kind: OrderKind.ride,
        title: 'Ride to Airport',
        pickup: 'East Legon',
        dropoff: 'Kotoka',
        fare: 45,
      );
      expect(order, isNotNull);
      expect(repo.balance, closeTo(before - 45, 0.001));
      expect(order!.status, OrderStatus.pending);
    });

    test('an order the wallet cannot cover is rejected', () async {
      final before = repo.balance;
      final order = await repo.placeOrder(
        kind: OrderKind.ride,
        title: 'Impossible ride',
        pickup: 'A',
        dropoff: 'B',
        fare: before + 1000,
      );
      expect(order, isNull);
      expect(repo.balance, before);
    });

    test('commission split adds up to the fare', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        kind: OrderKind.ride,
        title: 't',
        pickup: 'a',
        dropoff: 'b',
        fare: 100,
        status: OrderStatus.pending,
        createdAt: DateTime(2024),
      );
      expect(order.commission, closeTo(18, 0.001));
      expect(order.driverPayout, closeTo(82, 0.001));
      expect(
        order.commission + order.driverPayout,
        closeTo(order.fare, 0.001),
      );
    });

    test('completing an order records commission and pays the driver',
        () async {
      final order = await repo.placeOrder(
        kind: OrderKind.ride,
        title: 'Ride to Airport',
        pickup: 'East Legon',
        dropoff: 'Kotoka',
        fare: 100,
      );
      final driver = repo.availableDrivers.first;
      expect(await repo.acceptOrder(orderId: order!.id, driver: driver), isTrue);

      final split = await repo.completeOrder(order.id);
      expect(split, isNotNull);
      expect(split!.commission, closeTo(18, 0.001));
      expect(split.driverPayout, closeTo(82, 0.001));
      expect(repo.commissionEarned, closeTo(18, 0.001));

      // Settling twice must not pay twice.
      expect(await repo.completeOrder(order.id), isNull);
      expect(repo.commissionEarned, closeTo(18, 0.001));
    });

    test('two drivers cannot accept the same order', () async {
      final order = await repo.placeOrder(
        kind: OrderKind.delivery,
        title: 'Parcel',
        pickup: 'Osu',
        dropoff: 'Labone',
        fare: 25,
      );
      final a = repo.availableDrivers[0];
      final b = repo.availableDrivers[1];
      expect(await repo.acceptOrder(orderId: order!.id, driver: a), isTrue);
      expect(await repo.acceptOrder(orderId: order.id, driver: b), isFalse);
    });

    test('an unverified driver cannot be assigned an order', () async {
      final order = await repo.placeOrder(
        kind: OrderKind.ride,
        title: 'Ride',
        pickup: 'A',
        dropoff: 'B',
        fare: 20,
      );
      const unverified = Driver(
        id: 'dx',
        name: 'Unverified',
        vehicle: 'Bike',
        plate: 'X',
        verified: false,
      );
      expect(
        await repo.acceptOrder(orderId: order!.id, driver: unverified),
        isFalse,
      );
    });

    test('cancelling refunds the customer in full', () async {
      final before = repo.balance;
      final order = await repo.placeOrder(
        kind: OrderKind.mart,
        title: 'Groceries',
        pickup: 'WiseMart',
        dropoff: 'Home',
        fare: 87.50,
      );
      expect(repo.balance, closeTo(before - 87.50, 0.001));
      await repo.cancelOrder(order!.id);
      expect(repo.balance, closeTo(before, 0.001));
    });
  });
}
