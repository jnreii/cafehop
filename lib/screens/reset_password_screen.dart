import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/screens/login_screen.dart';
import 'package:cafehop/services/firebase_service.dart';
import 'package:cafehop/themes.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  static String routeName = '/reset';

  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends ConsumerState<ResetPasswordScreen> {
  String? email;
  final form = GlobalKey<FormState>();

  //sends password reset email to the user
  Future<void> reset(BuildContext context) async {
    bool isValid = form.currentState!.validate();

    if (isValid) {
      form.currentState!.save();

      try {
        FirebaseService firebaseService =
            ref.read(firebaseServiceProvider);

        await firebaseService.forgotPassword(email!);

        if (!mounted) return;

        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password reset email sent! Check your inbox.',
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.code)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              //CafeHop Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.coffee, color: primaryBlue, size: 40),
                  const SizedBox(width: 8),
                  Text('CafeHop', style: logoStyle),
                ],
              ),

              const SizedBox(height: 32),

              //White card background
              Container(
                padding: const EdgeInsets.all(24),
                decoration: cardDecoration,
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      //Heading
                      Center(
                        child: Text(
                          'Reset Password',
                          style: headingStyle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Enter your email and we\'ll send you a link to reset your password.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      //Email field
                      Text('Email', style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: inputDecoration(''),
                        style: bodyStyle,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please provide an email address.";
                          } else if (!value.contains('@')) {
                            return "Please provide a valid email address.";
                          } else {
                            return null;
                          }
                        },
                        onSaved: (value) {
                          email = value;
                        },
                      ),

                      const SizedBox(height: 24),

                      //Reset Password button
                      Container(
                        width: double.infinity,
                        decoration: primaryButtonDecoration,
                        child: ElevatedButton(
                          onPressed: () {
                            reset(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Send Reset Link',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      //back to Login link
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Back to login page? ',
                              style: bodyStyle,
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pop(
                                  LoginScreen.routeName,
                                );
                              },
                              child: Text(
                                'Login',
                                style: GoogleFonts.plusJakartaSans(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}