import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/screens/login_screen.dart';
import 'package:cafehop/services/firebase_service.dart';
import 'package:cafehop/themes.dart';

//Stateful to remember password visibility toggles and loading state, consumer to access FirebaseService
class SignupScreen extends ConsumerStatefulWidget {
  static String routeName = '/signup';

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  String? email;
  String? password;
  String? confirmPassword;
  String? fullName;
  String? phoneNumber;
  String? smsCode;
  var form = GlobalKey<FormState>();

  //Whether each password field hides its characters
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  //true while any of the 3 signup methods is running, disable buttons so user cant spam tap
  bool _isLoading = false;

  //registration with email and password
  Future<void> register(BuildContext context) async {
    bool isValid = form.currentState!.validate();
    if (isValid) {
      form.currentState!.save(); //saves form values into the variables

      if (password != confirmPassword) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password and Confirm Password does not match!')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        FirebaseService firebaseService = ref.read(firebaseServiceProvider);

        //create the account and signs the new user in automatically
        await firebaseService.register(email!, password!);

        //saves full name to the profile
        await firebaseService.updateDisplayName(fullName!);

        //send verification email while still signed in
        await firebaseService.sendEmailVerification();

        //sign out so they have to verify first then login fresh
        await firebaseService.logOut();

        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Account created! Check your email (and spam folder) to verify, then log in.'),
          ),
        );

        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.code)),
        );
      } catch (e) {
        //if updateDisplayName or sendEmailVerification fails
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      } finally {
        //always runs whether it succeeded or not, so button doesnt get stuck disabled forever
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  //Google sign up, Firebase makes the account automatically if acc is new
  Future<void> signUpWithGoogle(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      FirebaseService firebaseService = ref.read(firebaseServiceProvider);
      final result = await firebaseService.signInWithGoogle();

      //user cancelled the google account picker
      if (result == null) return;

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.code)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  //Phone signup
  Future<void> signUpWithPhone(BuildContext context) async {
    //reset in case user cancelled the previous attempt
    phoneNumber = null;
    smsCode = null;

    var phoneForm = GlobalKey<FormState>();

    //phone number input
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign up with Phone'),
          content: Form(
            key: phoneForm,
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+65 ', //fixed, assuming SG numbers only
                hintText: '91234567',
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
                phoneNumber = '+65$value'; //combine prefix + digits for firebase
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
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Send Code'),
            ),
          ],
        );
      },
    );

    if (phoneNumber == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      FirebaseService firebaseService = ref.read(firebaseServiceProvider);

      //sends the code to the phone number, returns a ConfirmationResult which is used to confirm the code
      final confirmationResult =
          await firebaseService.signInWithPhone(phoneNumber!);

      var codeForm = GlobalKey<FormState>();

      //OTP dialog
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

      //user cancelled OTP dialog
      if (smsCode == null) return;

      //Confirms the code, signs in (or creates account if new number)
      await firebaseService.confirmPhoneCode(confirmationResult, smsCode!);

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.code)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone sign-up failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      resizeToAvoidBottomInset: true, //so keyboard doesnt cover the fields
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

              // White card background
              Container(
                padding: const EdgeInsets.all(24),
                decoration: cardDecoration,
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, //aligns children to the left

                    children: [

                      //Join the Club heading
                      Center(
                        child: Text(
                          'Join the Club',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Discover Singapore\'s hidden gems.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            color: Colors.black54,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      //Full Name field
                      Text('Full Name', style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: inputDecoration(''),
                        style: bodyStyle,
                        validator: (value) {
                          if (value == null || value.length == 0)
                            return "Please provide your full name.";
                          else if (value.length < 4)
                            return 'Full name must be at least 4 characters.';
                          else
                            return null;
                        },
                        onSaved: (value) {
                          fullName = value;
                        },
                      ),

                      const SizedBox(height: 16),

                      //Email field
                      Text('Email', style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: inputDecoration(''),
                        style: bodyStyle,
                        keyboardType: TextInputType.emailAddress, //email keyboard
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

                      //Password field with show/hide toggle
                      Text('Password', style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: inputDecoration('').copyWith(
                          suffixIcon: IconButton( //suffix icon = icon sits inside the field on the right
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.remove_red_eye_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              //toggle visibility
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

                      const SizedBox(height: 16),

                      //Confirm Password field, same show/hide toggle 
                      Text('Confirm', style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: inputDecoration('').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.remove_red_eye_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              });
                            },
                          ),
                        ),
                        style: bodyStyle,
                        obscureText: _obscureConfirm,
                        validator: (value) {
                          if (value == null || value.length == 0)
                            return 'Please confirm your password.';
                          else if (value.length < 6)
                            return 'Password must be at least 6 characters.';
                          else
                            return null;
                        },
                        onSaved: (value) {
                          confirmPassword = value;
                        },
                      ),

                      const SizedBox(height: 24),

                      //Create Account button
                      Container(
                        width: double.infinity, //stretches full width
                        decoration: primaryButtonDecoration,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null //null onPressed means button is disabled
                              : () {
                                  register(context);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox( //small spinner while loading
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Create Account',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      //OR REGISTER WITH OTHERS divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.black26)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'OR REGISTER WITH OTHERS',
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

                      //Sign up with Google button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  signUpWithGoogle(context);
                                },
                          icon: FaIcon(
                            FontAwesomeIcons.google,
                            color: const Color.fromARGB(255, 26, 60, 143),
                            size: 18,
                          ),
                          label: Text(
                            'Sign up with Google',
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

                      //Sign up with Phone Number button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  signUpWithPhone(context);
                                },
                          icon: Icon(
                            Icons.phone_android,
                            color: Colors.black54,
                            size: 24,
                          ),
                          label: Text(
                            'Sign up with Phone Number',
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              //Already have an account link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: bodyStyle),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pushReplacementNamed(
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

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}