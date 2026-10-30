import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/models/review.dart';
import 'package:cafehop/services/firebase_service.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';
import 'package:cafehop/widgets/review_card.dart';

//full scrollable list of a cafe's reviews with star filtering
//opened from the "See all reviews" link on the cafe profile
class AllReviewsScreen extends StatefulWidget {
  static String routeName = '/all-reviews';

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  //0 means All, otherwise the exact star value to filter by
  int selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final cafe = ModalRoute.of(context)!.settings.arguments as Cafe;

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: CafeHopAppBar(showBackButton: true),
      body: StreamBuilder<List<Review>>(
        stream: FirebaseService().getReviews(cafe.id),
        builder: (context, snapshot) {
          final allReviews = snapshot.data ?? [];

          //rounds so a 4.5 counts under both the 4 and 5 filters equally
          //to whichever star its closer to
          final filteredReviews = selectedFilter == 0
              ? allReviews
              : allReviews
                  .where((r) => r.rating.round() == selectedFilter)
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cafe.name} Reviews',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: borderBlack,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${allReviews.length} review${allReviews.length == 1 ? '' : 's'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              //star filter chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip(label: 'All', value: 0),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: '5', value: 5, showStar: true),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: '4', value: 4, showStar: true),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: '3', value: 3, showStar: true),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: '2', value: 2, showStar: true),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: '1', value: 1, showStar: true),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: filteredReviews.isEmpty
                    ? Center(
                        child: Text(
                          selectedFilter == 0
                              ? 'No reviews yet.'
                              : 'No $selectedFilter star reviews yet.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.black38,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filteredReviews.length,
                        itemBuilder: (ctx, i) {
                          return buildReviewCard(filteredReviews[i]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int value,
    bool showStar = false,
  }) {
    final bool isSelected = selectedFilter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: () {
        setState(() {
          selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? logoBlue : Colors.white,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected ? logoBlue : Colors.black26,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStar) ...[
              Icon(
                Icons.star,
                size: 13,
                color: isSelected ? Colors.white : Colors.amber,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : borderBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}