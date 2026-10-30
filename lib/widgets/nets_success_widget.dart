import 'dart:async';
import 'package:flutter/material.dart';

class NETSSuccessWidget extends StatefulWidget {
  //called once the countdown finishes
  final VoidCallback onComplete;

  const NETSSuccessWidget({super.key, required this.onComplete});

  @override
  State<NETSSuccessWidget> createState() => _NETSSuccessWidgetState();
}

class _NETSSuccessWidgetState extends State<NETSSuccessWidget>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _countdown = 4;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    //gentle pulse on the tick icon while the booking saves in the
    //background, purely visual
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
          ),
          child: Image.asset(
            'images/green_tick.png',
            width: MediaQuery.of(context).size.width * 0.55,
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          "Payment Successful",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),

        const SizedBox(height: 16),

        //small spinner + label, communicates the actual firestore write
        //happening behind the scenes rather than just a bare countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Confirming your booking...",
              style: TextStyle(
                fontSize: 15,
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}