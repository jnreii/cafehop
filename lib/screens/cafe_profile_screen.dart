import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/review.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/services/firebase_service.dart';
import 'package:cafehop/screens/booking_form_screen.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';
import 'package:cafehop/widgets/cafe_map.dart';
import 'package:cafehop/screens/all_reviews_screen.dart';
import 'package:cafehop/widgets/review_card.dart';

class CafeProfileScreen extends ConsumerWidget {
  static String routeName = '/cafe-profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //gets the CafeHop colours currently selected by the user
    final selectedTheme = ref.watch(themeProvider);

    //gets the cafe object passed from the previous screen
    final cafe = ModalRoute.of(context)!.settings.arguments as Cafe;


    return Scaffold(
      backgroundColor: creamBackground,

      //shared CafeHop app bar
      appBar: CafeHopAppBar(
        showBackButton: true,
        actions: [
          Builder(
            builder: (shareContext) {
              return IconButton(
                icon: Icon(Icons.share_outlined, color: creamBackground),
                onPressed: () async {
                  //opens the device share sheet with this cafe's details
                  final box =
                      shareContext.findRenderObject() as RenderBox?;

                  await Share.share(
                    'Check out ${cafe.name} on CafeHop!\n'
                    '${cafe.neighbourhood} • ${cafe.category}\n'
                    '⭐ ${cafe.rating}\n'
                    '${cafe.address}',
                    subject: '${cafe.name} on CafeHop',
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  );
                },
              );
            },
          ),
        ],
      ),

      //only cafes with seats show the booking action
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16), //16px padding on all sides, matches the body content
        decoration: BoxDecoration(
          color: creamBackground,
          border: Border(
            top: BorderSide(color: Colors.black12, width: 1),
          ),
        ),
        child: cafe.hasSeats
            ? Container(
                decoration: primaryButtonDecoration,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      BookingFormScreen.routeName,
                      arguments: cafe,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedTheme.dark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Create a Booking',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: selectedTheme.tag,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderBlack,
                    width: 1.8,
                  ),
                ),
                child: Text(
                  'Pickup Only',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: selectedTheme.dark,
                  ),
                ),
              ),
      ),

      //singlechild scroll view so the whole page can scroll if it doesnt fit on screen
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            //cafe image
            Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderBlack, width: 1.8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        cafe.imageUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  //cafe status badge on the bottom left
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selectedTheme.dark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: borderBlack,
                            blurRadius: 0,
                            offset: Offset(1.6, 1.6),
                          ),
                        ],
                      ),
                      child: Text(
                        cafe.status,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  //cafe name with verified tick
                  Row(
                    children: [
                      Text(
                        cafe.name,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.verified, color: selectedTheme.dark, size: 20),
                    ],
                  ),

                  const SizedBox(height: 8),

                  //rating, price range and distance
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        cafe.rating.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.black38)),
                      const SizedBox(width: 8),
                      Text(
                        cafe.priceRange,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.black38)),
                      const SizedBox(width: 8),
                      Icon(Icons.location_on_outlined,
                          size: 14, color: secondaryText),
                      const SizedBox(width: 2),
                      Text(
                        cafe.distance,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  //description of cafe
                  Text(
                    cafe.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: tabInactiveText,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  //opening hours section
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 18,
                              color: selectedTheme.dark,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hours',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        Divider(color: Colors.black12),
                        const SizedBox(height: 6),

                        if (cafe.weeklySchedule.isNotEmpty) ...[
                          ..._buildOpeningHourRows(cafe),
                        ] else ...[
                          Text(
                            cafe.openingHoursDisplay,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: tabInactiveText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  //menu section
                  Text(
                    'Menu',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Divider(color: Colors.black26),
                  const SizedBox(height: 8),

                  //menu items list
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: cafe.menuItems.length,
                    itemBuilder: (ctx, i) {
                      final item = cafe.menuItems[i];
                      return _buildMenuItem(item, selectedTheme.dark);
                    },
                  ),

                  const SizedBox(height: 16),

                  //location section
                  Text(
                    'Location',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 8),

                  //address and MRT info
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
                          cafe.address,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.directions_walk,
                                size: 16, color: selectedTheme.dark),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cafe.nearestMrt,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: selectedTheme.dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        //real map showing this cafe's location
                        CafeMap(cafe: cafe),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  //reviews section
                  Text(
                    'Reviews',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Divider(color: Colors.black26),
                  const SizedBox(height: 8),

                  StreamBuilder<List<Review>>(
                    stream: FirebaseService().getReviews(cafe.id),
                    builder: (context, snapshot) {
                      final reviews = snapshot.data ?? [];

                      if (reviews.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No reviews yet.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: Colors.black38,
                            ),
                          ),
                        );
                      }

                      //only shows the first 3 here, the rest are behind
                      //the See all reviews link
                      final topReviews = reviews.take(3).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final review in topReviews)
                            buildReviewCard(review),

                          if (reviews.length > 3) ...[
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushNamed(
                                    AllReviewsScreen.routeName,
                                    arguments: cafe,
                                  );
                                },
                                child: Text(
                                  'See all ${reviews.length} reviews',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: selectedTheme.dark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
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

  //matches each menu item to a local asset image
  String _getMenuImage(String itemName) {
    const menuImages = <String, String>{

      //Mizu Matcha Bar
      'Ceremonial Matcha Brew': 'images/ceremonial_matcha.jpg',
      'Basic Matcha Latte': 'images/matcha_latte.jpg',
      'Salt Cream Top Matcha': 'images/matcha_creamtop.jpg',

      //Crust & Crumble
      'Signature Sourdough': 'images/sourdough.jpg',
      'Butter Croissant': 'images/croissant.jpg',
      'Salted Shiopan': 'images/shiopan.jpg',

      //The Flour House
      'Garlic Tomato Foccacia': 'images/foccaccia.jpg',
      'Plain Foccacia': 'images/plain_foccaccia.jpg',
      'Milo Matchasaur': 'images/milo_matcha.jpg',

      //Poh's Matcha Cafe
      'Strawberry Matcha': 'images/strawb_matcha.jpg',
      'Earl Grey Matcha': 'images/earl_grey_matcha.jpg',
      'Hojicha Latte': 'images/hojicha.jpg',

      //Grounded Coffee Co.
      'Signature Cold Brew': 'images/cold_brew.jpg',
      'Flat White': 'images/flat_white.jpg',
      'Banana Bread': 'images/banana_bread.jpg',

      //Sunday Room Coffee
      'Brown Sugar Oat Latte': 'images/oat_latte.jpg',
      'Orange Espresso Tonic': 'images/orange_espresso.jpg',
      'Tiramisu French Toast': 'images/tiramisu_french_toast.jpg',

      //Kumo Hojicha House
      'Hojicha Cloud Latte': 'images/hojicha.jpg',
      'Matcha Hojicha Duo': 'images/matcha_hojicha.jpg',
      'Black Sesame Mochi Cake': 'images/black_sesame_cake.jpg',

      //After Five Brew Club
      'Sea Salt Latte': 'images/flat_white.jpg',
      'Yuzu Cold Brew': 'images/yuzu_brew.jpg',
      'Kaya Butter Brioche': 'images/croissant.jpg',

      //Whisk & Window
      'Miso Caramel Cookie': 'images/miso_cookies.jpg',
      'Brown Butter Financier': 'images/financiers.jpg',
      'Lemon Glaze Loaf': 'images/banana_bread.jpg',

      //Paw & Pour Home Cafe
      'Honey Oat Latte': 'images/oat_latte.jpg',
      'Peanut Butter Pet Biscuit': 'images/pet_biscuit.jpg',
    };

    return menuImages[itemName] ?? 'images/cold_brew.jpg';
  }

  //builds a single menu item card
  Widget _buildMenuItem(MenuItem item, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderBlack, width: 1.8),
      ),
      child: Row(
        children: [
          //menu item photo
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              _getMenuImage(item.name),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.restaurant,
                    color: Colors.black26,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${item.price.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //turns a weekday number into the short day name
String _getDayName(int day) {
  const days = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  return days[day];
}


//turns stored 24hr time like 18:30 into 6:30 PM
String _formatOpeningTime(String time) {
  final parts = time.split(':');

  final hour = int.parse(parts[0]);
  final minute = parts[1];

  final displayHour = hour == 0
      ? 12
      : hour > 12
          ? hour - 12
          : hour;

  final period = hour >= 12 ? 'PM' : 'AM';

  return '$displayHour:$minute $period';
}


//builds one opening-hours row for each day the cafe is open
List<Widget> _buildOpeningHourRows(Cafe cafe) {
  final scheduleEntries = cafe.weeklySchedule.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  return scheduleEntries.map((entry) {
    final day = entry.key;
    final schedule = entry.value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              _getDayName(day),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: borderBlack,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              '${_formatOpeningTime(schedule.openTime)} – '
              '${_formatOpeningTime(schedule.closeTime)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: tabInactiveText,
              ),
            ),
          ),
        ],
      ),
    );
  }).toList();
}
}

//swipeable photo viewer when a review has more than 1 photo
//uses the first photo shape but keeps the height between a min and
//max so a weird photo size doesnt make the card too tall or short
class _ReviewPhotoCarousel extends StatefulWidget {
  final List<String> photosBase64;

  const _ReviewPhotoCarousel({required this.photosBase64});

  @override
  State<_ReviewPhotoCarousel> createState() => _ReviewPhotoCarouselState();
}

class _ReviewPhotoCarouselState extends State<_ReviewPhotoCarousel> {
  int _currentPage = 0;

  //gets the aspect ratio from the first photo
  double? _aspectRatio;

  static const double _minHeight = 140;
  static const double _maxHeight = 260;

  @override
  void initState() {
    super.initState();
    _loadFirstImageSize();
  }

  //decodes only the first photo to get its width/height, so we know what
  //shape to give the whole PageView before it renders
  void _loadFirstImageSize() {
    final bytes = base64Decode(widget.photosBase64[0]);
    final image = MemoryImage(bytes);

    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() {
            _aspectRatio = info.image.width / info.image.height;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        //uses a normal landscape shape while the real size is loading
        final ratio = _aspectRatio ?? (4 / 3);

        //works out the photo height then clamps it so a
        //very tall or wide photo doesnt blow out the card
        final idealHeight = constraints.maxWidth / ratio;
        final height = idealHeight.clamp(_minHeight, _maxHeight);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: PageView.builder(
                  itemCount: widget.photosBase64.length,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemBuilder: (ctx, i) {
                    return Image.memory(
                      base64Decode(widget.photosBase64[i]),
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),

            //dot indicator, only shown when theres more than 1 photo
            if (widget.photosBase64.length > 1) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.photosBase64.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: i == _currentPage ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}