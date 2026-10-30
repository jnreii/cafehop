import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cafehop/models/nets_state.dart';
import 'package:cafehop/services/nets_service.dart';

final netsServiceProvider = Provider((ref) {
  return NETSService();
});

final netsProvider =
    StateNotifierProvider.autoDispose<NetsNotifier, NetsState>((ref) {
  return NetsNotifier(ref.read(netsServiceProvider));
});

class NetsNotifier extends StateNotifier<NetsState> {
  final NETSService _service;
  Timer? _timer;
  StreamSubscription? _webhookSub;

  bool _isCheckingPayment = false;

  //stores SSE chunks together so a payment update isnt missed
  //if NETS splits one event across multiple chunks
  String _webhookBuffer = '';

  NetsNotifier(this._service) : super(NetsState());

  //generateQR() - calls requestQR from the service, decodes and stores the
  //qr code + txn ref in state, then starts the timer and webhook listener
  Future generateQR(double amount) async {
    _timer?.cancel();
    _webhookSub?.cancel();

    state = NetsState(status: 'loading');

    final result = await _service.requestQR(amount);

    if (result.isEmpty || result['qrCode'] == null) {
      state = state.copyWith(
        status: 'fail',
        message: 'Could not generate a QR code. Please try again.',
      );
      return;
    }

    final qrBytes = base64Decode(result['qrCode']);
    final txnRef = result['txnRef'] as String;

    state = state.copyWith(
      status: 'idle',
      qrCode: qrBytes,
      txnRef: txnRef,
      timeLeft: 180, //3 minutes, follows the NETS lab timeout flow
    );

    startTimer(txnRef);
    startWebhookListener(txnRef);
  }

  //startTimer(txnRef) - runs a 1 second countdown and updates timeLeft,
  //calls checkPayment() when time runs out
  void startTimer(String txnRef) {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeLeft <= 1) {
        timer.cancel();
        checkPayment(txnRef);
      } else {
        state = state.copyWith(timeLeft: state.timeLeft - 1);
      }
    });
  }

  //startWebhookListener(txnRef) to listens to the SSE stream and detects
  //events like "QR code scanned" by updates state.message
  //once NETS sends a completed transaction event, checkPayment() verifies
  //the final result immediately instead of waiting for the 3 minute timer
  void startWebhookListener(String txnRef) {
    _webhookSub?.cancel();
    _webhookBuffer = '';

    _webhookSub = _service.webhookStream(txnRef).listen(
      (chunk) {
        if (state.status != 'idle') return;

        //SSE data can arrive split across multiple chunks
        _webhookBuffer += chunk;
        final webhookData = _webhookBuffer.toLowerCase();

        if (webhookData.contains('scanned')) {
          state = state.copyWith(
            message: 'QR code scanned',
          );
        }

        //NETS has sent a transaction result, verify it immediately
        if (webhookData.contains('response_code')) {
          _webhookBuffer = '';
          checkPayment(txnRef);
        }
      },
      onError: (e) {
        //an SSE disconnect does not mean payment failed
        //the 3 minute timer stays active as the fallback
        if (state.status == 'idle') {
          state = state.copyWith(
            message: 'Waiting for payment confirmation...',
          );
        }
      },
      cancelOnError: true,
    );
  }

  Future checkPayment(String txnRef) async {
    //dont allow multiple webhook/timer checks to race each other
    if (_isCheckingPayment ||
        state.status == 'success' ||
        state.status == 'fail') {
      return;
    }

    _isCheckingPayment = true;

    try {
      var result = await _service.checkPayment(txnRef);

      print('checkPayment result: $result');

      //empty map means the request itself failed (network/DNS error),
      //not that NETS actually said the payment failed
      if (result.isEmpty) {
        //1 retry after a short delay before giving up
        await Future.delayed(const Duration(seconds: 2));

        result = await _service.checkPayment(txnRef);

        print('checkPayment retry result: $result');
      }

      if (result.isEmpty) {
        state = state.copyWith(
          status: 'fail',
          message:
              'Could not verify payment status. Please check your connection.',
        );

        _timer?.cancel();
        _webhookSub?.cancel();
        return;
      }

      final responseCode = result['response_code'];

      if (responseCode == '00') {
        state = state.copyWith(
          status: 'success',
          message: result['message'],
        );
      } else {
        state = state.copyWith(
          status: 'fail',
          message: result['message'] ?? 'Payment was not completed.',
        );
      }

      _timer?.cancel();
      _webhookSub?.cancel();
    } finally {
      _isCheckingPayment = false;
    }
  }

  //checks payment when the user comes back from TWallet
  //only changes to success if NETS confirms the payment,
  //otherwise the normal 3 minute timer keeps running
  Future<void> checkPaymentOnResume(String txnRef) async {
    if (_isCheckingPayment || state.status != 'idle') {
      return;
    }

    _isCheckingPayment = true;

    try {
      final result = await _service.checkPayment(txnRef);

      print('resume checkPayment result: $result');

      if (result['response_code'] == '00') {
        state = state.copyWith(
          status: 'success',
          message: result['message'],
        );

        _timer?.cancel();
        _webhookSub?.cancel();
      } else {
        //dont call it a failure yet
        //NETS may still be finishing the transaction
        state = state.copyWith(
          message: 'Waiting for payment confirmation...',
        );
      }
    } finally {
      _isCheckingPayment = false;
    }
  }

  //resets back to idle so the user can retry a fresh payment attempt
  void reset() {
    _timer?.cancel();
    _webhookSub?.cancel();
    _isCheckingPayment = false;
    state = NetsState();
  }

  //cleanup() means cancels the active timer/stream to prevent memory leaks
  void cleanup() {
    _timer?.cancel();
    _webhookSub?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _webhookSub?.cancel();
    super.dispose();
  }
}