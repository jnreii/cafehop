import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? profilePhotoUrl;

  //cafe ids the user has bookmarked, stored here instead of in memory so
  //saved cafes persist across logout/reinstall
  final List<String> savedCafeIds;

  //categories taken from booking history, used later by the AI recommender
  final List<String> preferredCategories;

  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.profilePhotoUrl,
    this.savedCafeIds = const [],
    this.preferredCategories = const [],
    this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      profilePhotoUrl: data['profilePhotoUrl'],
      savedCafeIds: List<String>.from(data['savedCafeIds'] ?? []),
      preferredCategories: List<String>.from(data['preferredCategories'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profilePhotoUrl': profilePhotoUrl,
      'savedCafeIds': savedCafeIds,
      'preferredCategories': preferredCategories,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }
}