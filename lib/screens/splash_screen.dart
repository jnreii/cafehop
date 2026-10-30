import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:cafehop/themes.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // warm yellow for the cat
  static const Color catYellow = Color(0xFFF4C95D);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
    );

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        await Future.delayed(
          const Duration(milliseconds: 350),
        );

        if (mounted) {
          widget.onFinished();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cat animation card
              Transform.rotate(
                angle: -0.025,
                child: Container(
                  width: 280,
                  height: 280,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: borderBlack,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: borderBlack,
                        blurRadius: 0,
                        offset: const Offset(6, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Lottie.asset(
                      'assets/animations/cat_splash.json',
                      controller: _controller,
                      fit: BoxFit.contain,
                      repeat: false,

                      // Change individual parts of the animation
                      delegates: LottieDelegates(
                        values: [
                          // Main background around the circle
                          ValueDelegate.color(
                            const [
                              'Shape Layer 8',
                              'Rectangle 1',
                              'Fill 1',
                            ],
                            value: darkBlue,
                          ),

                          // Second background shape
                          ValueDelegate.color(
                            const [
                              'Shape Layer 9',
                              'Rectangle 1',
                              'Fill 1',
                            ],
                            value: darkBlue,
                          ),

                          // Cat body
                          ValueDelegate.color(
                            const [
                              'body',
                              'Shape 1',
                              'Fill 1',
                            ],
                            value: catYellow,
                          ),
                        ],
                      ),

                      onLoaded: (composition) {
                        _controller.duration =
                            const Duration(milliseconds: 1600);

                        if (!_controller.isAnimating &&
                            !_controller.isCompleted) {
                          _controller.forward();
                        }
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: 'CafeHop'.split('').asMap().entries.map((entry) {
                  final index = entry.key;
                  final letter = entry.value;

                  return Text(
                    letter,
                    style: logoStyle.copyWith(
                      fontSize: 38,
                      letterSpacing: -1,
                    ),
                  )
                      .animate(
                        delay: (1300 + (index * 80)).ms,
                      )
                      .fadeIn(
                        duration: 260.ms,
                        curve: Curves.easeOut,
                      )
                      .slideY(
                        begin: 0.5,
                        end: 0,
                        duration: 320.ms,
                        curve: Curves.easeOutBack,
                      )
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                        duration: 320.ms,
                        curve: Curves.easeOutBack,
                      );
                }).toList(),
              ),

              const SizedBox(height: 8),

              Text(
                'hidden gems worth gatekeeping.',
                style: secondaryTextStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              )
                  .animate(
                    delay: 2050.ms,
                  )
                  .fadeIn(
                    duration: 260.ms,
                    curve: Curves.easeOut,
                  )
                  .slideY(
                    begin: 0.25,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}