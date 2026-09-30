import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';


class PaystackPaymentResult {
  const PaystackPaymentResult({
    required this.status,
    this.reference,
    this.message,
  });

  final String status;
  final String? reference;
  final String? message;

  bool get isSuccess => status == 'success';
  bool get isCancelled => status == 'cancelled';
}

class PaystackPaymentService {
  PaystackPaymentService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<PaystackPaymentResult> payInvoice(String invoiceId) async {
    try {
      // ------------------------------------------------------------
      // 1. Ask Firebase to initialize the Paystack transaction.
      // The Paystack secret key is used only inside Firebase Functions.
      // ------------------------------------------------------------
      final initialize = _functions.httpsCallable(
        'initializePaystackPayment',
      );

      final initialized = await initialize.call<Map<String, dynamic>>({
        'invoiceId': invoiceId,
      });

      final payload = Map<String, dynamic>.from(initialized.data);
      final serverReference = payload['reference']?.toString().trim() ?? '';
      final authorizationUrl =
          payload['authorizationUrl']?.toString().trim() ?? '';

      if (serverReference.isEmpty || authorizationUrl.isEmpty) {
        throw StateError(
          'Paystack did not return a valid checkout URL. Please try again.',
        );
      }

      // ------------------------------------------------------------
      // 2. IMPORTANT: do not call paystack_flutter_sdk.launch() here.
      // That native Android/iOS payment view is what can terminate the
      // installed application before the Paystack page is displayed.
      // Instead, open Paystack's official hosted checkout URL.
      // ------------------------------------------------------------
      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw StateError('Paystack returned an invalid checkout URL.');
      }

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw StateError(
          'Unable to open Paystack checkout. Please install or enable a web browser and try again.',
        );
      }

      // The browser checkout is now active. The screen verifies the
      // reference again when the parent returns to the academy app.
      return PaystackPaymentResult(
        status: 'pending',
        reference: serverReference,
        message: 'Paystack checkout opened. Complete the payment and return to the academy app.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw StateError(
        error.message ?? 'Unable to initialize the Paystack payment.',
      );
    } on PlatformException catch (error) {
      throw StateError(
        error.message ?? 'Paystack checkout could not be opened.',
      );
    }
  }

  /// Verifies a previously initialized transaction after the parent returns
  /// from Paystack's hosted checkout.
  Future<PaystackPaymentResult> verifyPayment(String reference) async {
    final cleanReference = reference.trim();
    if (cleanReference.isEmpty) {
      throw StateError('Payment reference is missing.');
    }

    try {
      final verify = _functions.httpsCallable('verifyPaystackPayment');
      final verified = await verify.call<Map<String, dynamic>>({
        'reference': cleanReference,
      });

      final verification = Map<String, dynamic>.from(verified.data);
      return PaystackPaymentResult(
        status: verification['status']?.toString() ?? 'failed',
        reference: verification['reference']?.toString() ?? cleanReference,
        message: verification['message']?.toString(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw StateError(
        error.message ?? 'Unable to verify the Paystack payment.',
      );
    }
  }
}
