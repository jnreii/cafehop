import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cafehop/models/bookings.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/screens/booking_form_screen.dart';
import 'package:cafehop/screens/review_form_screen.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/widgets/cafe_map.dart';
import 'package:cafehop/services/notification_service.dart';

//full detail view of a single booking, opened by tapping a booking card
class BookingDetailScreen extends ConsumerWidget {
  static String routeName = '/booking-detail';

  String _formatDateTime(DateTime dt) {
    return '${DateFormat('EEE, d MMM').format(dt)} • ${DateFormat('h:mm a').format(dt)}';
  }

  //wait 2 hours after the booking time so we dont ask while the visit
  //might still be happening
  bool _visitHasEnded(Booking booking) {
    return DateTime.now().isAfter(
      booking.dateTime.add(const Duration(hours: 2)),
    );
  }

  //cancel booking, flips status instead of deleting the doc so the
  //booking still shows up in Past
  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Booking?'),
          content: const Text(
              'Cancellations made more than 24 hours before your slot are '
              'eligible for a full deposit refund. Cancellations within 24 '
              'hours will forfeit the deposit.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep Booking'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                booking.status = 'cancelled';
                try {
                  await ref
                      .read(firebaseServiceProvider)
                      .updateBooking(booking);

                  //no reminder needed once this booking is cancelled
                  try {
                    await NotificationService.cancelBookingNotifications(booking);
                  } catch (e) {
                    print('Could not cancel booking reminder: $e');
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Booking cancelled. Deposit will be refunded if eligible.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Could not cancel booking. $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Booking'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //gets the colours from the theme the user picked
    final selectedTheme = ref.watch(themeProvider);

    //only the id is used from the route args, the rest streams live
    final args =
        ModalRoute.of(context)!.settings.arguments as Booking;

    //live cafe list, used to look up real coordinates for the map since
    //Booking only stores the cafe's address text, not lat/lng
    final cafesAsync = ref.watch(cafesProvider);

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: CafeHopAppBar(showBackButton: true),
      body: StreamBuilder<Booking>(
        //single booking doc stream by id
        stream: ref.read(firebaseServiceProvider).getBooking(args.id).cast<Booking>(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load booking.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: Colors.black54),
              ),
            );
          }

          final booking = snapshot.data!;
          //find the live cafe matching this booking, may be null briefly
          //while cafes are still loading, or if the cafe was ever deleted
          Cafe? matchedCafe;
          final cafesList = cafesAsync.value;
          if (cafesList != null) {
            for (final c in cafesList) {
              if (c.id == booking.cafeId) {
                matchedCafe = c;
                break;
              }
            }
          }
          final bool needsVisitConfirmation =
              booking.status == 'upcoming' &&
                  _visitHasEnded(booking);
          final bool isUpcoming =
              booking.status == 'upcoming' &&
                  !needsVisitConfirmation;

          Color statusBackground =
              const Color(0xFFF0FDF4);
          Color statusTextColor =
              const Color(0xFF16A34A);

          if (needsVisitConfirmation) {
            statusBackground = const Color(0xFFFEF3C7);
            statusTextColor = const Color(0xFFB45309);
          } else if (booking.status == 'upcoming') {
            statusBackground = selectedTheme.tag;
            statusTextColor = selectedTheme.dark;
          } else if (booking.status == 'cancelled') {
            statusBackground = const Color(0xFFFEE2E2);
            statusTextColor = const Color(0xFFDC2626);
          } else if (booking.status == 'missed') {
            statusBackground = const Color(0xFFFFF7ED);
            statusTextColor = const Color(0xFFEA580C);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                //cafe image
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(12),
                  child: Image.asset(
                    booking.cafeImageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 16),

                //cafe name and status badge
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.cafeName,
                        style:
                            GoogleFonts.bricolageGrotesque(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: borderBlack,
                        ),
                      ),
                    ),

                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius:
                            BorderRadius.circular(9999),
                        border: Border.all(
                            color: borderBlack,
                            width: 1.5),
                      ),
                      child: Text(
                        needsVisitConfirmation
                            ? 'CONFIRM VISIT'
                            : booking.status
                                .toUpperCase(),
                        style:
                            GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                //booking details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                        color: borderBlack,
                        width: 1.8),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BOOKING DETAILS',
                        style:
                            GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: tabInactiveText,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                              Icons
                                  .calendar_today_outlined,
                              size: 16,
                              color: secondaryText),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(
                                booking.dateTime),
                            style: GoogleFonts
                                .plusJakartaSans(
                                    fontSize: 15,
                                    color:
                                        borderBlack),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.people_outline,
                              size: 16,
                              color: secondaryText),
                          const SizedBox(width: 8),
                          Text(
                            '${booking.pax} pax',
                            style: GoogleFonts
                                .plusJakartaSans(
                                    fontSize: 15,
                                    color:
                                        borderBlack),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: secondaryText),
                          const SizedBox(width: 8),
                          Text(
                            'Deposit paid: \$${booking.depositAmount.toStringAsFixed(2)}',
                            style: GoogleFonts
                                .plusJakartaSans(
                                    fontSize: 15,
                                    color:
                                        borderBlack),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                //location section
                Text(
                  'Location',
                  style:
                      GoogleFonts.bricolageGrotesque(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: borderBlack,
                  ),
                ),

                const SizedBox(height: 8),

                //address and MRT info with black outline
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                        color: borderBlack,
                        width: 1.8),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.cafeAddress,
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      //real map, falls back to a simple text row if the
                      //cafe hasnt loaded yet or was removed from the catalogue
                      if (matchedCafe != null)
                        CafeMap(cafe: matchedCafe)
                      else
                        Text(
                          'Map unavailable',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                //action buttons for upcoming bookings
                if (isUpcoming) ...[
                  //Edit Booking opens the booking form with the current details
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed(
                          BookingFormScreen.routeName,
                          arguments: booking,
                        );
                      },
                      style:
                          OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: selectedTheme.primary,
                            width: 1.8),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 14),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  9999),
                        ),
                      ),
                      child: Text(
                        'Edit Booking',
                        style: GoogleFonts
                            .plusJakartaSans(
                          color: selectedTheme.primary,
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  //cancel booking
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        _confirmCancel(
                            context, ref, booking);
                      },
                      style:
                          OutlinedButton.styleFrom(
                        side: BorderSide(
                            color:
                                Colors.red[700]!,
                            width: 1.8),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 14),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  9999),
                        ),
                      ),
                      child: Text(
                        'Cancel Booking',
                        style: GoogleFonts
                            .plusJakartaSans(
                          color: Colors.red[700],
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],

                //only completed visits are allowed to leave a review
                if (booking.status == 'completed') ...[
                  StreamBuilder<bool>(
                    stream: ref
                        .read(firebaseServiceProvider)
                        .hasReviewStream(booking.id),
                    builder:
                        (context, reviewSnapshot) {
                      final hasReview =
                          reviewSnapshot.data ?? false;

                      if (hasReview) {
                        return Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(
                                0xFFF0FDF4),
                            borderRadius:
                                BorderRadius.circular(
                                    12),
                            border: Border.all(
                              color:
                                  const Color(
                                      0xFF16A34A),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Review submitted',
                            textAlign:
                                TextAlign.center,
                            style: GoogleFonts
                                .plusJakartaSans(
                              color: const Color(
                                  0xFF16A34A),
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pushNamed(
                              ReviewFormScreen
                                  .routeName,
                              arguments: booking,
                            );
                          },
                          style: ElevatedButton
                              .styleFrom(
                            backgroundColor:
                                selectedTheme.dark,
                            foregroundColor:
                                Colors.white,
                            padding: const EdgeInsets
                                .symmetric(
                                vertical: 14),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                          9999),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Leave a Review',
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}