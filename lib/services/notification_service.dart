import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafehop/models/bookings.dart';
import 'package:cafehop/models/cafe.dart';


class NotificationService {
  static final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  static const String _bookingReminderKey = 'bookingReminders';
  static const String _visitReminderKey = 'visitReminders';
  static const String _recommendationKey = 'recommendationNotifications';

  //sets up local notifications for android
  static Future<void> initialize({
    void Function(String?)? onNotificationTap,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    //CafeHop bookings are all in Singapore
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Singapore'));

    //uses the current CafeHop launcher icon for now
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
  }

  //checks if the app was opened by tapping a notification
  static Future<String?> getLaunchPayload() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final details =
        await notifications.getNotificationAppLaunchDetails();

    if (details?.didNotificationLaunchApp != true) {
      return null;
    }

    return details?.notificationResponse?.payload;
  }

  //asks the user for notification and exact alarm permission
  static Future<bool> requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final notificationPermission =
        await androidPlugin?.requestNotificationsPermission() ?? false;

    final exactAlarmPermission =
        await androidPlugin?.requestExactAlarmsPermission() ?? false;

    return notificationPermission && exactAlarmPermission;
  }

  //notification settings are saved on the device
  static Future<bool> bookingRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bookingReminderKey) ?? true;
  }

  static Future<bool> visitRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_visitReminderKey) ?? true;
  }

  static Future<bool> recommendationNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_recommendationKey) ?? true;
  }

  static Future<void> setBookingRemindersEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bookingReminderKey, value);
  }

  static Future<void> setVisitRemindersEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visitReminderKey, value);
  }

  static Future<void> setRecommendationNotificationsEnabled(
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_recommendationKey, value);
  }

  //makes a consistent notification id for each booking + notification type
  static int _notificationId(Booking booking, String type) {
    final key =
        '$type|${booking.userId}|${booking.cafeId}|'
        '${booking.dateTime.year}|${booking.dateTime.month}|'
        '${booking.dateTime.day}|${booking.dateTime.hour}|'
        '${booking.dateTime.minute}';

    int hash = 0;

    for (final codeUnit in key.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }

    return hash;
  }

  //schedules a reminder 24 hours before the booking
  static Future<void> scheduleBookingReminder(Booking booking) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (!await bookingRemindersEnabled()) {
      return;
    }

    final bookingTime = tz.TZDateTime(
      tz.local,
      booking.dateTime.year,
      booking.dateTime.month,
      booking.dateTime.day,
      booking.dateTime.hour,
      booking.dateTime.minute,
    );

    final reminderTime =
        bookingTime.subtract(const Duration(hours: 24));

    //dont schedule if the 24 hour reminder time has already passed
    if (!reminderTime.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'cafehop_booking_reminders',
      'Booking Reminders',
      channelDescription: 'Reminders for upcoming CafeHop bookings',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await notifications.zonedSchedule(
      id: _notificationId(booking, 'booking'),
      title: 'Booking reminder ☕',
      body:
          '${booking.cafeName} • '
          '${DateFormat('EEE, d MMM • h:mm a').format(booking.dateTime)}',
      scheduledDate: reminderTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'booking:${booking.id}',
    );
  }

  //asks how the visit went once the cafe session should be over
  static Future<void> scheduleVisitReminder(Booking booking) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (!await visitRemindersEnabled()) {
      return;
    }

    final bookingTime = tz.TZDateTime(
      tz.local,
      booking.dateTime.year,
      booking.dateTime.month,
      booking.dateTime.day,
      booking.dateTime.hour,
      booking.dateTime.minute,
    );

    //matches the 2 hour visit window used in the bookings screen
    final reminderTime =
        bookingTime.add(const Duration(hours: 2));

    if (!reminderTime.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'cafehop_visit_reminders',
      'Visit Reminders',
      channelDescription: 'Follow-ups after CafeHop visits',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await notifications.zonedSchedule(
      id: _notificationId(booking, 'visit'),
      title: 'How did your visit go?',
      body: 'Tell us about your visit to ${booking.cafeName}.',
      scheduledDate: reminderTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'visit:${booking.id}',
    );
  }

  //schedules both notifications belonging to one booking
  static Future<void> scheduleBookingNotifications(
    Booking booking,
  ) async {
    await scheduleBookingReminder(booking);
    await scheduleVisitReminder(booking);
  }

  //removes both notifications if a booking is changed or cancelled
  static Future<void> cancelBookingNotifications(
    Booking booking,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await notifications.cancel(
      id: _notificationId(booking, 'booking'),
    );

    await notifications.cancel(
      id: _notificationId(booking, 'visit'),
    );
  }

  //removes pending notifications of one type
  static Future<void> _cancelPendingType(String payload) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final pending =
        await notifications.pendingNotificationRequests();

    for (final notification in pending) {
      if (notification.payload == payload ||
          notification.payload?.startsWith('$payload:') == true) {
        await notifications.cancel(id: notification.id);
      }
    }
  }

  //updates already scheduled notifications after the user changes settings
  static Future<void> syncBookingNotifications(
    List<Booking> bookings,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _cancelPendingType('booking');
    await _cancelPendingType('visit');

    final upcomingBookings =
        bookings.where((booking) => booking.status == 'upcoming');

    for (final booking in upcomingBookings) {
      await scheduleBookingNotifications(booking);
    }
  }

  //makes the same notification id for the same recommended cafe
  static int _recommendationNotificationId(String cafeId) {
    final key = 'recommendation|$cafeId';

    int hash = 0;

    for (final codeUnit in key.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }

    return hash;
  }

  //shows a notification when a newly added cafe appears in Just For You
  static Future<void> showRecommendationNotification(Cafe cafe) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (!await recommendationNotificationsEnabled()) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'cafehop_recommendations',
      'Cafe Recommendations',
      channelDescription: 'New cafes matching your CafeHop preferences',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await notifications.show(
      id: _recommendationNotificationId(cafe.id),
      title: 'New cafe match ✨',
      body: 'You might like ${cafe.name} in ${cafe.neighbourhood}.',
      notificationDetails: details,
      payload: 'recommendation:${cafe.id}',
    );
  }

  //checks if firestore has received any new cafes and only notifies
  //if the new cafe was also selected by the AI recommender
  static Future<void> checkForNewRecommendationMatches({
    required String userId,
    required List<Cafe> cafes,
    required Set<String> recommendedCafeIds,
    required bool hasPreferences,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    //saved separately for each user on the device
    final knownCafeKey = 'knownCafeIds_$userId';

    final currentCafeIds =
        cafes.map((cafe) => cafe.id).toSet();

    final storedCafeIds =
        prefs.getStringList(knownCafeKey);

    //first time this feature runs, remember the current catalogue
    //without sending notifications for cafes that already existed
    if (storedCafeIds == null) {
      await prefs.setStringList(
        knownCafeKey,
        currentCafeIds.toList(),
      );
      return;
    }

    final knownCafeIds = storedCafeIds.toSet();

    final newCafeIds =
        currentCafeIds.difference(knownCafeIds);

    if (newCafeIds.isNotEmpty &&
        hasPreferences &&
        await recommendationNotificationsEnabled()) {
      for (final cafe in cafes) {
        final isNew = newCafeIds.contains(cafe.id);
        final isRecommended =
            recommendedCafeIds.contains(cafe.id);

        if (isNew && isRecommended) {
          await showRecommendationNotification(cafe);
        }
      }
    }

    //remember the latest catalogue even if notifications are switched off,
    //so old cafes dont suddenly notify the user when they turn them back on
    await prefs.setStringList(
      knownCafeKey,
      currentCafeIds.toList(),
    );
  }
}