import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/screens/cafe_profile_screen.dart';
import 'package:cafehop/screens/booking_form_screen.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';

class SavedScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  String selectedCategory = 'All';
  String selectedSort = 'Default';

  //filters the user's saved cafes by category
  List<Cafe> _filterSavedCafes(List<Cafe> cafes) {
    if (selectedCategory == 'All') {
      return List<Cafe>.from(cafes);
    }

    return cafes
        .where((cafe) => cafe.category == selectedCategory)
        .toList();
  }

  //sorts only the saved cafes already loaded from firestore
  List<Cafe> _sortSavedCafes(List<Cafe> cafes) {
    final sortedCafes = List<Cafe>.from(cafes);

    if (selectedSort == 'A-Z') {
      sortedCafes.sort(
        (a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      );
    } else if (selectedSort == 'Highest Rated') {
      sortedCafes.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (selectedSort == 'Nearest') {
      sortedCafes.sort(
        (a, b) => _distanceValue(a.distance).compareTo(
          _distanceValue(b.distance),
        ),
      );
    }

    return sortedCafes;
  }

  //turns a distance like 0.8km into a number so it can be sorted
  double _distanceValue(String distance) {
    return double.tryParse(
          distance.toLowerCase().replaceAll('km', '').trim(),
        ) ??
        double.infinity;
  }

  //removes a cafe from the user's saved list
  Future<void> _unsaveCafe(
    BuildContext context,
    WidgetRef ref,
    Cafe cafe,
  ) async {
    final firebaseService = ref.read(firebaseServiceProvider);
    final user = firebaseService.getCurrentUser();

    if (user == null) return;

    try {
      await firebaseService.toggleSavedCafe(
        user.uid,
        cafe.id,
        true,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update saved cafes. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //gets the CafeHop colours currently selected by the user
    final selectedTheme = ref.watch(themeProvider);

    final savedIds = ref.watch(savedCafeIdsProvider);
    final cafesAsync = ref.watch(cafesProvider);

    return Scaffold(
      backgroundColor: creamBackground,

      //shared CafeHop app bar
      appBar: CafeHopAppBar(),

      body: cafesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        error: (error, stackTrace) => Center(
          child: Text(
            'Could not load saved cafes. Please try again.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: tabInactiveText,
            ),
          ),
        ),

        data: (cafes) {
          //derives the actual Cafe objects from the firestore cafe list
          //using the saved ids stored in the user's firestore document
          final List<Cafe> savedCafes =
              cafes.where((cafe) => savedIds.contains(cafe.id)).toList();

          //filter options only use categories that actually exist in Saved
          final categories = <String>[
            'All',
            ...savedCafes.map((cafe) => cafe.category).toSet(),
          ];

          final filteredCafes = _filterSavedCafes(savedCafes);
          final displayedCafes = _sortSavedCafes(filteredCafes);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                //Saved Gems heading
                Text(
                  'Saved Gems',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: borderBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your curated list of neighborhood favorites.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: tabInactiveText,
                  ),
                ),

                const SizedBox(height: 16),

                //filter and sort menus for the cafes already saved by the user
                Row(
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                      itemBuilder: (context) {
                        return categories.map((category) {
                          return PopupMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selectedCategory == 'All'
                              ? Colors.white
                              : selectedTheme.tag,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderBlack, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 0,
                              offset: Offset(1.2, 1.2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_list,
                              size: 12,
                              color: selectedCategory == 'All'
                                  ? borderBlack
                                  : selectedTheme.dark,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              selectedCategory == 'All'
                                  ? 'Filter'
                                  : selectedCategory,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: selectedCategory == 'All'
                                    ? borderBlack
                                    : selectedTheme.dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() {
                          selectedSort = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'Default',
                          child: Text('Default'),
                        ),
                        const PopupMenuItem(
                          value: 'A-Z',
                          child: Text('A-Z'),
                        ),
                        const PopupMenuItem(
                          value: 'Highest Rated',
                          child: Text('Highest Rated'),
                        ),
                        const PopupMenuItem(
                          value: 'Nearest',
                          child: Text('Nearest'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selectedSort == 'Default'
                              ? Colors.white
                              : selectedTheme.tag,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderBlack, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 0,
                              offset: Offset(1.2, 1.2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sort,
                              size: 12,
                              color: selectedSort == 'Default'
                                  ? borderBlack
                                  : selectedTheme.dark,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              selectedSort == 'Default'
                                  ? 'Sort'
                                  : selectedSort,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: selectedSort == 'Default'
                                    ? borderBlack
                                    : selectedTheme.dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                //saved cafe cards
                if (savedCafes.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.favorite_outline,
                          size: 60,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No saved cafes yet',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 16,
                            color: Colors.black38,
                          ),
                        ),
                        Text(
                          'Tap the heart icon on any cafe to save it',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 13,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (displayedCafes.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        'No saved cafes match this filter.',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16,
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: displayedCafes.length,
                    itemBuilder: (ctx, i) {
                      final cafe = displayedCafes[i];
                      return _buildSavedCard(
                        context,
                        ref,
                        cafe,
                        selectedTheme,
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  //saved cafe card
  Widget _buildSavedCard(
    BuildContext context,
    WidgetRef ref,
    Cafe cafe,
    CafeTheme selectedTheme,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          CafeProfileScreen.routeName,
          arguments: cafe,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: borderBlack, width: 1.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //cafe image with saved heart on top
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  child: Image.asset(
                    cafe.imageUrl,
                    height: 173,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                //filled heart removes the cafe from Saved
                Positioned(
                  top: 7,
                  right: 7,
                  child: GestureDetector(
                    onTap: () {
                      _unsaveCafe(context, ref, cafe);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedTheme.dark,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderBlack, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 0,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            //cafe details
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cafe.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                      ),

                      //star rating chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ratingBadgeBackground,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              cafe.rating.toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: borderBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: borderBlack,
                            width: 1.8,
                          ),
                        ),
                        child: Text(
                          cafe.neighbourhood,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  //only cafes with seats can be booked from Saved
                  Row(
                    children: [
                      Expanded(
                        child: cafe.hasSeats
                            ? Container(
                                decoration: BoxDecoration(
                                  color: selectedTheme.dark,
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
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      BookingFormScreen.routeName,
                                      arguments: cafe,
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: Text(
                                    'Book Table',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedTheme.tag,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: borderBlack,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Pickup Only',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: selectedTheme.dark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}