import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../constants/app_colors.dart';
import '../../data/paystack_payment_service.dart';
import '../../models/invoice.dart';

class PayInvoiceScreen extends StatefulWidget {
  const PayInvoiceScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<PayInvoiceScreen> createState() => _PayInvoiceScreenState();
}

class _PayInvoiceScreenState extends State<PayInvoiceScreen> with WidgetsBindingObserver {
  final _service = PaystackPaymentService();
  bool _loading = false;
  String? _pendingReference;
  bool _verifyingReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingReference != null) {
      _verifyReturnedPayment();
    }
  }

  Future<void> _verifyReturnedPayment() async {
    if (_verifyingReturn || _pendingReference == null || !mounted) return;
    _verifyingReturn = true;
    try {
      final result = await _service.verifyPayment(_pendingReference!);
      if (!mounted) return;
      if (result.isSuccess) {
        _pendingReference = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Payment verified successfully.'),
          ),
        );
        Navigator.of(context).pop(true);
      } else if (result.status == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Payment is still pending. If you completed payment, please wait a moment and return again.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text(error.toString().replaceFirst('StateError: ', '')),
        ),
      );
    } finally {
      _verifyingReturn = false;
    }
  }

  Future<void> _pay() async {
    if (_loading || widget.invoice.isPaid) return;
    setState(() => _loading = true);

    try {
      final result = await _service.payInvoice(widget.invoice.id);
      if (!mounted) return;

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Payment verified successfully.'),
          ),
        );
        Navigator.of(context).pop(true);
      } else if (result.status == 'pending' && result.reference != null) {
        _pendingReference = result.reference;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
            content: Text('Paystack checkout opened. Complete payment in your browser, then return to this app.'),
          ),
        );
      } else {
        throw StateError(
          result.message?.isNotEmpty == true
              ? result.message!
              : 'Payment could not be completed.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text(error.toString().replaceFirst('StateError: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final amount = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 2,
    ).format(invoice.balance);

    return Scaffold(
      appBar: AppBar(title: const Text('Secure payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 26,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'PAYSTACK',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                const Text(
                  'Amount due',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  invoice.title,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _DetailRow(label: 'Invoice', value: invoice.invoiceNumber),
                  const Divider(height: 24),
                  _DetailRow(label: 'Player', value: invoice.playerName.isEmpty ? 'Player' : invoice.playerName),
                  const Divider(height: 24),
                  _DetailRow(label: 'Due date', value: DateFormat('d MMM yyyy').format(invoice.dueDate)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: .10)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your payment is verified on the academy server before the invoice is marked paid.',
                    style: TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _pay,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(_loading ? 'Opening secure checkout…' : 'Pay $amount'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
