import 'package:flutter/material.dart';

import '../../core/data/app_repository.dart';
import '../../core/data/app_scope.dart';
import '../../core/models/models.dart';
import '../../core/payments/payment_gateway.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// What the top-up sheet collects before the payment is initiated.
class _TopUpRequest {
  const _TopUpRequest({required this.amount, required this.phone});
  final double amount;
  final String phone;
}

/// Shows the "approve on your phone" state and polls the provider until the
/// payment settles, then pops with the final [PaymentIntent].
class _PaymentPromptDialog extends StatefulWidget {
  const _PaymentPromptDialog({required this.repo, required this.initial});

  final AppRepository repo;
  final PaymentIntent initial;

  @override
  State<_PaymentPromptDialog> createState() => _PaymentPromptDialogState();
}

class _PaymentPromptDialogState extends State<_PaymentPromptDialog> {
  late PaymentIntent _intent = widget.initial;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    // Poll a bounded number of times so a stuck prompt cannot spin forever.
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      try {
        final next = await widget.repo.confirmTopUp(_intent.reference);
        if (!mounted) return;
        setState(() => _intent = next);
        if (next.isSettled) {
          if (mounted) Navigator.of(context).pop(next);
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _intent = _intent.copyWith(
              status: PaymentStatus.failed,
              message: 'Could not confirm the payment. Please try again.',
            ));
        Navigator.of(context).pop(_intent);
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _intent.copyWith(
        status: PaymentStatus.failed,
        message: 'Timed out waiting for approval.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '₵${_intent.amountCedis.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _intent.message ?? 'Waiting for confirmation…',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _intent.copyWith(
              status: PaymentStatus.cancelled,
              message: 'Payment cancelled.',
            ),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Wallet: balance, top-up and transaction history.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  Future<void> _topUp(BuildContext context) async {
    final repo = AppScope.of(context);
    final amountController = TextEditingController(text: '50');
    final phoneController = TextEditingController(
      text: repo.user?.phone ?? '',
    );
    final request = await showModalBottomSheet<_TopUpRequest>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Top up wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'You will get a prompt on your phone to approve the payment.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₵)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Money number',
                prefixIcon: Icon(Icons.phone_android_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(
                _TopUpRequest(
                  amount: parseCedis(amountController.text) ?? 0,
                  phone: phoneController.text.trim(),
                ),
              ),
              child: const Text('Send payment prompt'),
            ),
          ],
        ),
      ),
    );
    if (request == null || request.amount <= 0) return;
    if (!context.mounted) return;
    await _runPayment(context, repo, request);
  }

  /// Drives the two-phase payment: initiate, then poll until the provider
  /// settles. The balance only moves once the provider confirms success.
  Future<void> _runPayment(
    BuildContext context,
    AppRepository repo,
    _TopUpRequest request,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    PaymentIntent intent;
    try {
      intent = await repo.startTopUp(
        amount: request.amount,
        phone: request.phone,
      );
    } on PaymentException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!context.mounted) return;
    final settled = await showDialog<PaymentIntent>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaymentPromptDialog(
        repo: repo,
        initial: intent,
      ),
    );

    if (settled == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          settled.status == PaymentStatus.succeeded
              ? 'Added ₵${settled.amountCedis.toStringAsFixed(2)} to your wallet.'
              : settled.message ?? 'Payment was not completed.',
        ),
      ),
    );
  }

  /// Shows the scan-to-pay sheet. A real build would open the camera and
  /// decode a merchant QR; here we surface the user's pay code so the flow is
  /// complete and testable.
  Future<void> _pay(BuildContext context) async {
    final repo = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pay with Wisedona',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Show this code to the merchant, or scan theirs.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 140,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                repo.user?.name ?? 'Wisedona user',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Balance ${cedis(repo.balance)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Wallet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cedis(repo.balance),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _topUp(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Top up'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pay(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Pay'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Transactions',
            subtitle: 'Your wallet history',
          ),
          if (repo.transactions.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long,
              title: 'No transactions',
              message: 'Top up your wallet to get started.',
            )
          else
            ...repo.transactions.map(
              (tx) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionTile(tx: tx),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final color = tx.isCredit ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tx.subtitle} • ${relativeTime(tx.timestamp)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${tx.isCredit ? '+' : '-'}${cedis(tx.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
