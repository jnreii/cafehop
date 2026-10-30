import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/bookings.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';
import 'package:cafehop/services/notification_service.dart';

class BookingFormScreen extends ConsumerStatefulWidget {
  static String routeName = '/booking-form';

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  int selectedDateIndex = 0;
  String? selectedTimeSlot;
  int pax = 2;

  //current cafe being booked, needed to get its day-specific time slots
  Cafe? currentCafe;

  //when non-null, screen behaves as a pre-filled edit view instead of a fresh form
  Booking? existingBooking;
  bool _initialized = false;

  //shows a loader while the cafe is being fetched from firestore in edit mode
  bool _isCafeLoading = false;

  //stores an error if the cafe could not be found in firestore
  String? _cafeLoadError;

  //stops the save button being tapped twice while the write is still going
  bool _isLoading = false;

  //users need at least 30 minutes notice before a home cafe booking
  static const Duration _minimumBookingNotice = Duration(minutes: 30);

  //dates this cafe is actually open within the next 14 days
  List<DateTime> availableDates = [];

  //time slots already taken by another upcoming booking
  Set<String> bookedTimeSlots = {};

  //shows a small loader while firestore checks the selected date
  bool _isLoadingBookedSlots = false;

  //prevents an older firestore request overwriting a newer selected date
  int _slotRequestId = 0;

  //turns a stored slot like 18:30 into a DateTime on the selected date
  DateTime _getSlotDateTime(DateTime date, String storedTime) {
    final parsedTime = DateFormat('HH:mm').parse(storedTime);

    return DateTime(
      date.year,
      date.month,
      date.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  //checks if a time slot is still far enough away to be booked
  bool _isSlotBookable(DateTime date, String storedTime) {
    final slotDateTime = _getSlotDateTime(date, storedTime);

    //when editing, keep the user's own existing slot selectable
    //even if it has now entered the 30 minute notice window
    if (existingBooking != null &&
        slotDateTime.year == existingBooking!.dateTime.year &&
        slotDateTime.month == existingBooking!.dateTime.month &&
        slotDateTime.day == existingBooking!.dateTime.day &&
        slotDateTime.hour == existingBooking!.dateTime.hour &&
        slotDateTime.minute == existingBooking!.dateTime.minute) {
      return slotDateTime.isAfter(DateTime.now());
    }

    final earliestBookableTime =
        DateTime.now().add(_minimumBookingNotice);

    return !slotDateTime.isBefore(earliestBookableTime);
  }

  //checks the next 14 days and only keeps dates the cafe is open
  //today is hidden if all of today's booking slots have already passed
  List<DateTime> _getAvailableDates(Cafe cafe) {
    List<DateTime> dates = [];

    final now = DateTime.now();

    //remove the current time so we are only comparing calendar dates
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    for (int i = 0; i < 14; i++) {
      final date = today.add(Duration(days: i));

      if (!cafe.isOpenOnDate(date)) {
        continue;
      }

      final slots = cafe.timeSlotsForDate(date);

      //pickup-only cafes or days with no table sessions shouldnt appear
      if (slots.isEmpty) {
        continue;
      }

      //for today, only show the date if at least 1 slot can still be booked
      if (i == 0) {
        final hasBookableSlot = slots.any(
          (slot) => _isSlotBookable(date, slot),
        );

        if (!hasBookableSlot) {
          continue;
        }
      }

      dates.add(date);
    }

    return dates;
  }

  String _getMonthLabel(DateTime date) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[date.month - 1];
  }

  String _getDayLabel(DateTime date) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.weekday % 7]; //returns sunday when weekday is 7, so mod 7 gives 0 for sunday
  }

  String _formatSlotTime(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  //turns the stored 24hr time, e.g. 18:30, into 6:30 PM for the UI
  String _formatStoredTime(String time) {
    final parsedTime = DateFormat('HH:mm').parse(time);
    return DateFormat('h:mm a').format(parsedTime);
  }

  //gets the correct slots for whichever cafe + date is currently selected
  //and removes slots that are already past or less than 30 minutes away
  List<String> get availableTimeSlots {
    if (currentCafe == null || availableDates.isEmpty) {
      return [];
    }

    final selectedDate = availableDates[selectedDateIndex];

    return currentCafe!
        .timeSlotsForDate(selectedDate)
        .where((time) => _isSlotBookable(selectedDate, time))
        .map((time) => _formatStoredTime(time))
        .toList();
  }

  //checks firestore for slots that already have an upcoming booking
  Future<void> _loadBookedTimeSlots() async {
    if (currentCafe == null || availableDates.isEmpty) {
      return;
    }

    //each request gets its own number so if the user taps dates quickly,
    //an older request cant overwrite the latest selected date
    final requestId = ++_slotRequestId;
    final selectedDate = availableDates[selectedDateIndex];

    setState(() {
      _isLoadingBookedSlots = true;
      bookedTimeSlots = {};
    });

    try {
      final slots = await ref
          .read(firebaseServiceProvider)
          .getBookedTimeSlots(
            currentCafe!.id,
            selectedDate,
            excludeBookingId: existingBooking?.id,
          );

      //ignore the result if the user already selected another date
      if (!mounted || requestId != _slotRequestId) {
        return;
      }

      setState(() {
        bookedTimeSlots = slots;
        _isLoadingBookedSlots = false;

        //if a slot becomes unavailable while selected, clear it
        if (selectedTimeSlot != null &&
            bookedTimeSlots.contains(selectedTimeSlot)) {
          selectedTimeSlot = null;
        }
      });
    } catch (e) {
      if (!mounted || requestId != _slotRequestId) {
        return;
      }

      setState(() {
        _isLoadingBookedSlots = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not check booking availability. $e'),
        ),
      );
    }
  }

  //sets up the cafe's available dates and prefills
  //date/time/pax if editing an existing booking
  void _setupCafe(Cafe cafe) {
    currentCafe = cafe;

    //only show dates this cafe is actually open and still bookable
    availableDates = _getAvailableDates(cafe);

    if (existingBooking != null) {
      //first match the booking's date to one of this cafe's open dates
      final index = availableDates.indexWhere(
        (d) =>
            d.year == existingBooking!.dateTime.year &&
            d.month == existingBooking!.dateTime.month &&
            d.day == existingBooking!.dateTime.day,
      );

      if (index != -1) {
        selectedDateIndex = index;
      }

      //then check the time against that specific day's available slots
      final formattedTime = _formatSlotTime(existingBooking!.dateTime);

      if (availableTimeSlots.contains(formattedTime)) {
        selectedTimeSlot = formattedTime;
      }
    }

    //wait until the first frame is built before starting the firestore check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBookedTimeSlots();
      }
    });
  }

  //edit mode only has the cafe id in the booking,
  //so fetch the full cafe directly from firestore
  Future<void> _loadCafeForEdit(Booking booking) async {
    setState(() {
      _isCafeLoading = true;
      _cafeLoadError = null;
    });

    try {
      final cafe = await ref
          .read(firebaseServiceProvider)
          .getCafeById(booking.cafeId);

      if (!mounted) return;

      if (cafe == null) {
        setState(() {
          _isCafeLoading = false;
          _cafeLoadError = 'Could not find this cafe.';
        });
        return;
      }

      setState(() {
        _isCafeLoading = false;
        _setupCafe(cafe);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCafeLoading = false;
        _cafeLoadError = 'Could not load cafe details. Please try again.';
      });
    }
  }

  //runs once to setup the cafe's available dates and prefill
  //date/time/pax if editing an existing booking
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments;

      _initialized = true;

      if (args is Booking) {
        existingBooking = args;
        pax = args.pax;

        //fetch the actual cafe from firestore instead of sample data
        _loadCafeForEdit(args);
      } else {
        //new bookings already receive a Cafe object that came from firestore
        _setupCafe(args as Cafe);
      }
    }
  }

  //rebuilds the booking with the newly picked date/time/pax and
  //saves it, keeping everything else (cafe info, deposit, status) the same
  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final date = availableDates[selectedDateIndex];
      final parsedTime = DateFormat('h:mm a').parse(selectedTimeSlot!);
      final newDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      final updatedBooking = Booking(
        id: existingBooking!.id,
        userId: existingBooking!.userId,
        cafeId: existingBooking!.cafeId,
        cafeName: existingBooking!.cafeName,
        cafeAddress: existingBooking!.cafeAddress,
        cafeImageUrl: existingBooking!.cafeImageUrl,
        dateTime: newDateTime,
        pax: pax,
        depositAmount: existingBooking!.depositAmount,
        status: existingBooking!.status,
      );

      await ref.read(firebaseServiceProvider).updateBooking(updatedBooking);

      //remove the reminder for the old slot and schedule the new one
      try {
        await NotificationService.cancelBookingNotifications(existingBooking!);
        await NotificationService.scheduleBookingNotifications(updatedBooking);
      } catch (e) {
        print('Could not update booking reminder: $e');
      }

      if (mounted) {
        Navigator.of(context).pop(); //close this screen, back to booking detail
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking updated.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save changes. $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  //edit confirmation dialog
  void _showEditStub(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Changes?'),
          content: const Text('Are you sure you want to save these changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _saveChanges();
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    //gets the colours from the theme the user picked
    final selectedTheme = ref.watch(themeProvider);

    final bool isEditing = existingBooking != null;

    //edit mode needs to fetch the cafe from firestore before the form can show
    if (_isCafeLoading || currentCafe == null) {
      return Scaffold(
        backgroundColor: creamBackground,
        appBar: CafeHopAppBar(showBackButton: true),
        body: Center(
          child: _cafeLoadError == null
              ? CircularProgressIndicator(
                  color: selectedTheme.dark,
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _cafeLoadError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: secondaryText,
                    ),
                  ),
                ),
        ),
      );
    }

    final Cafe cafe = currentCafe!;

    return Scaffold(
      backgroundColor: creamBackground,

      appBar: CafeHopAppBar(showBackButton: true),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: creamBackground,
          border: Border(
            top: BorderSide(color: Colors.black12, width: 1),
          ),
        ),
        child: Container(
          decoration: primaryButtonDecoration,
          child: ElevatedButton(
            //disabled until a time slot is picked, or while saving/checking slots
            onPressed: (availableDates.isEmpty ||
                    selectedTimeSlot == null ||
                    _isLoading ||
                    _isLoadingBookedSlots)
                ? null
                : () {
                    if (isEditing) {
                      //edit flow
                      _showEditStub(context);
                    } else {
                      //new booking flow
                      Navigator.of(context).pushNamed(
                        '/booking-summary',
                        arguments: {
                          'cafe': cafe,
                          'date': availableDates[selectedDateIndex],
                          'time': selectedTimeSlot,
                          'pax': pax,
                        },
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedTheme.dark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.black26,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isEditing ? 'SAVE CHANGES →' : 'CONFIRM BOOKING →',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            //cafe image with black outline frame
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderBlack, width: 1.8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    cafe.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  //cafe name, with an "Editing" tag when in edit mode
                  Row(
                    children: [
                      Text(
                        cafe.name,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: borderBlack,
                        ),
                      ),
                      if (isEditing) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: selectedTheme.tag,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Editing',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: selectedTheme.dark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  //select date label
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: borderBlack),
                      const SizedBox(width: 6),
                      Text(
                        'SELECT DATE',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: borderBlack,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  //horizontal date strip
                  if (availableDates.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderBlack,
                          width: 1.8,
                        ),
                      ),
                      child: Text(
                        'No booking dates available in the next 14 days.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: secondaryText,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableDates.length,
                        itemBuilder: (ctx, i) {
                          final date = availableDates[i];
                          bool isSelected = selectedDateIndex == i;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                selectedDateIndex = i;

                                //different days can have different time slots,
                                //so reset the selected time when the date changes
                                selectedTimeSlot = null;
                              });

                              //check firestore again for the newly selected date
                              _loadBookedTimeSlots();
                            },
                            child: Container(
                              width: 64,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? selectedTheme.primary : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: borderBlack,
                                  width: 1.8,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black,
                                          blurRadius: 0,
                                          offset: Offset(3.6, 3.6),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getMonthLabel(date),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: isSelected
                                          ? Colors.white70
                                          : borderBlack,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    date.day.toString(),
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 24,
                                      color: isSelected
                                          ? Colors.white
                                          : borderBlack,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    _getDayLabel(date),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: isSelected
                                          ? Colors.white70
                                          : borderBlack,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  //number of pax
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.black26, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Number of Pax',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B1C1C),
                              ),
                            ),
                            Text(
                              'Max ${cafe.maxPax} guests per table',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: tabInactiveText,
                              ),
                            ),
                          ],
                        ),
                        //pax selector, white minus and themed plus button
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EDED),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Row(
                            children: [
                              //white circle, wont go below 1 pax
                              InkWell(
                                customBorder: CircleBorder(),
                                onTap: () {
                                  if (pax > 1) {
                                    setState(() {
                                      pax--;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.remove,
                                      size: 18, color: borderBlack),
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  pax.toString(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B1C1C),
                                  ),
                                ),
                              ),
                              //capped at cafe.maxPax
                              InkWell(
                                customBorder: CircleBorder(),
                                onTap: () {
                                  if (pax < cafe.maxPax) {
                                    setState(() {
                                      pax++;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: selectedTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.add,
                                      size: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  //select time label
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 16, color: borderBlack),
                      const SizedBox(width: 6),
                      Text(
                        'SELECT TIME',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: borderBlack,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Bookings close 30 minutes before each session.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: secondaryText,
                    ),
                  ),

                  const SizedBox(height: 12),

                  //time slot grid
                  if (_isLoadingBookedSlots)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: selectedTheme.dark,
                          ),
                        ),
                      ),
                    )
                  else if (availableTimeSlots.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderBlack,
                          width: 1.8,
                        ),
                      ),
                      child: Text(
                        'No table booking slots available for this day.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: secondaryText,
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics:
                          NeverScrollableScrollPhysics(), //disable scrolling, let the outer SingleChildScrollView handle it
                      //sliver grid delegate to create a 2-column grid with spacing and aspect ratio
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 3,
                      ),
                      itemCount: availableTimeSlots.length,
                      itemBuilder: (ctx, i) {
                        final slot = availableTimeSlots[i];

                        final bool isBooked =
                            bookedTimeSlots.contains(slot);

                        final bool isSelected =
                            selectedTimeSlot == slot && !isBooked;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),

                          //booked sessions stay visible but cant be selected
                          onTap: isBooked
                              ? null
                              : () {
                                  setState(() {
                                    selectedTimeSlot = slot;
                                  });
                                },

                          child: Container(
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? const Color(0xFFF0EEEE)
                                  : isSelected
                                      ? selectedTheme.dark
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isBooked
                                    ? Colors.black26
                                    : borderBlack,
                                width: 1.8,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black,
                                        blurRadius: 0,
                                        offset: Offset(3.6, 3.6),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: isBooked
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          slot,
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: Colors.black38,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'BOOKED',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            color: Colors.black38,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      slot,
                                      style:
                                          GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: isSelected
                                            ? Colors.white
                                            : borderBlack,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}