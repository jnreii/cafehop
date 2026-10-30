import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/recommendation.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/services/applied_ai_service.dart';

//single shared instance of the Applied AI service
final appliedAIServiceProvider = Provider<AppliedAIService>((ref) {
  return AppliedAIService();
});

//builds personalised recommendations from the user's real Firestore activity
//and automatically falls back to top-rated cafes if AI isnt needed or fails
final recommendationsProvider =
    FutureProvider<List<Recommendation>>((ref) async {

  //get every provider/future BEFORE the first await
  //so we dont try to use ref after this provider has been disposed
  final cafesFuture = ref.watch(cafesProvider.future);
  final bookingsFuture = ref.watch(allBookingsProvider.future);
  final reviewsFuture = ref.watch(userReviewsProvider.future);
  final savedIds = ref.watch(savedCafeIdsProvider);
  final userDoc = ref.watch(userDocProvider).value;
  final aiService = ref.read(appliedAIServiceProvider);

  final cafes = await cafesFuture;
  final bookings = await bookingsFuture;
  final reviews = await reviewsFuture;

  //ranked preference profile stored in the user's firestore document
  final preferredCategories =
      userDoc?.preferredCategories ?? <String>[];

  if (cafes.isEmpty) {
    return [];
  }

  //makes cafe lookups easier using the cafe id
  final cafesById = {
    for (final cafe in cafes) cafe.id: cafe,
  };

  //turn the user's saved cafe ids into real Cafe objects
  final savedCafes = savedIds
      .map((id) => cafesById[id])
      .whereType<Cafe>()
      .toList();

  //only completed bookings count as actual visits
  final completedBookings = bookings
      .where((booking) => booking.status == 'completed')
      .toList();

  //dont remove duplicates here
  //if someone visits the same cafe/type repeatedly, thats useful signal
  final visitedCafes = completedBookings
      .map((booking) => cafesById[booking.cafeId])
      .whereType<Cafe>()
      .toList();

  //only reviews with 4 or 5 stars are treated as positive preferences
  //dont remove duplicate categories because repeated positive reviews
  //should count as a stronger preference signal
  final positivelyReviewedCategories = reviews
      .where((review) => review.rating >= 4)
      .map((review) => cafesById[review.cafeId]?.category)
      .whereType<String>()
      .toList();

  final hasUserSignal =
      savedCafes.isNotEmpty ||
      visitedCafes.isNotEmpty ||
      positivelyReviewedCategories.isNotEmpty;

  //cafes already saved or visited should normally not appear again
  final excludedIds = {
    ...savedIds,
    ...completedBookings.map((booking) => booking.cafeId),
  };

  var fallbackCafes = cafes
      .where((cafe) => !excludedIds.contains(cafe.id))
      .toList();

  //if the user somehow interacted with every cafe, still show something
  if (fallbackCafes.isEmpty) {
    fallbackCafes = List<Cafe>.from(cafes);
  }

  //deterministic fallback = highest rated first
  fallbackCafes.sort(
    (a, b) => b.rating.compareTo(a.rating),
  );

  final fallbackRecommendations = fallbackCafes
      .take(5)
      .map(
        (cafe) => Recommendation(
          cafe: cafe,
          reason: hasUserSignal
              ? 'Highly rated CafeHop pick'
              : 'Top-rated CafeHop pick',
        ),
      )
      .toList();

  //cold-start user has no meaningful preference history yet,
  //so dont waste an API call or pretend the AI knows them
  if (!hasUserSignal) {
    return fallbackRecommendations;
  }

  try {
    final aiRecommendations =
        await aiService.getRecommendations(
      allCafes: cafes,
      savedCafes: savedCafes,
      visitedCafes: visitedCafes,
      positivelyReviewedCategories:
          positivelyReviewedCategories,
      preferredCategories: preferredCategories,
      maxResults: 5,
    );

    //invalid/empty AI output automatically falls back
    if (aiRecommendations.isEmpty) {
      return fallbackRecommendations;
    }

    //if groq only returns e.g. 2 valid cafes, fill the remaining spaces
    //with the normal rating fallback instead of leaving the section half empty
    final combined =
        List<Recommendation>.from(aiRecommendations);

    final usedIds = combined
        .map((recommendation) => recommendation.cafe.id)
        .toSet();

    for (final fallback in fallbackRecommendations) {
      if (combined.length >= 5) {
        break;
      }

      if (!usedIds.contains(fallback.cafe.id)) {
        combined.add(fallback);
        usedIds.add(fallback.cafe.id);
      }
    }

    return combined;
  } catch (e) {
    //internet down, invalid API key, groq unavailable etc.
    //the app still works normally
    print('AI recommendation error: $e');
    return fallbackRecommendations;
  }
});