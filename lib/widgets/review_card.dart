import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cafehop/models/review.dart';
import 'package:cafehop/themes.dart';

//shared review card, used on both the cafe profile (top 3) and the
//full reviews screen, so styling only needs fixing in one place
Widget buildReviewCard(Review review) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderBlack, width: 1.8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              review.reviewerName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            //star rating
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ratingBadgeBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, size: 12, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    review.rating.toString(),
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
        Text(
          review.comment,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: tabInactiveText,
            height: 1.4,
          ),
        ),
        if (review.photosBase64.isNotEmpty) ...[
          const SizedBox(height: 8),
          ReviewPhotoCarousel(photosBase64: review.photosBase64),
        ],
        const SizedBox(height: 6),
        Text(
          review.postedAgo,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: Colors.black38,
          ),
        ),
      ],
    ),
  );
}

//swipeable photo viewer for a review with more than 1 photo
//sizes itself to the first photo's shape, clamped between a min and max
//height so it never gets absurdly tall/short or jumps around wildly
class ReviewPhotoCarousel extends StatefulWidget {
  final List<String> photosBase64;

  const ReviewPhotoCarousel({super.key, required this.photosBase64});

  @override
  State<ReviewPhotoCarousel> createState() => _ReviewPhotoCarouselState();
}

class _ReviewPhotoCarouselState extends State<ReviewPhotoCarousel> {
  int _currentPage = 0;

  //aspect ratio taken from the first photo
  double? _aspectRatio;

  static const double _minHeight = 140;
  static const double _maxHeight = 260;

  @override
  void initState() {
    super.initState();
    _loadFirstImageSize();
  }

  //decodes just the first photo to read its width/height, so we know what
  //shape box to give the whole PageView before anything renders
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
        //default to a normal-ish landscape photo shape while loading
        final ratio = _aspectRatio ?? (4 / 3);

        //height the photo would want at this width, then clamp it so a
        //very tall or very wide photo doesnt blow out the card
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
                      color: i == _currentPage ? darkBlue : Colors.black26,
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