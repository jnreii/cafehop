import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cafehop/services/firebase_service.dart';
import 'package:cafehop/models/bookings.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/user.dart';
import 'package:cafehop/models/review.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
}); //stream is sequence of events, captures user state login/logout

//upcoming bookings for the logged in user, live updating
final upcomingBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return service.getUpcomingBookings(user.uid);
    },
    loading: () => Stream.value([]),
    error: (e, _) => Stream.value([]),
  );
});

//past bookings for the logged in user
final pastBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return service.getPastBookings(user.uid);
    },
    loading: () => Stream.value([]),
    error: (e, _) => Stream.value([]),
  );
});

//all bookings for the logged in user, used to find bookings that have passed
//but still need the user to confirm whether they attended
final allBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return service.getAllBookings(user.uid);
    },
    loading: () => Stream.value([]),
    error: (e, _) => Stream.value([]),
  );
});

//every cafe, live from firestore
final cafesProvider = StreamProvider<List<Cafe>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  return service.getCafes();
});

//the logged in user's own document, includes savedCafeIds
final userDocProvider = StreamProvider<AppUser?>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return service.getUserDoc(user.uid);
    },
    loading: () => Stream.value(null),
    error: (e, _) => Stream.value(null),
  );
});

//just the saved cafe ids, derived from the user doc so Explore and Saved
//both read the same live source instead of separate local state
final savedCafeIdsProvider = Provider<Set<String>>((ref) {
  final userDoc = ref.watch(userDocProvider).value;
  return userDoc == null ? {} : userDoc.savedCafeIds.toSet();
});

//reviews written by the logged in user, used as another AI preference signal
final userReviewsProvider = StreamProvider<List<Review>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return service.getUserReviews(user.uid);
    },
    loading: () => Stream.value([]),
    error: (e, _) => Stream.value([]),
  );
});