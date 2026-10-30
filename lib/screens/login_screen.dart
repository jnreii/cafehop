import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/screens/reset_password_screen.dart';
import 'package:cafehop/screens/signup_screen.dart';
import 'package:cafehop/services/firebase_service.dart';
import 'package:cafehop/themes.dart';

//Stateful to remember state of password visibility toggle and form input values, consumer to access FirebaseService and authStateProvider
class LoginScreen extends ConsumerStatefulWidget {
  static String routeName = "/login";
//static variables exist without creating an instance of the class
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> { 
  String? email;
  String? password;
  String? phoneNumber;
  String? smsCode;
  var form = GlobalKey<FormState>(); //accesses the state of the form, allows validation and saving of form input values

  //Whether the password field hides its characters
  bool _obscurePassword = true; //hidden default

  // Handles both email/password login and Google Sign-In
 Future<void> login(BuildContext context, bool isGoogleLogin) async { 
    bool isValid = isGoogleLogin ? true : form.currentState!.validate(); 

    if (isValid) {
      form.currentState!.save();

      try {
        FirebaseService firebaseService = ref.read(firebaseServiceProvider); 

        if (isGoogleLogin) {
          final result = await firebaseService.signInWithGoogle();

          //user closed the Google account picker
          if (result == null) return;
        } else {
          await firebaseService.login(email!, password!);
        }

      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.code)),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
    }
  }

  //Phone Sign-In
  Future<void> loginWithPhone(BuildContext context) async {
    //Resets phoneNumber and smsCode to null if the user cancels the dialogs
    phoneNumber = null;
    smsCode = null;

    var phoneForm = GlobalKey<FormState>(); 

    //input phone number dialog
    await showDialog( //showDialog returns a Future that completes when the dialog is dismissed
      context: context, 
      builder: (context) { 
        return AlertDialog(
          title: const Text('Continue with Phone'),
          content: Form(
            key: phoneForm, 
            child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixText: '+65 ',           // fixed, assume Singapore numbers only
              hintText: 'XXXX XXXX',
            ),
            keyboardType: TextInputType.phone, //numeric keyboard
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Please provide a phone number.';
              else if (value.length != 8)
                return 'Phone number must be 8 digits.';
              else if (!value.startsWith('8') && !value.startsWith('9'))
                return 'SG mobile numbers start with 8 or 9.';
              else
                return null;
            },
            onSaved: (value) {
              phoneNumber = '+65$value';    // combine prefix and digits for Firebase
            },
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (phoneForm.currentState!.validate()) { 
                  phoneForm.currentState!.save(); 
                  Navigator.of(context).pop(); //returns to prev screen
                }
              },
              child: const Text('Send Code'),
            ),
          ],
        );
      },
    );

    // User cancelled phone number dialog
    if (phoneNumber == null) return;

    try {
      FirebaseService firebaseService = ref.read(firebaseServiceProvider);

      //Sends the verification code
      final confirmationResult =
          await firebaseService.signInWithPhone(phoneNumber!);

      var codeForm = GlobalKey<FormState>();

      //OTP code input dialog
      await showDialog( 
        context: context,
        builder: (context) {
          return AlertDialog( 
            title: const Text('Enter Verification Code'),
            content: Form(
              key: codeForm,
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please provide the verification code.';
                  else if (value.length != 6)
                    return 'Code must be 6 digits.';
                  else
                    return null;
                },
                onSaved: (value) {
                  smsCode = value;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (codeForm.currentState!.validate()) {
                    codeForm.currentState!.save();
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Verify'),
              ),
            ],
          );
        },
      );

      //User cancelled code input dialog
      if (smsCode == null) return;

      await firebaseService.confirmPhoneCode(confirmationResult, smsCode!);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.code)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone sign-in failed. Please try again.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      resizeToAvoidBottomInset: true, //allows the screen to scroll up when the keyboard appears
      //safe area to avoid notches and system UI
      body: SafeArea(
        child: SingleChildScrollView(
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

              // White card with black outline background design
              Container(
                padding: const EdgeInsets.all(24), //padding inside the card
                decoration: cardDecoration,
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, //aligns children to the left
                    children: [
                      //Welcome text
                      Center(
                        child: Text(
                          'Welcome Back!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Ready for your next caffeine fix?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            color: primaryBlue,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      //Email field label
                      Text('Email', style: labelStyle),
                      const SizedBox(height: 8),

                      //Email input
                      TextFormField( 
                        decoration: inputDecoration(''),
                        style: bodyStyle,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.length == 0)
                            return "Please provide an email address.";
                          else if (!value.contains('@'))
                            return "Please provide a valid email address.";
                          else
                            return null;
                        },
                        onSaved: (value) {
                          email = value;
                        },
                      ),

                      const SizedBox(height: 16),

                      //Password label with Forgot Password link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, //aligns the children to the left and right edges of the row
                        children: [
                          Text('Password', style: labelStyle),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                ResetPasswordScreen.routeName,
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.plusJakartaSans(
                                color: primaryBlue,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      //Password input with show/hide toggle
                      TextFormField(
                        decoration: inputDecoration('').copyWith(
                          suffixIcon: IconButton( //suffix icon places the icon on the right side of input field
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.remove_red_eye_outlined
                                  : Icons.visibility_off_outlined, 
                            ),
                            onPressed: () {
                              //Toggle password visibility
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        style: bodyStyle,
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.length == 0)
                            return 'Please provide a password.';
                          else if (value.length < 6)
                            return 'Password must be at least 6 characters.';
                          else
                            return null;
                        },
                        onSaved: (value) {
                          password = value;
                        },
                      ),

                      const SizedBox(height: 24),

                      //Login button
                      Container(
                        width: double.infinity, //makes the button take up the full width of the parent container
                        decoration: primaryButtonDecoration,
                        child: ElevatedButton(
                          onPressed: () {
                            login(context, false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Login',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      //OR CONTINUE WITH divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.black26)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.black26)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      //Sign in with Google button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            login(context, true);
                          },
                          icon: FaIcon(
                            FontAwesomeIcons.google,
                            color: const Color.fromARGB(255, 26, 60, 143),
                            size: 18,
                          ),
                          label: Text(
                            'Sign in with Google',
                            style: bodyStyle,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.black, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      //Continue with Phone Number button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            loginWithPhone(context);
                          },
                          icon: Icon(
                            Icons.phone_android,
                            color: Colors.black54,
                            size: 24,
                          ),
                          label: Text(
                            'Continue with Phone Number',
                            style: bodyStyle,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.black, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      //Register link
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ", style: bodyStyle),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pushReplacementNamed(
                                  SignupScreen.routeName,
                                );
                              },
                              child: Text(
                                'Register',
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