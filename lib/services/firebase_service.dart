import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cafehop/models/bookings.dart';
import 'package:cafehop/models/review.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/user.dart';

class FirebaseService {
  //current logged in user
  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  //register with email and password
  Future<UserCredential> register(String email, String password) async {
    final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await ensureUserDocument(result.user);
    return result;
  }

  //login with email and password
  Future<UserCredential> login(String email, String password) async {
    final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    //makes sure older accounts also have a user document
    await ensureUserDocument(result.user);

    return result;
  }

  //logs out from firebase and google
  Future logOut() async {
    await FirebaseAuth.instance.signOut();

    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }

  //sends a password reset email
  Future forgotPassword(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(
      email: email,
    );
  }

  //google sign in
  //web uses a popup while android uses google_sign_in
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();

        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        //asks which google account to use instead of reusing the last one
        googleProvider.setCustomParameters({
          'prompt': 'select_account',
        });

        final UserCredential webResult =
            await FirebaseAuth.instance.signInWithPopup(
          googleProvider,
        );

        await ensureUserDocument(webResult.user);

        print('Google Sign-In successful: ${webResult.user?.email}');
        return webResult;
      }

      final GoogleSignIn googleSignIn = GoogleSignIn();

      //clears the previous account so the picker appears again
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser =
          await googleSignIn.signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await ensureUserDocument(result.user);

      print('Google Sign-In successful: ${result.user?.email}');
      return result;
    } catch (e) {
      print('Google Sign-In failed: $e');
      rethrow;
    }
  }

  //holds the web confirmation while the user enters their phone code
  ConfirmationResult? _webConfirmation;

  //sends a verification code to the phone number
  Future<String> signInWithPhone(String phoneNumber) async {
    if (kIsWeb) {
      _webConfirmation =
          await FirebaseAuth.instance.signInWithPhoneNumber(
        phoneNumber,
      );

      return _webConfirmation!.verificationId;
    }

    final completer = Completer<String>();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
    );

    return completer.future;
  }

  //confirms the code the user received
  Future<UserCredential> confirmPhoneCode(
    String verificationId,
    String smsCode,
  ) async {
    UserCredential result;

    if (kIsWeb) {
      result = await _webConfirmation!.confirm(smsCode);
    } else {
      final PhoneAuthCredential credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
    }

    await ensureUserDocument(result.user);
    return result;
  }

  //changes the password for the logged in user
  Future changePassword(String newPassword) {
    return FirebaseAuth.instance.currentUser!.updatePassword(
      newPassword,
    );
  }

  //sends a verification email
  Future sendEmailVerification() {
    return FirebaseAuth.instance.currentUser!
        .sendEmailVerification();
  }

  //updates the firebase auth display name
  Future updateDisplayName(String name) {
    return FirebaseAuth.instance.currentUser!.updateDisplayName(
      name,
    );
  }

  //updates the editable details in Personal Information
  //the name is kept in auth and firestore so they stay consistent
  Future<void> updatePersonalInformation({
    required String name,
    String? phoneNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently logged in.',
      );
    }

    final cleanName = name.trim();
    final cleanPhone = phoneNumber?.trim();

    await usersRef.doc(user.uid).set(
      {
        'name': cleanName,
        'email': user.email ?? '',
        'phoneNumber':
            cleanPhone == null || cleanPhone.isEmpty
                ? null
                : cleanPhone,
      },
      SetOptions(merge: true),
    );

    await user.updateDisplayName(cleanName);
  }

  //updates only the user's profile photo
  Future<void> updateProfilePhoto(String profilePhoto) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently logged in.',
      );
    }

    await usersRef.doc(user.uid).set(
      {
        'profilePhotoUrl': profilePhoto,
      },
      SetOptions(merge: true),
    );
  }

  //booking collection
  final CollectionReference<Map<String, dynamic>> bookingsRef =
      FirebaseFirestore.instance.collection('bookings');

  //adds a new booking
  Future<DocumentReference<Map<String, dynamic>>> addBooking(
    Booking booking,
  ) {
    return bookingsRef.add(booking.toMap());
  }

  //updates an existing booking
  Future updateBooking(Booking booking) {
    return bookingsRef.doc(booking.id).update(
      booking.toMap(),
    );
  }

  //deletes a booking
  Future deleteBooking(String id) {
    return bookingsRef.doc(id).delete();
  }

  //gets one booking using its document id
  Stream<Booking> getBooking(String id) {
    return bookingsRef.doc(id).snapshots().map(
      (doc) => Booking.fromMap(
        doc.id,
        doc.data()!,
      ),
    );
  }

  //gets one booking once when opening a notification
  Future<Booking?> getBookingById(String id) async {
    final doc = await bookingsRef.doc(id).get();

    if (!doc.exists) return null;

    return Booking.fromMap(
      doc.id,
      doc.data()!,
    );
  }

  //gets every booking belonging to one user
  Stream<List<Booking>> getAllBookings(String userId) {
    return bookingsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => Booking.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  //gets upcoming bookings and sorts the nearest booking first
  Stream<List<Booking>> getUpcomingBookings(String userId) {
    return bookingsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .where(
          'status',
          isEqualTo: 'upcoming',
        )
        .orderBy('dateTime')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => Booking.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  //past includes completed, cancelled and missed bookings
  Stream<List<Booking>> getPastBookings(String userId) {
    return bookingsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .where(
          'status',
          whereIn: [
            'completed',
            'cancelled',
            'missed',
          ],
        )
        .orderBy(
          'dateTime',
          descending: true,
        )
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => Booking.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  //counts bookings on firestore without downloading every document
  Future<int> countBookings(
    String userId,
    String status,
  ) async {
    final result = await bookingsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .where(
          'status',
          isEqualTo: status,
        )
        .count()
        .get();

    return result.count ?? 0;
  }

  //checks which slots are already taken for the selected cafe and date
  Future<Set<String>> getBookedTimeSlots(
    String cafeId,
    DateTime date, {
    String? excludeBookingId,
  }) async {
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final endOfDay =
        startOfDay.add(const Duration(days: 1));

    final snap = await bookingsRef
        .where(
          'cafeId',
          isEqualTo: cafeId,
        )
        .where(
          'status',
          isEqualTo: 'upcoming',
        )
        .where(
          'dateTime',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(startOfDay),
        )
        .where(
          'dateTime',
          isLessThan: Timestamp.fromDate(endOfDay),
        )
        .get();

    return snap.docs
        //when editing, the booking shouldnt block its own current slot
        .where(
          (doc) => doc.id != excludeBookingId,
        )
        .map((doc) {
          final dt =
              (doc.data()['dateTime'] as Timestamp).toDate();

          return DateFormat('h:mm a').format(dt);
        })
        .toSet();
  }

  //review collection
  final CollectionReference<Map<String, dynamic>> reviewsRef =
      FirebaseFirestore.instance.collection('reviews');

  //uses the booking id so one booking cant submit multiple reviews
  Future addReview(Review review) {
    return reviewsRef.doc(review.bookingId).set(
      review.toMap(),
    );
  }

  //checks if a booking already has a review
  Future<bool> hasReview(String bookingId) async {
    final doc = await reviewsRef.doc(bookingId).get();
    return doc.exists;
  }

  //updates the review button when a review is submitted
  Stream<bool> hasReviewStream(String bookingId) {
    return reviewsRef.doc(bookingId).snapshots().map(
      (doc) => doc.exists,
    );
  }

  //gets all reviews for one cafe
  Stream<List<Review>> getReviews(String cafeId) {
    return reviewsRef
        .where(
          'cafeId',
          isEqualTo: cafeId,
        )
        .snapshots()
        .map((snap) {
      final reviews = snap.docs
          .map(
            (doc) => Review.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();

      //shows newer reviews first
      reviews.sort((a, b) {
        final aDate = a.postedAt ?? DateTime(2000);
        final bDate = b.postedAt ?? DateTime(2000);

        return bDate.compareTo(aDate);
      });

      return reviews;
    });
  }

  //gets reviews written by one user for AI personalisation
  Stream<List<Review>> getUserReviews(String userId) {
    return reviewsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => Review.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  //counts how many reviews one user has submitted
  Future<int> countUserReviews(String userId) async {
    final result = await reviewsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .count()
        .get();

    return result.count ?? 0;
  }

  //cafe collection
  final CollectionReference<Map<String, dynamic>> cafesRef =
      FirebaseFirestore.instance.collection('cafes');

  //live list used anywhere cafes are displayed
  Stream<List<Cafe>> getCafes() {
    return cafesRef.snapshots().map(
      (snap) => snap.docs
          .map(
            (doc) => Cafe.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList(),
    );
  }

  //gets one cafe using its id
  Future<Cafe?> getCafeById(String cafeId) async {
    final doc = await cafesRef.doc(cafeId).get();

    if (!doc.exists) return null;

    return Cafe.fromMap(
      doc.id,
      doc.data()!,
    );
  }

  //user collection
  final CollectionReference<Map<String, dynamic>> usersRef =
      FirebaseFirestore.instance.collection('users');

  //creates the user document the first time they authenticate
  Future<void> ensureUserDocument(User? user) async {
    if (user == null) return;

    final docRef = usersRef.doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) return;

    final newUser = AppUser(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      phoneNumber: user.phoneNumber,
      profilePhotoUrl: user.photoURL,
      createdAt: DateTime.now(),
    );

    await docRef.set(
      newUser.toMap(),
    );
  }

  //live stream of one user's firestore document
  Stream<AppUser?> getUserDoc(String uid) {
    return usersRef.doc(uid).snapshots().map(
      (doc) => doc.exists
          ? AppUser.fromMap(
              doc.id,
              doc.data()!,
            )
          : null,
    );
  }

  //recalculates preferred cafe categories from completed visits
  //repeat visits to a category make that preference stronger
  Future<void> refreshPreferredCategories(
    String userId,
  ) async {
    final completedBookings = await bookingsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .where(
          'status',
          isEqualTo: 'completed',
        )
        .get();

    if (completedBookings.docs.isEmpty) {
      await usersRef.doc(userId).set(
        {
          'preferredCategories': <String>[],
        },
        SetOptions(merge: true),
      );

      return;
    }

    //only gets each cafe once even if it was visited multiple times
    final uniqueCafeIds = completedBookings.docs
        .map(
          (doc) => doc.data()['cafeId'] as String?,
        )
        .whereType<String>()
        .toSet();

    final cafeDocs = await Future.wait(
      uniqueCafeIds.map(
        (cafeId) => cafesRef.doc(cafeId).get(),
      ),
    );

    final categoryByCafeId = <String, String>{};

    for (final doc in cafeDocs) {
      if (!doc.exists) continue;

      final data = doc.data();
      final category = data?['category'];

      if (category is String && category.isNotEmpty) {
        categoryByCafeId[doc.id] = category;
      }
    }

    //counts every completed visit instead of only unique cafes
    final categoryCounts = <String, int>{};

    for (final bookingDoc in completedBookings.docs) {
      final cafeId = bookingDoc.data()['cafeId'];
      final category = categoryByCafeId[cafeId];

      if (category == null) continue;

      categoryCounts[category] =
          (categoryCounts[category] ?? 0) + 1;
    }

    final rankedCategories =
        categoryCounts.entries.toList()
          ..sort((a, b) {
            final countCompare =
                b.value.compareTo(a.value);

            //alphabetical tie-break keeps the result predictable
            if (countCompare != 0) {
              return countCompare;
            }

            return a.key.compareTo(b.key);
          });

    final preferredCategories = rankedCategories
        .map(
          (entry) => entry.key,
        )
        .toList();

    await usersRef.doc(userId).set(
      {
        'preferredCategories': preferredCategories,
      },
      SetOptions(merge: true),
    );
  }

  //adds or removes a cafe from the user's saved list
  Future<void> toggleSavedCafe(
    String uid,
    String cafeId,
    bool currentlySaved,
  ) {
    final docRef = usersRef.doc(uid);

    if (currentlySaved) {
      return docRef.update({
        'savedCafeIds': FieldValue.arrayRemove([
          cafeId,
        ]),
      });
    }

    return docRef.update({
      'savedCafeIds': FieldValue.arrayUnion([
        cafeId,
      ]),
    });
  }
}