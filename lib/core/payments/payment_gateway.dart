/// Payment rail abstraction.
///
/// The wallet is only real if money actually moves. This file defines the
/// contract every provider implements, plus a [MockPaymentGateway] used in
/// tests and offline development.
///
/// A production build plugs in Paystack (card + MoMo) or Hubtel (MTN MoMo,
/// Vodafone Cash, AirtelTigo) by implementing [PaymentGateway] and passing it
/// to `AppRepository.paymentGateway`. Nothing else in the app changes.
library;

import 'dart:async';
import 'dart:math';

/// A payment provider capable of charging a customer in cedis.
abstract class PaymentGateway {
  /// Human-readable provider name, shown on the top-up sheet.
  String get name;

  /// Starts a top-up of [amountCedis] against [phone] (a MoMo number) or a
  /// card, depending on the provider.
  ///
  /// Returns a [PaymentIntent]. For MoMo the intent is usually
  /// [PaymentStatus.pending] until the customer approves the prompt on their
  /// phone; for cards it resolves immediately.
  Future<PaymentIntent> initiateTopUp({
    required double amountCedis,
    required String phone,
    String? email,
  });

  /// Polls the provider for the current state of [reference].
  ///
  /// The wallet credits the balance only when this returns
  /// [PaymentStatus.succeeded] — never on [initiateTopUp] alone, because a
  /// pending MoMo prompt can still be declined.
  Future<PaymentIntent> verify(String reference);

  /// Sends a driver their payout. Returns the provider reference on success.
  Future<String> payout({
    required double amountCedis,
    required String phone,
    required String orderId,
  });
}

enum PaymentStatus { pending, succeeded, failed, cancelled }

/// The result of a payment attempt.
class PaymentIntent {
  const PaymentIntent({
    required this.reference,
    required this.status,
    required this.amountCedis,
    this.message,
  });

  final String reference;
  final PaymentStatus status;
  final double amountCedis;
  final String? message;

  bool get isSettled =>
      status == PaymentStatus.succeeded ||
      status == PaymentStatus.failed ||
      status == PaymentStatus.cancelled;

  PaymentIntent copyWith({PaymentStatus? status, String? message}) =>
      PaymentIntent(
        reference: reference,
        status: status ?? this.status,
        amountCedis: amountCedis,
        message: message ?? this.message,
      );
}

/// Raised when a provider rejects a request outright (bad number, amount out
/// of range, provider outage). Distinct from a declined payment, which is a
/// normal [PaymentIntent] with [PaymentStatus.failed].
class PaymentException implements Exception {
  const PaymentException(this.message);
  final String message;

  @override
  String toString() => 'PaymentException: $message';
}

/// In-memory gateway for tests and offline development.
///
/// Simulates a MoMo prompt: the first [verify] after [initiateTopUp] returns
/// [PaymentStatus.pending], the second returns the configured outcome. This
/// exercises the real two-phase flow so the wallet code is tested against the
/// same shape a live provider produces.
class MockPaymentGateway implements PaymentGateway {
  MockPaymentGateway({
    this.outcome = PaymentStatus.succeeded,
    this.pendingPolls = 1,
  });

  /// What the simulated prompt resolves to.
  final PaymentStatus outcome;

  /// How many [verify] calls return `pending` before resolving.
  final int pendingPolls;

  final Map<String, int> _polls = {};
  final Map<String, PaymentIntent> _intents = {};
  final Random _random = Random();

  @override
  String get name => 'Mock MoMo';

  @override
  Future<PaymentIntent> initiateTopUp({
    required double amountCedis,
    required String phone,
    String? email,
  }) async {
    if (amountCedis <= 0) {
      throw const PaymentException('Amount must be greater than zero.');
    }
    if (phone.trim().length < 9) {
      throw const PaymentException('Enter a valid mobile money number.');
    }
    final ref = 'mock_${DateTime.now().microsecondsSinceEpoch}'
        '_${_random.nextInt(9999)}';
    final intent = PaymentIntent(
      reference: ref,
      status: PaymentStatus.pending,
      amountCedis: amountCedis,
      message: 'Approve the prompt on your phone.',
    );
    _intents[ref] = intent;
    _polls[ref] = 0;
    return intent;
  }

  @override
  Future<PaymentIntent> verify(String reference) async {
    final intent = _intents[reference];
    if (intent == null) {
      throw PaymentException('Unknown payment reference: $reference');
    }
    final polls = (_polls[reference] ?? 0) + 1;
    _polls[reference] = polls;
    if (polls <= pendingPolls) return intent;
    final resolved = intent.copyWith(
      status: outcome,
      message: outcome == PaymentStatus.succeeded
          ? 'Payment received.'
          : 'Payment was not completed.',
    );
    _intents[reference] = resolved;
    return resolved;
  }

  @override
  Future<String> payout({
    required double amountCedis,
    required String phone,
    required String orderId,
  }) async {
    if (amountCedis <= 0) {
      throw const PaymentException('Payout amount must be positive.');
    }
    return 'mockpayout_${orderId}_${DateTime.now().microsecondsSinceEpoch}';
  }
}
