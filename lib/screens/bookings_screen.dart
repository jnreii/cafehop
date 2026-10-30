import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cafehop/models/bookings.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/screens/booking_detail_screen.dart';
import 'package:cafehop/screens/review_form_screen.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';
import 'package:cafehop/screens/booking_form_screen.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  final String? initialVisitBookingId;

  BookingsScreen({
    this.initialVisitBookingId,
  });

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  //0 = Upcoming tab, 1 = Past tab
  int selectedTab = 0;

  //ids of bookings the user has dismissed the auto-popup for this session
  //tracked per booking so declining one doesnt block the prompt for another
  final Set<String> dismissedPromptIds = {};

  //stops 2 auto-popups from stacking on top of each other
  bool _isPromptShowing = false;
  @override
  void initState() {
    super.initState();

    //visit notifications open straight to the Past tab
    if (widget.initialVisitBookingId != null) {
      selectedTab = 1;
    }
  }

  //formats the booking date and time for the cards
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(dt.year, dt.month, dt.day);

    if (bookingDay == today) {
      return 'Today, ${_formatTime(dt)}';
    }

    return '${DateFormat('EEE, d MMM').format(dt)} • ${_formatTime(dt)}';
  }

  String _formatTime(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  //wait 2 hours after the booking time so we dont ask for visit confirmation
  //while the user might still be at the cafe
  bool _visitHasEnded(Booking booking) {
    return DateTime.now().isAfter(
      booking.dateTime.add(const Duration(hours: 2)),
    );
  }

  //status badge shown on bookings in the Past tab
  Widget _buildPastStatusBadge(Booking booking) {
    String label = booking.status.toUpperCase();
    Color backgroundColor = const Color(0xFFF0FDF4);
    Color textColor = const Color(0xFF16A34A);

    if (booking.status == 'upcoming' && _visitHasEnded(booking)) {
      label = 'CONFIRM VISIT';
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFB45309);
    } else if (booking.status == 'cancelled') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
    } else if (booking.status == 'missed') {
      backgroundColor = const Color(0xFFFFF7ED);
      textColor = const Color(0xFFEA580C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  //shows after a booking has passed so the user can confirm what happened
  //2 real choices only, choosing "I visited" goes straight into the
  //review form which has its own skip link inside it
  Future<void> _showVisitPrompt(Booking booking) async {
    //uses the selected theme for the main action in this popup
    final selectedTheme = ref.read(themeProvider);

    _isPromptShowing = true;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderBlack, width: 1.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How did your visit go?',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: borderBlack,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${booking.cafeName}\n${_formatDateTime(booking.dateTime)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: secondaryText,
                  ),
                ),

                const SizedBox(height: 20),

                //I visited goes straight into the review form
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();

                      booking.status = 'completed';

                      try {
                        final firebaseService = ref.read(firebaseServiceProvider);

                        await firebaseService.updateBooking(booking);

                        //recalculates the user's ranked cafe preferences now that
                        //this booking counts as a completed visit
                        try {
                          await firebaseService.refreshPreferredCategories(
                            booking.userId,
                          );
                        } catch (e) {
                          print('Could not refresh preferred categories: $e');
                        }

                        if (mounted) {
                          await Navigator.of(context).pushNamed(
                            ReviewFormScreen.routeName,
                            arguments: booking,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not update booking. $e'),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedTheme.dark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'I visited',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                //marks the booking as missed
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();

                      booking.status = 'missed';

                      try {
                        await ref
                            .read(firebaseServiceProvider)
                            .updateBooking(booking);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Booking marked as missed.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not update booking. $e'),
                            ),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderBlack, width: 1.8),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: Text(
                      "I didn't make it",
                      style: GoogleFonts.plusJakartaSans(
                        color: borderBlack,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                //Maybe later dismisses only this booking so it
                //wont auto-popup again this session, but the card can still
                //be tapped to reopen this same dialog manually
                Center(
                  child: TextButton(
                    onPressed: () {
                      dismissedPromptIds.add(booking.id);
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(
                      'Maybe later',
                      style: GoogleFonts.plusJakartaSans(
                        color: secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    _isPromptShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    //gets the CafeHop colours currently selected by the user
    final selectedTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: CafeHopAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            //Upcoming and Past toggle tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F3F2),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: Colors.black26, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9999),
                      onTap: () {
                        setState(() {
                          selectedTab = 0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedTab == 0
                              ? selectedTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Center(
                          child: Text(
                            'Upcoming',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selectedTab == 0
                                  ? Colors.white
                                  : Color(0xFF434841),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9999),
                      onTap: () {
                        setState(() {
                          selectedTab = 1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedTab == 1
                              ? selectedTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Center(
                          child: Text(
                            'Past',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selectedTab == 1
                                  ? Colors.white
                                  : Color(0xFF434841),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            //shows either Upcoming or Past depending on the selected tab
            if (selectedTab == 0) ...[
              _buildUpcomingTab(selectedTheme),
            ] else ...[
              _buildPastTab(),
            ],
          ],
        ),
      ),
    );
  }

  //small spinner while firestore is still loading
  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  //shown if the firestore query fails
  Widget _buildError(Object err) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Text(
          'Could not load bookings.\n$err',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: Colors.black54),
        ),
      ),
    );
  }

  //builds the Upcoming tab, big Next Up card and Upcoming Week list
  Widget _buildUpcomingTab(CafeTheme selectedTheme) {
    //firestore SELECT uses 2 filters on different fields + sort order, live updating
    final upcomingAsync = ref.watch(upcomingBookingsProvider);

    return upcomingAsync.when(
      loading: () => _buildLoading(),
      error: (err, stack) => _buildError(err),
      data: (upcomingBookings) {
        final activeUpcomingBookings = upcomingBookings
            .where((booking) => !_visitHasEnded(booking))
            .toList();

        if (activeUpcomingBookings.isEmpty) {
          return Center(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.calendar_today_outlined,
                    size: 60, color: Colors.black26),
                const SizedBox(height: 16),
                Text(
                  'No upcoming bookings',
                  style: GoogleFonts.bricolageGrotesque(
                      fontSize: 16, color: Colors.black38),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next Up',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: borderBlack,
              ),
            ),
            const SizedBox(height: 12),

            //big Next Up card, opens booking details when tapped
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).pushNamed(
                  BookingDetailScreen.routeName,
                  arguments: activeUpcomingBookings[0],
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderBlack, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(3.6, 3.6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7.2),
                      //uses the bundled cafe image asset
                      child: Image.asset(
                        activeUpcomingBookings[0].cafeImageUrl,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      activeUpcomingBookings[0].cafeName,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: borderBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(activeUpcomingBookings[0].dateTime),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: secondaryText),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.people_outline,
                            size: 14, color: secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          '${activeUpcomingBookings[0].pax} pax',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    //Modify opens the booking form pre-filled for editing
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          BookingFormScreen.routeName,
                          arguments: activeUpcomingBookings[0],
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: selectedTheme.primary, width: 1.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                      ),
                      child: Text(
                        'Modify',
                        style: GoogleFonts.plusJakartaSans(
                          color: selectedTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (activeUpcomingBookings.length > 1) ...[
              const SizedBox(height: 24),
              Text(
                'Upcoming Week',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: borderBlack,
                ),
              ),
              const SizedBox(height: 12),
              //shrinkWrap + NeverScrollableScrollPhysics are needed because this ListView
              //sits inside the outer SingleChildScrollView
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: activeUpcomingBookings.length - 1,
                itemBuilder: (ctx, i) {
                  final booking = activeUpcomingBookings[i + 1];
                  return _buildUpcomingWeekCard(booking);
                },
              ),
            ],
          ],
        );
      },
    );
  }

  //builds the Past tab, list of past bookings
  Widget _buildPastTab() {
    //firestore SELECT uses whereIn for multiple values on the same field
    final pastAsync = ref.watch(pastBookingsProvider);
    final allAsync = ref.watch(allBookingsProvider);

    return pastAsync.when(
      loading: () => _buildLoading(),
      error: (err, stack) => _buildError(err),
      data: (pastBookings) {
        return allAsync.when(
          loading: () => _buildLoading(),
          error: (err, stack) => _buildError(err),
          data: (allBookings) {
            //upcoming bookings only move here after their 2 hour visit window
            final awaitingConfirmation = allBookings
                .where((booking) =>
                    booking.status == 'upcoming' &&
                    _visitHasEnded(booking))
                .toList();

            final displayBookings = [
              ...pastBookings,
              ...awaitingConfirmation,
            ];

            //auto shows the popup for the first awaiting-confirmation
            //booking that hasnt been dismissed yet, one at a time so
            //dialogs never stack
            final nextToPrompt = awaitingConfirmation
                .where((b) => !dismissedPromptIds.contains(b.id))
                .toList();

            //if this screen was opened from a visit notification,
            //prioritise that exact booking instead of whichever comes first
            Booking? requestedBooking;

            if (widget.initialVisitBookingId != null) {
              for (final booking in nextToPrompt) {
                if (booking.id == widget.initialVisitBookingId) {
                  requestedBooking = booking;
                  break;
                }
              }
            }

            final promptBooking = requestedBooking ??
                (nextToPrompt.isNotEmpty ? nextToPrompt[0] : null);

            if (promptBooking != null && !_isPromptShowing) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isPromptShowing) {
                  _showVisitPrompt(promptBooking);
                }
              });
            }

            //most recent first
            displayBookings.sort(
              (a, b) => b.dateTime.compareTo(a.dateTime),
            );

            if (displayBookings.isEmpty) {
              return Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.history, size: 60, color: Colors.black26),
                    const SizedBox(height: 16),
                    Text(
                      'No past bookings',
                      style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16, color: Colors.black38),
                    ),
                  ],
                ),
              );
            }

            //same shrinkWrap + NeverScrollableScrollPhysics reason as the
            //Upcoming Week list since this is also inside the outer
            //SingleChildScrollView
            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: displayBookings.length,
              itemBuilder: (ctx, i) {
                return _buildUpcomingWeekCard(displayBookings[i]);
              },
            );
          },
        );
      },
    );
  }

  //small tappable chip prompting completed-but-unreviewed bookings
  Widget _buildReviewPrompt(Booking booking) {
    return StreamBuilder<bool>(
      stream: ref.read(firebaseServiceProvider).hasReviewStream(booking.id),
      builder: (context, snapshot) {
        final hasReview = snapshot.data ?? false;

        //already reviewed, nothing to prompt
        if (hasReview) return const SizedBox.shrink();

        return InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: () {
            Navigator.of(context).pushNamed(
              ReviewFormScreen.routeName,
              arguments: booking,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: Colors.amber[700]!, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_outline, size: 13, color: Colors.amber[800]),
                const SizedBox(width: 4),
                Text(
                  'Rate your visit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //builds a compact version of the booking row card
  Widget _buildUpcomingWeekCard(Booking booking) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (selectedTab == 1 &&
            booking.status == 'upcoming' &&
            _visitHasEnded(booking)) {
          _showVisitPrompt(booking);
        } else {
          Navigator.of(context).pushNamed(
            BookingDetailScreen.routeName,
            arguments: booking,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderBlack, width: 1.8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3.4),
              child: Image.asset(
                booking.cafeImageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        booking.cafeName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: borderBlack,
                        ),
                      ),
                      Text(
                        '${booking.pax} pax',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tabInactiveText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDateTime(booking.dateTime),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: secondaryText),
                  ),
                  if (selectedTab == 1) ...[
                    const SizedBox(height: 8),
                    _buildPastStatusBadge(booking),
                  ],
                  if (selectedTab == 1 && booking.status == 'completed') ...[
                    const SizedBox(height: 8),
                    _buildReviewPrompt(booking),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            //cancelled bookings can be removed from history completely
            if (selectedTab == 1 && booking.status == 'cancelled') ...[
              InkWell(
                customBorder: CircleBorder(),
                onTap: () {
                  _confirmDelete(booking);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline,
                      size: 20, color: Colors.red[700]),
                ),
              ),
            ] else ...[
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
            ],
          ],
        ),
      ),
    );
  }

  //delete removes the booking document completely
  //only offered on cancelled bookings, deleting a completed one would leave
  //its review orphaned since reviews are keyed on bookingId
  Future<void> _confirmDelete(Booking booking) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Booking?'),
          content: Text(
            'This will permanently remove your cancelled booking at '
            '${booking.cafeName} from your history. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  await ref
                      .read(firebaseServiceProvider)
                      .deleteBooking(booking.id);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking removed.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not remove booking. $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}