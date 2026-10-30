import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cafehop/providers/nets_provider.dart';
import 'package:cafehop/widgets/nets_fail_widget.dart';
import 'package:cafehop/widgets/nets_success_widget.dart';

class NETSWidget extends ConsumerStatefulWidget {
  //deposit amount for this booking, shown on the QR screen
  final double amount;

  //called once the success countdown finishes, used to navigate away
  final VoidCallback onSuccessComplete;

  //called once the fail countdown finishes, used to let the user retry
  final VoidCallback onFailComplete;

  const NETSWidget({
    super.key,
    required this.amount,
    required this.onSuccessComplete,
    required this.onFailComplete,
  });

  @override
  ConsumerState<NETSWidget> createState() => _NETSWidgetState();
}

class _NETSWidgetState extends ConsumerState<NETSWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    //calls generateQR when the widget is first built to display the QR code
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(netsProvider.notifier).generateQR(widget.amount);
    });
  }

  //when the user comes back to CafeHop from TWallet,
  //check NETS straight away instead of waiting for the timer to finish
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;

        final paymentState = ref.read(netsProvider);

        if (paymentState.status == 'idle' &&
            paymentState.txnRef != null) {
          ref
              .read(netsProvider.notifier)
              .checkPaymentOnResume(paymentState.txnRef!);
        }
      });
    }
  }

  //format seconds into mm:ss
  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(netsProvider);

    return Container(
      padding: const EdgeInsets.all(10),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (state.status == "idle" && state.qrCode != null)
            Text(
              "Booking Deposit: \$${widget.amount.toStringAsFixed(2)}\nScan the QR code below with TWallet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

          //show QR code when available
          if (state.status == "idle" && state.qrCode != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Image.memory(
                state.qrCode!,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),

          if (state.status == "idle" && state.qrCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Image.asset(
                'images/nets_qr_info.png',
                width: MediaQuery.of(context).size.width * 0.7,
              ),
            ),

          if (state.message != null && state.status == "idle")
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                state.message!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ),

          //show status messages
          if (state.status == "loading")
            const CircularProgressIndicator(),

          //show success message
          if (state.status == "success")
            NETSSuccessWidget(
              onComplete: widget.onSuccessComplete,
            ),

          //show failure message
          if (state.status == "fail")
            NETSFailWidget(
              onComplete: widget.onFailComplete,
            ),

          //show time left when QR is active
          if (state.status == "idle" && state.qrCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "Time left: ${formatTime(state.timeLeft)}",
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),

          //cancel button, pops back to the booking form instead of the
          //original lab's "/" root, since going to app root here would
          //dump the user back on Explore instead of letting them retry
          if (state.status == "idle" && state.qrCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: () {
                  ref.read(netsProvider.notifier).cleanup();
                  Navigator.of(context).pop();
                },
                child: Text("Cancel Payment"),
              ),
            ),
        ],
      ),
    );
  }
}