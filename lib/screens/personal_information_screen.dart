import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';

class PersonalInformationScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends ConsumerState<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _email = '';
  String? _profilePhoto;
  bool _photoChanged = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPersonalInformation();
  }

  //loads the current Firestore details into the form once
  Future<void> _loadPersonalInformation() async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authUser = firebaseService.getCurrentUser();

      if (authUser == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      //older accounts may not have a user document yet
      await firebaseService.ensureUserDocument(authUser);

      final appUser = await firebaseService.getUserDoc(authUser.uid).first;

      if (!mounted) return;

      _nameController.text = appUser?.name.isNotEmpty == true
          ? appUser!.name
          : authUser.displayName ?? '';

      _phoneController.text =
          appUser?.phoneNumber ?? authUser.phoneNumber ?? '';

      _email = appUser?.email.isNotEmpty == true
          ? appUser!.email
          : authUser.email ?? '';

      _profilePhoto = appUser?.profilePhotoUrl;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load your personal information.'),
        ),
      );
    }
  }

  //lets the user choose a new profile photo from gallery
  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,

        //profile photos dont need to be full resolution
        //keeping it small also avoids putting a huge image in Firestore
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 50,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      final encodedImage =
          'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (!mounted) return;

      setState(() {
        _profilePhoto = encodedImage;
        _photoChanged = true;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not select profile photo.'),
        ),
      );
    }
  }

  //shows firestore/base64 photos and also supports google profile photo urls
  Widget _buildProfilePhoto() {
    if (_profilePhoto == null || _profilePhoto!.isEmpty) {
      return const Icon(
        Icons.person,
        size: 58,
        color: Colors.black26,
      );
    }

    if (_profilePhoto!.startsWith('data:image')) {
      try {
        final encoded = _profilePhoto!.split(',').last;
        final bytes = base64Decode(encoded);

        return Image.memory(
          bytes,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return const Icon(
          Icons.person,
          size: 58,
          color: Colors.black26,
        );
      }
    }

    return Image.network(
      _profilePhoto!,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.person,
          size: 58,
          color: Colors.black26,
        );
      },
    );
  }

  //saves the editable fields to Firestore and keeps the auth name in sync
  Future<void> _savePersonalInformation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      await firebaseService.updatePersonalInformation(
        name: _nameController.text,
        phoneNumber: _phoneController.text,
      );

      //photo has its own firestore update so the existing form stays separate
      if (_photoChanged && _profilePhoto != null) {
        await firebaseService.updateProfilePhoto(_profilePhoto!);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal information updated.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your personal information.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: CafeHopAppBar(showBackButton: true),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: selectedTheme.primary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: borderBlack,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep your CafeHop profile details up to date.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: secondaryText,
                      ),
                    ),

                    const SizedBox(height: 24),

                    //profile photo
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickProfilePhoto,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: borderBlack,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _buildProfilePhoto(),
                                  ),
                                ),

                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: selectedTheme.dark,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: borderBlack,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          TextButton(
                            onPressed: _pickProfilePhoto,
                            child: Text(
                              _profilePhoto == null ||
                                      _profilePhoto!.isEmpty
                                  ? 'Add profile photo'
                                  : 'Change profile photo',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: selectedTheme.dark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderBlack,
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 0,
                            offset: Offset(3, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Full Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              hintText: 'Enter your full name',
                              selectedTheme: selectedTheme,
                            ),
                            validator: (value) {
                              final name = value?.trim() ?? '';

                              if (name.isEmpty) {
                                return 'Please enter your name.';
                              }

                              if (name.length < 2) {
                                return 'Name must be at least 2 characters.';
                              }

                              if (name.length > 50) {
                                return 'Name must be 50 characters or less.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          _buildLabel('Email'),
                          const SizedBox(height: 8),

                          //email is shown here but account email changes need
                          //their own verification flow, so it stays read-only
                          TextFormField(
                            initialValue: _email,
                            readOnly: true,
                            decoration: _inputDecoration(
                              hintText: 'No email linked',
                              selectedTheme: selectedTheme,
                              readOnly: true,
                            ).copyWith(
                              suffixIcon: const Icon(
                                Icons.lock_outline,
                                size: 18,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          _buildLabel('Phone Number'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            decoration: _inputDecoration(
                              hintText: 'e.g. +65 9123 4567',
                              selectedTheme: selectedTheme,
                            ),
                            validator: (value) {
                              final phone = value?.trim() ?? '';

                              //phone number is optional
                              if (phone.isEmpty) return null;

                              final cleaned =
                                  phone.replaceAll(RegExp(r'[\s-]'), '');

                              if (!RegExp(r'^\+?\d{8,15}$')
                                  .hasMatch(cleaned)) {
                                return 'Enter a valid phone number.';
                              }

                              return null;
                            },
                            onFieldSubmitted: (_) {
                              if (!_isSaving) {
                                _savePersonalInformation();
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: borderBlack,
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 0,
                            offset: Offset(3, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed:
                            _isSaving ? null : _savePersonalInformation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedTheme.dark,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black26,
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'SAVE CHANGES',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  //small label shared by all 3 profile fields
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: borderBlack,
      ),
    );
  }

  //keeps all the profile text fields visually consistent
  InputDecoration _inputDecoration({
    required String hintText,
    required CafeTheme selectedTheme,
    bool readOnly = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: readOnly ? const Color(0xFFF4F4F4) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: borderBlack,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: borderBlack,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: selectedTheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }
}