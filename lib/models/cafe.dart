class MenuItem {
  final String name;
  final double price;

  MenuItem({
    required this.name,
    required this.price,
  });

  factory MenuItem.fromMap(Map<String, dynamic> data) {
    return MenuItem(
      name: data['name'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }
}


//one day's opening hours + booking slots
//times are stored as 24hr strings, e.g. 18:30 = 6:30PM
class DaySchedule {
  final String openTime;
  final String closeTime;
  final List<String> timeSlots;

  const DaySchedule({
    required this.openTime,
    required this.closeTime,
    required this.timeSlots,
  });

  factory DaySchedule.fromMap(Map<String, dynamic> data) {
    return DaySchedule(
      openTime: data['openTime'] ?? '09:00',
      closeTime: data['closeTime'] ?? '18:00',
      timeSlots: List<String>.from(data['timeSlots'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'openTime': openTime,
      'closeTime': closeTime,
      'timeSlots': timeSlots,
    };
  }
}


class Cafe {
  final String id;
  final String name;
  final String category;
  final String neighbourhood;
  final String address;
  final String description;
  final double rating;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final bool hasSeats;
  final double depositAmount;
  final int maxPax;
  final String distance;
  final String priceRange;
  final String nearestMrt;
  final List<MenuItem> menuItems;

  //each open day can have its own opening hours and booking slots
  //key uses DateTime.weekday: 1=Mon ... 7=Sun
  final Map<int, DaySchedule> weeklySchedule;

  Cafe({
    required this.id,
    required this.name,
    required this.category,
    required this.neighbourhood,
    required this.address,
    required this.description,
    required this.rating,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.hasSeats,
    required this.depositAmount,
    required this.maxPax,
    required this.distance,
    required this.priceRange,
    required this.nearestMrt,
    required this.menuItems,
    required this.weeklySchedule,
  });


  static const List<String> _dayNames = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];


  //turns "18:30" into minutes since midnight
  //makes comparing opening times easier
  int _timeToMinutes(String time) {
    final parts = time.split(':');

    if (parts.length != 2) return 0;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return (hour * 60) + minute;
  }


  //gets the schedule for a specific date
  DaySchedule? scheduleForDate(DateTime date) {
    return weeklySchedule[date.weekday];
  }


  //gets only the booking slots for the selected date
  List<String> timeSlotsForDate(DateTime date) {
    return scheduleForDate(date)?.timeSlots ?? [];
  }


  //true if the cafe is open right now, based on real device time
  bool get isOpenNow {
    final now = DateTime.now();
    final schedule = scheduleForDate(now);

    if (schedule == null) return false;

    final nowMinutes = (now.hour * 60) + now.minute;
    final openMinutes = _timeToMinutes(schedule.openTime);
    final closeMinutes = _timeToMinutes(schedule.closeTime);

    return nowMinutes >= openMinutes &&
        nowMinutes < closeMinutes;
  }


  //true if the cafe is open on the given date, ignores time of day
  bool isOpenOnDate(DateTime date) {
    return scheduleForDate(date) != null;
  }


  //Open Now / Closed - Opens [day] [time], computed live
  String get status {
    if (isOpenNow) return 'Open Now';

    for (int i = 0; i < 8; i++) {
      final checkDate = DateTime.now().add(Duration(days: i));
      final schedule = scheduleForDate(checkDate);

      if (schedule != null) {
        final dayLabel =
            i == 0 ? 'today' : _dayNames[checkDate.weekday];

        final parts = schedule.openTime.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute =
            parts.length > 1 ? parts[1] : '00';

        final displayHour = hour > 12
            ? hour - 12
            : (hour == 0 ? 12 : hour);

        final period = hour >= 12 ? 'PM' : 'AM';

        final timeLabel = minute == '00'
            ? '$displayHour$period'
            : '$displayHour:$minute$period';

        return 'Closed • Opens $dayLabel $timeLabel';
      }
    }

    return 'Closed';
  }


  //human readable opening hours
  String get openingHoursDisplay {
    if (weeklySchedule.isEmpty) {
      return 'Hours not available';
    }

    final sortedDays = weeklySchedule.keys.toList()
      ..sort();

    final parts = <String>[];

    for (final day in sortedDays) {
      final schedule = weeklySchedule[day]!;

      parts.add(
        '${_dayNames[day]} '
        '${schedule.openTime} - ${schedule.closeTime}',
      );
    }

    return parts.join(' • ');
  }


  factory Cafe.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    //Firestore map keys are strings,
    //so convert "6" back into weekday 6
    final Map<int, DaySchedule> weeklySchedule = {};

    final rawSchedule = data['weeklySchedule'];

    if (rawSchedule is Map) {
      rawSchedule.forEach((key, value) {
        final day = int.tryParse(key.toString());

        if (day != null && value is Map) {
          weeklySchedule[day] =
              DaySchedule.fromMap(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return Cafe(
      id: id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      neighbourhood: data['neighbourhood'] ?? '',
      address: data['address'] ?? '',
      description: data['description'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      imageUrl: data['imageUrl'] ?? '',
      latitude:
          (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude:
          (data['longitude'] as num?)?.toDouble() ?? 0,
      hasSeats: data['hasSeats'] ?? false,
      depositAmount:
          (data['depositAmount'] as num?)?.toDouble() ?? 0,
      maxPax:
          (data['maxPax'] as num?)?.toInt() ?? 1,
      distance: data['distance'] ?? '',
      priceRange: data['priceRange'] ?? '',
      nearestMrt: data['nearestMrt'] ?? '',

      menuItems: (data['menuItems'] as List? ?? [])
          .map(
            (m) => MenuItem.fromMap(
              Map<String, dynamic>.from(m),
            ),
          )
          .toList(),

      weeklySchedule: weeklySchedule,
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'neighbourhood': neighbourhood,
      'address': address,
      'description': description,
      'rating': rating,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'hasSeats': hasSeats,
      'depositAmount': depositAmount,
      'maxPax': maxPax,
      'distance': distance,
      'priceRange': priceRange,
      'nearestMrt': nearestMrt,

      'menuItems':
          menuItems.map((m) => m.toMap()).toList(),

      //Firestore map keys need to be strings
      'weeklySchedule': weeklySchedule.map(
        (day, schedule) => MapEntry(
          day.toString(),
          schedule.toMap(),
        ),
      ),
    };
  }
}