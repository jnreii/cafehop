import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/recommendation.dart';

class AppliedAIService {
  //passed in at build time: flutter run --dart-define=GROQ_API_KEY=your_key
  static const groqKey = String.fromEnvironment('GROQ_API_KEY');

  static const groqModel = 'llama-3.1-8b-instant';

  static const groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  //main entry point, builds the prompt from the user's real activity and
  //asks groq to rank cafes theyve never booked before
  Future<List<Recommendation>> getRecommendations({
    required List<Cafe> allCafes,
    required List<Cafe> savedCafes,
    required List<Cafe> visitedCafes,
    required List<String> positivelyReviewedCategories,
    required List<String> preferredCategories,
    int maxResults = 5,
  }) async {
    if (allCafes.isEmpty) {
      return [];
    }

    //cafes the user has already saved or visited shouldnt be recommended
    //again, theyve already found those
    final excludeIds = {
      ...savedCafes.map((c) => c.id),
      ...visitedCafes.map((c) => c.id),
    };

    final candidateCafes =
        allCafes.where((c) => !excludeIds.contains(c.id)).toList();

    if (candidateCafes.isEmpty) {
      //nothing left to recommend, user has saved/visited everything
      return [];
    }

    //dont ask for more recommendations than there are cafes available
    final resultLimit =
        maxResults > candidateCafes.length ? candidateCafes.length : maxResults;

    //turn the candidate cafes into simple lines the AI can read
    String cafeList = '';

    for (final c in candidateCafes) {
      final menuNames =
          c.menuItems.map((item) => item.name).take(4).join(', ');

      cafeList +=
          '${c.id} | '
          '${c.name} | '
          'category: ${c.category} | '
          'neighbourhood: ${c.neighbourhood} | '
          'price: ${c.priceRange} | '
          'rating: ${c.rating} | '
          'menu: $menuNames\n';
    }

    //saved cafes are interest signals, but dont necessarily mean a visit
    final savedList = savedCafes.isEmpty
        ? 'none'
        : savedCafes
            .map(
              (c) =>
                  '${c.name} '
                  '(category: ${c.category}, '
                  'neighbourhood: ${c.neighbourhood}, '
                  'price: ${c.priceRange})',
            )
            .join(', ');

    //completed visits are a stronger signal because the user actually went
    final visitedList = visitedCafes.isEmpty
        ? 'none'
        : visitedCafes
            .map(
              (c) =>
                  '${c.name} '
                  '(category: ${c.category}, '
                  'neighbourhood: ${c.neighbourhood}, '
                  'price: ${c.priceRange})',
            )
            .join(', ');

    //only positive reviews are treated as preference signals
    //repeated categories are intentionally kept because repeated positive
    //reviews are stronger evidence of a preference
    final reviewedList = positivelyReviewedCategories.isEmpty
        ? 'none'
        : positivelyReviewedCategories.join(', ');
    //ranked categories derived from completed booking history
    //the first category is currently the user's strongest preference
    final preferredList = preferredCategories.isEmpty
        ? 'none'
        : preferredCategories.join(', ');

    final prompt = '''
USER'S SAVED CAFES
These are interest signals. The user bookmarked them but may not have visited:
$savedList

USER'S COMPLETED VISITS
These are stronger signals because the user actually visited:
$visitedList

CATEGORIES THE USER REVIEWED POSITIVELY
Repeated categories indicate a stronger preference:
$reviewedList

USER'S RANKED PREFERRED CATEGORIES
This is derived from completed booking history and is ordered strongest first:
$preferredList

CANDIDATE CAFES
Only recommend cafes from this list:
$cafeList

Rank the cafes based on how well they match the user's demonstrated preferences.

Consider patterns in:
- cafe category
- neighbourhood
- price range
- menu items
- repeated interests or visits

Completed visits and positive reviews are stronger signals than saved cafes.
Use the ranked preferred categories as a summary of completed visit patterns,
not as a separate extra piece of evidence.

Use rating as a secondary factor, not the main reason for a personalised recommendation.

Return at most $resultLimit recommendations.

For every recommendation:
- use only an ID from CANDIDATE CAFES
- do not repeat an ID
- keep the reason under 8 words
- explain why this cafe matches this specific user's activity
- every reason must refer to a real pattern from the user's saved cafes, completed visits, or positive reviews
- do not give generic reasons based only on the candidate cafe's rating or popularity
- do not say "near you" or "in your area" because the user's live location is not provided
- do not claim the recommended cafe has a category unless that matches its actual candidate data
- do not invent preferences that are not supported by the activity above

GOOD REASONS:
"Similar to your saved matcha cafes"
"Matches your bakery visit history"
"Fits your preference for Tiong Bahru"
"Similar price to cafes you save"

BAD REASONS:
"Highly rated cafe"
"Popular bakery"
"Great reviews"
"Saved Matcha cafes in your area"

Return JSON in exactly this structure:

{
  "recommendations": [
    {
      "id": "cafe_id",
      "reason": "short personalised reason"
    }
  ]
}
''';

    final aiReply = await askGroq(prompt);

    return turnReplyIntoRecommendations(
      aiReply,
      candidateCafes,
      resultLimit,
    );
  }

  //sends the prompt to groq and returns whatever text it replies with
  Future<String> askGroq(String prompt) async {
    if (groqKey.isEmpty) {
      throw Exception('GROQ_API_KEY is missing.');
    }

    final response = await http
        .post(
          Uri.parse(groqUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $groqKey',
          },
          body: jsonEncode({
            'model': groqModel,

            //json mode means groq returns valid json rather than
            //sometimes wrapping the reply in markdown/code fences
            'response_format': {
              'type': 'json_object',
            },

            //low temperature keeps ranking more consistent between runs
            'temperature': 0.3,

            'messages': [
              {
                'role': 'system',
                'content':
                    'You are CafeHop\'s personalised cafe recommendation engine. '
                    'Use only the cafe data and user activity provided. '
                    'Respond only with valid JSON.',
              },
              {
                'role': 'user',
                'content': prompt,
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Groq API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    final choices = data['choices'];

    if (choices is! List || choices.isEmpty) {
      throw Exception('Groq returned no choices.');
    }

    final message = choices[0]['message'];

    if (message is! Map) {
      throw Exception('Groq returned an invalid message.');
    }

    final content = message['content'];

    if (content == null || content is! String || content.trim().isEmpty) {
      throw Exception('Groq returned an empty response.');
    }

    return content;
  }

  //reads the AI's JSON and matches each id back to a real Cafe,
  //pairing it with the reason the AI gave
  List<Recommendation> turnReplyIntoRecommendations(
    String aiReply,
    List<Cafe> candidateCafes,
    int maxResults,
  ) {
    final results = <Recommendation>[];

    //set instead of map, only used to remember ids already returned
    final usedIds = <String>{};

    final cafesById = {
      for (final cafe in candidateCafes) cafe.id: cafe,
    };

    try {
      final data = jsonDecode(aiReply);

      if (data is! Map<String, dynamic>) {
        return [];
      }

      final recommendations = data['recommendations'];

      if (recommendations is! List) {
        return [];
      }

      for (final rec in recommendations) {
        if (results.length >= maxResults) {
          break;
        }

        if (rec is! Map) {
          continue;
        }

        final id = rec['id'];
        final reason = rec['reason'];

        //ignore missing ids and repeated recommendations
        if (id is! String || usedIds.contains(id)) {
          continue;
        }

        //only ids from the real candidate list are accepted
        //any cafe hallucinated by the AI is ignored
        final matchedCafe = cafesById[id];

        if (matchedCafe == null) {
          continue;
        }

        usedIds.add(id);

        results.add(
          Recommendation(
            cafe: matchedCafe,
            reason: reason is String && reason.trim().isNotEmpty
                ? reason.trim()
                : 'Recommended for you',
          ),
        );
      }
    } catch (e) {
      //recommendationsProvider will use the normal rating fallback instead
      return [];
    }

    return results;
  }
}