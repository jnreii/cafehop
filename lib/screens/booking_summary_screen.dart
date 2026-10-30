import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:intl/intl.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/bookings.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/providers/nets_provider.dart';
import 'package:cafehop/screens/main_screen.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';
import 'package:cafehop/widgets/nets_widget.dart';
import 'package:cafehop/services/notification_service.dart';

class BookingSummaryScreen extends ConsumerStatefulWidget {
  static String routeName = '/booking-summary';

  @override
  ConsumerState<BookingSummaryScreen> createState() =>
      _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends ConsumerState<BookingSummaryScreen> {
  //true once the user taps Pay, then the body swaps to the NETS QR flow
  bool _paymentStarted = false;

  //NETS has to be selected before the Pay button can be used
  bool _isNetsSelected = false;

  //stops the same booking being created twice if the success listener fires
  //more than once for the same payment
  bool _bookingCreated = false;

  //stores the firestore write so the success screen waits for it
  //before saying the booking is confirmed
  Future<bool>? _bookingCreationFuture;

  //saved once when Pay is tapped and reused by the success handler so the
  //final availability re-check uses the exact same slot the user paid for
  Cafe? _cafe;
  DateTime? _date;
  String? _time;
  int? _pax;

  void _startPayment(Cafe cafe, DateTime date, String time, int pax) {
    _cafe = cafe;
    _date = date;
    _time = time;
    _pax = pax;
    _bookingCreated = false;
    _bookingCreationFuture = null;

    setState(() {
      _paymentStarted = true;
    });
  }

  //final availability check right before writing the booking,
  //the slot was checked in the form but the NETS payment
  //window can take a few minutes, so another user could take it
  //before this booking gets saved
  Future<bool> _createBookingAfterPayment() async {
    final cafe = _cafe!;
    final date = _date!;
    final time = _time!;
    final pax = _pax!;

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final user = firebaseService.getCurrentUser();

      final parsedTime = DateFormat('h:mm a').parse(time);
      final slotDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      //re-check the exact same slot one more time
      final stillBooked = await firebaseService.getBookedTimeSlots(
        cafe.id,
        slotDateTime,
      );

      final formattedSlot = DateFormat('h:mm a').format(slotDateTime);

      if (stillBooked.contains(formattedSlot)) {
        //slot was taken while the user was paying
        //the lab NETS flow doesnt include the ReversalAPI, so a real
        //refund isnt automated here and the user is told clearly
        //instead of pretending it already happened
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Slot No Longer Available'),
              content: const Text(
                'Sorry, this time slot was just taken by another booking. '
                'Your deposit will be manually refunded. Please choose a '
                'different time.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );

          if (mounted) {
            //back to the booking form so they can pick another slot
            Navigator.of(context).pop();
          }
        }

        return false;
      }

      final booking = Booking(
        id: '', //firestore makes the id, we dont set it here
        userId: user?.uid ?? '',
        cafeId: cafe.id,
        cafeName: cafe.name,
        cafeAddress: cafe.address,
        cafeImageUrl: cafe.imageUrl,
        dateTime: slotDateTime,
        pax: pax,
        //copy the deposit at booking time, so it stays correct if the cafe
        //changes their price later
        depositAmount: cafe.depositAmount,
        status: 'upcoming',
      );

      final bookingRef =
          await firebaseService.addBooking(booking);

      //same booking but now with the real firestore document id
      final savedBooking = Booking(
        id: bookingRef.id,
        userId: booking.userId,
        cafeId: booking.cafeId,
        cafeName: booking.cafeName,
        cafeAddress: booking.cafeAddress,
        cafeImageUrl: booking.cafeImageUrl,
        dateTime: booking.dateTime,
        pax: booking.pax,
        depositAmount: booking.depositAmount,
        status: booking.status,
      );

      //schedule notifications after the booking is safely saved
      try {
        await NotificationService.scheduleBookingNotifications(
          savedBooking,
        );
      } catch (e) {
        print('Could not schedule booking reminder: $e');
      }

      //only returns true once firestore has actually saved the booking
      return true;
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Booking Failed'),
            content: Text(
              'Your payment succeeded but we could not save your booking.\n\n$e',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      return false;
    }
  }

  //called once the success countdown finishes
  Future<void> _onSuccessComplete(Cafe cafe) async {
    //waits for the firestore booking write before navigating away
    final bookingSaved = await _bookingCreationFuture;

    if (!mounted || bookingSaved != true) return;

    ref.read(netsProvider.notifier).cleanup();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (ctx) => MainScreen(initialTab: 1),
      ),
      (route) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking confirmed at ${cafe.name}!')),
    );
  }

  //once the fail countdown finishes, resets so the user can retry
  //without losing their date/time/pax selections
  void _onFailComplete() {
    if (!mounted) return;

    ref.read(netsProvider.notifier).reset();
    setState(() {
      _paymentStarted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    //gets the CafeHop colours currently selected by the user
    final selectedTheme = ref.watch(themeProvider);

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final cafe = args['cafe'] as Cafe;
    final DateTime date = args['date'] as DateTime;
    final String time = args['time'] as String;
    final int pax = args['pax'] as int;

    //listens for payment success and triggers the booking write
    //exactly once per payment attempt
    ref.listen<dynamic>(netsProvider, (previous, next) {
      if (next.status == 'success' && !_bookingCreated) {
        _bookingCreated = true;
        _bookingCreationFuture = _createBookingAfterPayment();
      }
    });

    //formats the date as dd.mm.yyyy
    //day and month always use 2 digits
    final String formattedDate =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Scaffold(
      backgroundColor: creamBackground,

      appBar: CafeHopAppBar(showBackButton: true),

      //Pay button only shows before payment starts, the NETS widget
      //has its own cancel button once its showing
      bottomNavigationBar: _paymentStarted
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: creamBackground,
                border: Border(
                  top: BorderSide(color: Colors.black12, width: 1),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderBlack, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(3.2, 3.2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isNetsSelected
                      ? () {
                          _startPayment(cafe, date, time, pax);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedTheme.dark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.black26,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'PAY WITH NETS QR →',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.28,
                    ),
                  ),
                ),
              ),
            ),

      body: _paymentStarted
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: NETSWidget(
                amount: cafe.depositAmount,
                onSuccessComplete: () => _onSuccessComplete(cafe),
                onFailComplete: _onFailComplete,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  //booking summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderBlack, width: 1.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BOOKING SUMMARY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tabInactiveText,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$formattedDate | $time',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: borderBlack,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 16,
                              color: secondaryText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$pax Pax',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  DottedBorder(
                    color: selectedTheme.dark,
                    strokeWidth: 2,
                    dashPattern: [8, 4],
                    borderType: BorderType.RRect,
                    radius: Radius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: selectedTheme.tag,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REQUIRED DEPOSIT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selectedTheme.dark,
                                ),
                              ),
                              Text(
                                '\$${cafe.depositAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: selectedTheme.dark,
                                ),
                              ),
                            ],
                          ),

                          //slightly rotates the deposit icon card
                          Transform.rotate(
                            angle: 0.05,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: borderBlack,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black,
                                    blurRadius: 0,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.emoji_nature_outlined,
                                size: 50,
                                color: Colors.black26,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  //deposit info text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: selectedTheme.dark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The deposit is held to secure your spot and will be returned to your original payment method within one business day after your visit.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: tabInactiveText,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  //payment method section
                  Text(
                    'Payment Method',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: borderBlack,
                    ),
                  ),

                  const SizedBox(height: 12),

                  //NETS QR has to be selected before the Pay button enables
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _isNetsSelected = !_isNetsSelected;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderBlack, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 0,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card_outlined,
                                color: borderBlack,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'NETS QR Payment',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          //filled circle shows that NETS is currently selected
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isNetsSelected
                                  ? selectedTheme.primary
                                  : Colors.white,
                              border: Border.all(
                                color: borderBlack,
                                width: 2,
                              ),
                            ),
                            child: _isNetsSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}