import 'package:cafehop/models/cafe.dart';

//pairs a real Cafe with the AI's reasoning for recommending it
//kept separate from Cafe itself since the reason is specific to 1
//recommendation run, not a property of the cafe
class Recommendation {
  final Cafe cafe;
  final String reason;

  Recommendation({
    required this.cafe,
    required this.reason,
  });
}