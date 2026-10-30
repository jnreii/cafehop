import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String bookingId;
  final String cafeId;
  final String userId;

  final String reviewerName;
  final double rating;
  final String comment;
  final String postedAgo;
  final DateTime? postedAt;

  //multiple photos, empty list if none attached
  final List<String> photosBase64;

  const Review({
    this.id = '',
    this.bookingId = '',
    this.cafeId = '',
    this.userId = '',
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.postedAgo,
    this.postedAt,
    this.photosBase64 = const [],
  });

  //converts a firestore doc into a Review object
  factory Review.fromMap(String id, Map<String, dynamic> data) {
    final postedAt = (data['postedAt'] as Timestamp?)?.toDate();

    //older reviews only saved 1 photo under photoBase64, wrap it into a
    //list so old reviews still show up correctly
    List<String> photos = [];
    if (data['photosBase64'] != null) {
      photos = List<String>.from(data['photosBase64']);
    } else if (data['photoBase64'] != null) {
      photos = [data['photoBase64']];
    }

    return Review(
      id: id,
      bookingId: data['bookingId'] ?? '',
      cafeId: data['cafeId'] ?? '',
      userId: data['userId'] ?? '',
      reviewerName: data['reviewerName'] ?? 'CafeHop User',
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'] ?? '',
      postedAgo: postedAt == null ? '' : _formatPostedAgo(postedAt),
      postedAt: postedAt,
      photosBase64: photos,
    );
  }

  //converts a Review object into a map for firestore
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'cafeId': cafeId,
      'userId': userId,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'postedAt': Timestamp.fromDate(postedAt ?? DateTime.now()),
      //only write the field if photos were actually attached
      if (photosBase64.isNotEmpty) 'photosBase64': photosBase64,
    };
  }

  //turns the date into something shorter for the review card
  static String _formatPostedAgo(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}