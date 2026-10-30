import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/models/user.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/screens/personal_information_screen.dart';
import 'package:cafehop/services/firebase_service.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';
import 'package:cafehop/services/notification_service.dart';

class ProfileScreen extends ConsumerWidget {

  //logs the user out and returns back to login
  Future<void> logout(BuildContext context, WidgetRef ref) async {
    //gets this before logout since ProfileScreen disappears after signing out
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(firebaseServiceProvider).logOut();

      //main.dart automatically shows LoginScreen when the auth state changes
    } catch (e) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('An error occurred while logging out.'),
          ),
        );
      }
    }
  }

  //change password using new and confirm password fields
  Future<void> changePassword(BuildContext context, WidgetRef ref) async {
    String? newPassword;
    String? confirmPassword;

    var passwordForm = GlobalKey<FormState>();

    //local variable just for showing the password mismatch inside this dialog
    String? mismatchError;

    //asks user for their new password and confirmation
    await showDialog(
      context: context,
      builder: (context) {
        //StatefulBuilder gives only this dialog its own small state
        //so ProfileScreen doesnt need to become a StatefulWidget
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: passwordForm,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please provide a password.';
                        else if (value.length < 6)
                          return 'Password must be at least 6 characters.';
                        else
                          return null;
                      },
                      onSaved: (value) {
                        newPassword = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty)
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

                    //shows mismatch error directly inside the dialog
                    if (mismatchError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        mismatchError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (passwordForm.currentState!.validate()) {
                      passwordForm.currentState!.save();

                      if (newPassword != confirmPassword) {
                        //only rebuilds the dialog to show the error above
                        setDialogState(() {
                          mismatchError = 'Passwords do not match.';
                        });
                        return;
                      }

                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    //stops here if the user cancelled the dialog
    if (newPassword == null) return;

    try {
      FirebaseService firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.changePassword(newPassword!);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!')),
      );
    } on FirebaseAuthException catch (e) {
      //firebase needs a recent login before allowing password changes
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please log out and log in again after changing your password.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.code)),
        );
      }
    }
  }

  //lets the user choose which CafeHop notifications they want
  Future<void> showNotificationSettings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    bool bookingReminders =
        await NotificationService.bookingRemindersEnabled();
    bool visitReminders =
        await NotificationService.visitRemindersEnabled();
    bool recommendations =
        await NotificationService.recommendationNotificationsEnabled();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Notification Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Booking reminders'),
                    subtitle: const Text('24 hours before your booking'),
                    value: bookingReminders,
                    onChanged: (value) async {
                      setDialogState(() {
                        bookingReminders = value;
                      });

                      await NotificationService
                          .setBookingRemindersEnabled(value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visit reminders'),
                    subtitle: const Text('Ask how your cafe visit went'),
                    value: visitReminders,
                    onChanged: (value) async {
                      setDialogState(() {
                        visitReminders = value;
                      });

                      await NotificationService
                          .setVisitRemindersEnabled(value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cafe recommendations'),
                    subtitle: const Text('New cafes matching your taste'),
                    value: recommendations,
                    onChanged: (value) async {
                      setDialogState(() {
                        recommendations = value;
                      });

                      await NotificationService
                          .setRecommendationNotificationsEnabled(value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );

    //updates existing upcoming reminders to match the new settings
    try {
      final bookings =
          await ref.read(allBookingsProvider.future);

      await NotificationService.syncBookingNotifications(
        bookings,
      );
    } catch (e) {
      print('Could not update notification settings: $e');
    }
  }

  //shows the saved profile photo or falls back to the person icon
  Widget _buildProfilePhoto(String? profilePhoto) {
    if (profilePhoto == null || profilePhoto.trim().isEmpty) {
      return const Icon(
        Icons.person,
        size: 60,
        color: Colors.black26,
      );
    }

    //photos picked from gallery are stored as base64
    if (profilePhoto.startsWith('data:image')) {
      try {
        final encodedImage = profilePhoto.split(',').last;

        return Image.memory(
          base64Decode(encodedImage),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return const Icon(
          Icons.person,
          size: 60,
          color: Colors.black26,
        );
      }
    }

    //also supports profile photos from Google sign in
    return Image.network(
      profilePhoto,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.person,
          size: 60,
          color: Colors.black26,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //current logged in user, used for their details and verified badge
    final firebaseService = ref.read(firebaseServiceProvider);
    final user = firebaseService.getCurrentUser();

    final bool isVerified = user?.emailVerified ?? false;

    //saved cafes updates live from the user's firestore document
    final savedCount = ref.watch(savedCafeIdsProvider).length;

    //loads the other 2 profile stats using firestore aggregation queries
    final Future<List<int>> statsFuture = user == null
        ? Future.value([0, 0])
        : Future.wait([
            firebaseService.countBookings(user.uid, 'completed'),
            firebaseService.countUserReviews(user.uid),
          ]);

    return Scaffold(
      backgroundColor: creamBackground,

      //shared CafeHop app bar
      appBar: CafeHopAppBar(),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
        child: Column(
          children: [

            //shows the user's saved profile photo
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: borderBlack, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 0,
                    offset: Offset(4, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: user == null
                    ? _buildProfilePhoto(null)
                    : StreamBuilder<AppUser?>(
                        stream: firebaseService.getUserDoc(user.uid),
                        builder: (context, snapshot) {
                          //firestore photo first, then google account photo
                          final profilePhoto =
                              snapshot.data?.profilePhotoUrl ?? user.photoURL;

                          return _buildProfilePhoto(profilePhoto);
                        },
                      ),
              ),
            ),

            const SizedBox(height: 16),

            //uses the saved profile name first, then falls back to auth details
            if (user == null)
              Text(
                'CafeHopper',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: borderBlack,
                ),
                textAlign: TextAlign.center,
              )
            else
              StreamBuilder<AppUser?>(
                stream: firebaseService.getUserDoc(user.uid),
                builder: (context, snapshot) {
                  final savedName = snapshot.data?.name.trim() ?? '';
                  final authName = user.displayName?.trim() ?? '';

                  final displayName = savedName.isNotEmpty
                      ? savedName
                      : authName.isNotEmpty
                          ? authName
                          : user.email ?? user.phoneNumber ?? 'CafeHopper';

                  return Text(
                    displayName,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: borderBlack,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),

            const SizedBox(height: 8),

            //verified badge follows the user's real email verification status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isVerified
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: isVerified
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFECACA),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVerified ? Icons.check_circle : Icons.error_outline,
                    size: 12,
                    color: isVerified
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isVerified ? 'VERIFIED' : 'UNVERIFIED',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isVerified
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            FutureBuilder<List<int>>(
              future: statsFuture,
              builder: (context, snapshot) {
                //shows a dash while the firestore aggregation is loading
                final visits =
                    snapshot.hasData ? snapshot.data![0].toString() : '—';
                final reviews =
                    snapshot.hasData ? snapshot.data![1].toString() : '—';

                return Row(
                  children: [
                    Expanded(child: _buildStatCard(visits, 'VISITS')),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            _buildStatCard(savedCount.toString(), 'SAVED')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(reviews, 'REVIEWS')),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            //settings list
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderBlack, width: 2),
              ),
              child: Column(
                children: [
                  _buildSettingsRow(
                    Icons.person_outline,
                    'Personal Information',
                    true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PersonalInformationScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsRow(
                    Icons.lock_outline,
                    'Change Password',
                    true,
                    onTap: () {
                      changePassword(context, ref);
                    },
                  ),
                  _buildSettingsRow(
                    Icons.notifications_outlined,
                    'Notification Settings',
                    true,
                    onTap: () {
                      showNotificationSettings(context, ref);
                    },
                  ),
                  _buildSettingsRow(
                    Icons.palette_outlined,
                    'Theme',
                    false,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ThemeSelectionScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            //log out button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E2E2),
                  border: Border.all(color: borderBlack, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(3.6, 3.6),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () {
                    logout(context, ref);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Log Out',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: borderBlack,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //builds the visits, saved and reviews stat cards
  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderBlack, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 0,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: borderBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: borderBlack,
            ),
          ),
        ],
      ),
    );
  }

  //builds each row inside the settings card
  Widget _buildSettingsRow(IconData icon, String label, bool showDivider,
      {VoidCallback? onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 20, color: borderBlack),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Colors.black38),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: borderBlack.withOpacity(0.3)),
      ],
    );
  }
}


//separate page where the user can choose their CafeHop colour theme
class ThemeSelectionScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: creamBackground,

      //same CafeHop app bar but with a back button
      appBar: CafeHopAppBar(showBackButton: true),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your theme',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: borderBlack,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Pick an accent colour for your CafeHop experience.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 24),

            //creates one selectable card for each CafeHop theme
            ...cafeThemes.map((theme) {
              final bool isSelected =
                  selectedTheme.name == theme.name;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(theme);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.primary
                            : borderBlack,
                        width: isSelected ? 3 : 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 0,
                          offset: Offset(3, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [

                        //shows the main, dark and light colours of the theme
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: theme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: borderBlack,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(-8, 0),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: theme.dark,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: borderBlack,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(-16, 0),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: theme.tag,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: borderBlack,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 4),

                        Expanded(
                          child: Text(
                            theme.label,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: borderBlack,
                            ),
                          ),
                        ),

                        //shows which theme is currently selected
                        if (isSelected)
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: theme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: borderBlack,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}