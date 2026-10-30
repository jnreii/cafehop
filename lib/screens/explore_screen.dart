import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/recommendation.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/screens/cafe_profile_screen.dart';
import 'package:cafehop/screens/view_all_screen.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/applied_ai_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';
import 'package:cafehop/services/notification_service.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  //currently selected category filter
  String selectedCategory = 'All';
  //stops the same firestore update being checked twice at once
  bool _checkingRecommendationNotifications = false;

  //search bar controller and the current search text
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  //list of category filter options
  final List<String> categories = [
    'All',
    'Matcha',
    'Bakeries',
    'Coffee',
    'Pet Friendly',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //returns filtered cafe list based on selected category and search text
  List<Cafe> _getFilteredCafes(List<Cafe> cafes) {
    var filtered = cafes;

    if (selectedCategory != 'All') {
      filtered = filtered
          .where((cafe) => cafe.category == selectedCategory)
          .toList();
    }

    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((cafe) =>
              cafe.name.toLowerCase().contains(query) ||
              cafe.neighbourhood.toLowerCase().contains(query) ||
              cafe.category.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  //toggles saved state of a cafe and shows a snackbar when saved
  Future<void> _toggleSaved(Cafe cafe) async {
    final savedIds = ref.read(savedCafeIdsProvider);
    final wasSaved = savedIds.contains(cafe.id);

    final firebaseService = ref.read(firebaseServiceProvider);
    final user = firebaseService.getCurrentUser();

    if (user == null) return;

    try {
      await firebaseService.toggleSavedCafe(
        user.uid,
        cafe.id,
        wasSaved,
      );

      if (!wasSaved && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cafe.name} saved!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update saved cafes. Please try again.'),
          ),
        );
      }
    }
  }

  //checks if a newly added cafe was also picked by the AI recommender
  Future<void> _checkNewCafeNotifications(
    List<Cafe> cafes,
    List<Recommendation> recommendations,
  ) async {
    if (_checkingRecommendationNotifications) return;

    final userDoc = ref.read(userDocProvider).value;
    final user =
        ref.read(firebaseServiceProvider).getCurrentUser();

    if (user == null || userDoc == null) return;

    _checkingRecommendationNotifications = true;

    try {
      await NotificationService.checkForNewRecommendationMatches(
        userId: user.uid,
        cafes: cafes,
        recommendedCafeIds: recommendations
            .map((recommendation) => recommendation.cafe.id)
            .toSet(),

        //dont count the cold-start rating fallback as an AI preference match
        hasPreferences:
            userDoc.preferredCategories.isNotEmpty,
      );
    } catch (e) {
      print('Could not check recommendation notifications: $e');
    } finally {
      _checkingRecommendationNotifications = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = ref.watch(savedCafeIdsProvider);

    //gets the colours from the theme the user picked
    final selectedTheme = ref.watch(themeProvider);

    //reads every cafe live from firestore
    final cafesAsync = ref.watch(cafesProvider);

    //AI recommendations built from the user's real firestore activity
    final recommendationsAsync = ref.watch(recommendationsProvider);
    //watch the user doc too so preferredCategories changes update this screen
    ref.watch(userDocProvider);

    return Scaffold(
      backgroundColor: creamBackground,
      //reusable app bar with the CafeHop logo
      appBar: CafeHopAppBar(),

      body: cafesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load cafes. Please try again.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        data: (cafes) {
          final filteredCafes = _getFilteredCafes(cafes);
          //only check after the latest AI recommendations have finished loading
          final recommendations = recommendationsAsync.value;

          if (recommendations != null &&
              !recommendationsAsync.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _checkNewCafeNotifications(
                  cafes,
                  recommendations,
                );
              }
            });
          }

          //ListView lets the whole Explore page scroll together
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [

              //search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: borderBlack, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: borderBlack,
                      blurRadius: 0,
                      offset: Offset(3.6, 3.6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Find your next hidden gem...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: Colors.black38,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: tabInactiveText,
                    ),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.close,
                              color: tabInactiveText,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              //category filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) { //converts each to widget
                    bool isSelected = selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? selectedTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? selectedTheme.primary : borderBlack,
                              width: 1.8,
                            ),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              //Just For You section header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Just For You',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.auto_awesome,
                        size: 17,
                        color: selectedTheme.primary,
                      ),
                    ],
                  ),
                  //opens the full recommendation list
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed(ViewAllScreen.routeName);
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        color: selectedTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                'Picked based on your CafeHop activity',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: secondaryText,
                ),
              ),

              const SizedBox(height: 12),

              //AI-powered Just For You recommendations
              recommendationsAsync.when(
                loading: () => SizedBox(
                  height: 220,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: selectedTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Finding cafes for you...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                error: (error, stackTrace) => SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'Could not load recommendations.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ),
                ),

                data: (recommendations) {
                  if (recommendations.isEmpty) {
                    return SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'No recommendations available yet.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: secondaryText,
                          ),
                        ),
                      ),
                    );
                  }

                  //horizontal scrollable AI recommendation cards
                  return SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: AlwaysScrollableScrollPhysics(),
                      itemCount: recommendations.length,
                      itemBuilder: (ctx, i) {
                        final recommendation = recommendations[i];
                        return _buildJustForYouCard(recommendation, selectedTheme);
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              //Discover Nearby heading
              Text(
                'Discover Nearby',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              if (filteredCafes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No cafes match your search.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ),
                ),

              ...filteredCafes.map((cafe) { //"..." is the spread operator, takes each item in the list and adds it to the parent list
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDiscoverCard(cafe, savedIds, selectedTheme),
                );
              }).toList(),

              //bottom padding
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  //builds a horizontal Just For You cafe card, tap to open the cafe profile
  Widget _buildJustForYouCard(
    Recommendation recommendation,
    CafeTheme selectedTheme,
  ) {
    final cafe = recommendation.cafe;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pushNamed(
          CafeProfileScreen.routeName,
          arguments: cafe,
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderBlack, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: borderBlack,
              blurRadius: 0,
              offset: Offset(3.6, 3.6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack( //stack lets you layer widgets on top of each other
              children: [
                ClipRRect(
                  //ClipRRect = clips its child into rounded corners
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.asset(
                    cafe.imageUrl,
                    height: 120,
                    width: double.infinity, //double.infinity = takes up all available width
                    fit: BoxFit.cover, //BoxFit.cover = scales and crops the image to fill the spaces
                  ),
                ),

                //AI recommendation reason, floats on top of the image
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selectedTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        recommendation.reason,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            //cafe name and location
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, //aligns the text to the left
                children: [
                  Text(
                    cafe.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, //cuts off with "..." if name too long
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: secondaryText,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${cafe.neighbourhood} • ${cafe.distance}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  //builds a vertical Discover Nearby cafe card
  Widget _buildDiscoverCard(
    Cafe cafe,
    Set<String> savedIds,
    CafeTheme selectedTheme,
  ) {
    final bool isSaved = savedIds.contains(cafe.id);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pushNamed(
          CafeProfileScreen.routeName,
          arguments: cafe,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderBlack, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: borderBlack,
              blurRadius: 0,
              offset: Offset(3.6, 3.6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //cafe image with heart icon on top
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.asset(
                    cafe.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                //heart icon, toggles saved state on tap
                Positioned(
                  top: 12,
                  right: 12,
                  child: InkWell(
                    customBorder: CircleBorder(),
                    onTap: () {
                      _toggleSaved(cafe);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSaved ? selectedTheme.dark : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: borderBlack,
                          width: 1.8,
                        ),
                      ),
                      child: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_outline,
                        size: 18,
                        color: isSaved ? Colors.white : secondaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            //cafe details block
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  //cafe name and rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cafe.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      //star rating chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ratingBadgeBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              cafe.rating.toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  //neighbourhood and category tags
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderBlack, width: 1.8),
                        ),
                        child: Text(
                          cafe.neighbourhood,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selectedTheme.tag,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cafe.category,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: selectedTheme.dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  //open/closed status
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: cafe.status.startsWith('Open')
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cafe.status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: cafe.status.startsWith('Open')
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  //only cafes with seats can take table bookings
                  SizedBox(
                    width: double.infinity,
                    child: cafe.hasSeats
                        ? ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                '/booking-form',
                                arguments: cafe,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedTheme.dark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: borderBlack,
                                  width: 1.8,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Book a Table',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedTheme.tag,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: borderBlack,
                                width: 1.8,
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
            ),
          ],
        ),
      ),
    );
  }
}