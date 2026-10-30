import 'dart:async';
import 'package:flutter/material.dart';

class NETSFailWidget extends StatefulWidget {
  //called once the 10 second countdown finishes
  final VoidCallback onComplete;

  const NETSFailWidget({super.key, required this.onComplete});

  @override
  State<NETSFailWidget> createState() => _NETSFailWidgetState();
}

class _NETSFailWidgetState extends State<NETSFailWidget> {
  Timer? _timer;
  int _countdown = 10;

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  //starts a countdown timer that updates the UI every second and calls
  //onComplete when it reaches zero
  void startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('images/red_cross.png', width: MediaQuery.of(context).size.width * 0.6),

        SizedBox(height: 10),

        const Text(
          "Payment Failed",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          "You can try again in $_countdown seconds",
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}