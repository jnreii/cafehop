import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;

  //who made the booking, used to filter bookings per user
  final String userId;

  //denormalised cafe info so the bookings list doesnt need a 2nd read
  final String cafeId;
  final String cafeName;
  final String cafeAddress;
  final String cafeImageUrl;

  final DateTime dateTime;
  final int pax;
  final double depositAmount;

  //upcoming / completed / cancelled / missed
  String status;

  Booking({
    required this.id,
    required this.userId,
    required this.cafeId,
    required this.cafeName,
    required this.cafeAddress,
    required this.cafeImageUrl,
    required this.dateTime,
    required this.pax,
    required this.depositAmount,
    required this.status,
  });

  //converts a firestore doc into a Booking object
  //Timestamp is firestores own date type, need .toDate() to get DateTime
  factory Booking.fromMap(String id, Map<String, dynamic> data) {
    return Booking(
      id: id,
      userId: data['userId'] ?? '',
      cafeId: data['cafeId'] ?? '',
      cafeName: data['cafeName'] ?? '',
      cafeAddress: data['cafeAddress'] ?? '',
      cafeImageUrl: data['cafeImageUrl'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      pax: data['pax'] ?? 1,
      depositAmount: (data['depositAmount'] ?? 0).toDouble(),
      status: data['status'] ?? 'upcoming',
    );
  }

  //converts a Booking object into a map for firestore
  //no id here, firestore generates the doc id itself
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'cafeId': cafeId,
      'cafeName': cafeName,
      'cafeAddress': cafeAddress,
      'cafeImageUrl': cafeImageUrl,
      'dateTime': Timestamp.fromDate(dateTime),
      'pax': pax,
      'depositAmount': depositAmount,
      'status': status,
    };
  }
}