import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/screens/cafe_profile_screen.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';

//shows every "Just For You" cafe as a vertical list
class ViewAllScreen extends ConsumerStatefulWidget {
  static String routeName = '/view-all';

  @override
  ConsumerState<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends ConsumerState<ViewAllScreen> {
  String selectedCategory = 'All';
  String selectedSort = 'Recommended';

  //recommendation tags shown over the cafe images
  static const List<String> _tags = [
    'Because you love matcha',
    'Trending in Tiong Bahru',
    'Popular near you',
    'New in Bedok',
    'Top rated this week',
  ];

  //filters cafes by the selected category
  List<Cafe> _filterCafes(List<Cafe> cafes) {
    if (selectedCategory == 'All') {
      return List<Cafe>.from(cafes);
    }

    return cafes
        .where((cafe) => cafe.category == selectedCategory)
        .toList();
  }

  //sorts the cafes based on the selected sort option
  List<Cafe> _sortCafes(List<Cafe> cafes) {
    final sortedCafes = List<Cafe>.from(cafes);

    if (selectedSort == 'Top Rated') {
      sortedCafes.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (selectedSort == 'Nearest') {
      sortedCafes.sort(
        (a, b) => _distanceValue(a.distance).compareTo(
          _distanceValue(b.distance),
        ),
      );
    } else if (selectedSort == 'A-Z') {
      sortedCafes.sort(
        (a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      );
    }

    return sortedCafes;
  }

  //turns something like "0.8km" into 0.8 so it can be sorted
  double _distanceValue(String distance) {
    return double.tryParse(
          distance.toLowerCase().replaceAll('km', '').trim(),
        ) ??
        double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    //gets the CafeHop colours currently selected by the user
    final selectedTheme = ref.watch(themeProvider);

    final cafesAsync = ref.watch(cafesProvider);

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: CafeHopAppBar(showBackButton: true),

      body: cafesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        error: (error, stackTrace) => Center(
          child: Text(
            'Could not load cafes. Please try again.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: secondaryText,
            ),
          ),
        ),

        data: (cafes) {
          //gets the categories directly from firestore cafe data
          final categories = <String>[
            'All',
            ...cafes.map((cafe) => cafe.category).toSet(),
          ];

          final filteredCafes = _filterCafes(cafes);
          final displayedCafes = _sortCafes(filteredCafes);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Just For You',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: borderBlack,
                      ),
                    ),

                    //sort dropdown
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() {
                          selectedSort = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'Recommended',
                          child: Text('Recommended'),
                        ),
                        const PopupMenuItem(
                          value: 'Top Rated',
                          child: Text('Top Rated'),
                        ),
                        const PopupMenuItem(
                          value: 'Nearest',
                          child: Text('Nearest'),
                        ),
                        const PopupMenuItem(
                          value: 'A-Z',
                          child: Text('A-Z'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: borderBlack,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: borderBlack,
                              blurRadius: 0,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sort,
                              size: 16,
                              color: borderBlack,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              selectedSort,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: borderBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${displayedCafes.length} hidden gems',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: secondaryText,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              //category filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: categories.map((category) {
                    final isSelected = selectedCategory == category;

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
                            horizontal: 15,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? selectedTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? selectedTheme.primary
                                  : borderBlack,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? Colors.white
                                  : borderBlack,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: displayedCafes.isEmpty
                    ? Center(
                        child: Text(
                          'No cafes found in this category.',
                          style: GoogleFonts.plusJakartaSans(
                            color: secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        itemCount: displayedCafes.length,
                        itemBuilder: (ctx, i) {
                          final cafe = displayedCafes[i];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildRecommendedCard(
                              context,
                              cafe,
                              i,
                              selectedTheme,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  //builds one recommended cafe card
  Widget _buildRecommendedCard(
    BuildContext context,
    Cafe cafe,
    int index,
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
            //cafe image with recommendation tag overlay
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
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selectedTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tags[index % _tags.length],
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            //cafe details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cafe.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 8),

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
                            Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
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

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${cafe.neighbourhood} • ${cafe.distance}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selectedTheme.tag,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cafe.category,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: selectedTheme.dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Icon(
                        Icons.circle,
                        size: 8,
                        color: cafe.status.startsWith('Open')
                            ? Colors.green
                            : Colors.red,
                      ),

                      const SizedBox(width: 4),

                      Expanded(
                        child: Text(
                          cafe.status,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: cafe.status.startsWith('Open')
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
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
}