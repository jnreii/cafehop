import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cafehop/models/bookings.dart';
import 'package:cafehop/models/review.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/themes.dart';
import 'package:cafehop/widgets/cafe_hop_app_bar.dart';

class ReviewFormScreen extends ConsumerStatefulWidget {
  static String routeName = '/review-form';

  @override
  ConsumerState<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends ConsumerState<ReviewFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  //minimum characters required in the comment, stops 1-word reviews
  static const int _minCommentLength = 15;

  //most reviews only need a couple photos, capping keeps the firestore size in check
  static const int _maxPhotos = 5;

  int _rating = 0;
  bool _isLoading = false;

  //raw bytes of picked photos, kept in memory for the preview
  //REMINDER: using bytes (not File) so this works on both web and android
  final List<Uint8List> _pickedImages = [];

  //label shown under the stars depending on rating picked
  final Map<int, String> _ratingLabels = {
    1: 'Poor',
    2: 'Below Average',
    3: 'Good',
    4: 'Great',
    5: 'Excellent',
  };

  @override
  void initState() {
    super.initState();
    //rebuilds the char counter as the user types
    _commentController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  //opens the camera or gallery, mode 0 = camera, 1 = gallery, same pattern as MP9
  //gallery lets the user pick more than 1 photo at once
  Future<void> _pickImage(int mode) async {
    if (_pickedImages.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can add up to $_maxPhotos photos.')),
      );
      return;
    }

    if (mode == 0) {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        imageQuality: 90,
      );
      if (image == null) return;

      //XFile.readAsBytes works on both web and android, unlike dart:io File
      final bytes = await image.readAsBytes();
      setState(() {
        _pickedImages.add(bytes);
      });
      return;
    }

    //gallery, can pick multiple in one go
    final List<XFile> images = await ImagePicker().pickMultiImage(
      maxWidth: 600,
      imageQuality: 90,
    );
    if (images.isEmpty) return;

    final remainingSlots = _maxPhotos - _pickedImages.length;
    final imagesToAdd = images.take(remainingSlots);

    for (final image in imagesToAdd) {
      final bytes = await image.readAsBytes();
      _pickedImages.add(bytes);
    }
    setState(() {});
  }

  //bottom sheet letting the user choose camera or gallery
  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: darkBlue),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(0);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: darkBlue),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(1);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  //submits the review to firestore
  Future<void> _submitReview(Booking booking) async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a star rating first.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(firebaseServiceProvider);
      final user = service.getCurrentUser();

      if (user == null) {
        throw Exception('No user is logged in.');
      }

      if (booking.status != 'completed') {
        throw Exception('Only completed bookings can be reviewed.');
      }

      final alreadyReviewed = await service.hasReview(booking.id);

      if (alreadyReviewed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already reviewed this visit.'),
            ),
          );
        }
        return;
      }

      String reviewerName = user.displayName?.trim() ?? '';

      if (reviewerName.isEmpty && user.email != null) {
        reviewerName = user.email!.split('@')[0];
      }

      if (reviewerName.isEmpty && user.phoneNumber != null) {
        reviewerName = user.phoneNumber!;
      }

      if (reviewerName.isEmpty) {
        reviewerName = 'CafeHop User';
      }

      final review = Review(
        bookingId: booking.id,
        cafeId: booking.cafeId,
        userId: user.uid,
        reviewerName: reviewerName,
        rating: _rating.toDouble(),
        comment: _commentController.text.trim(),
        postedAgo: 'Just now',
        postedAt: DateTime.now(),
        photosBase64: _pickedImages.map((bytes) => base64Encode(bytes)).toList(),
      );

      await service.addReview(review);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit review. $e'),
          ),
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

  @override
  Widget build(BuildContext context) {
    final booking =
        ModalRoute.of(context)!.settings.arguments as Booking;

    final int commentLength = _commentController.text.trim().length;

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: CafeHopAppBar(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How was ${booking.cafeName}?',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: borderBlack,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Your review helps other cafe hoppers know what to expect.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: secondaryText,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Your rating',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: borderBlack,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: List.generate(5, (index) {
                  final star = index + 1;

                  return IconButton(
                    onPressed: () {
                      setState(() {
                        _rating = star;
                      });
                    },
                    icon: Icon(
                      star <= _rating
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  );
                }),
              ),

              //label under the stars, blank until a rating is picked
              if (_rating > 0) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _ratingLabels[_rating]!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[800],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Text(
                'Tell us about your visit',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: borderBlack,
                ),
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _commentController,
                maxLines: 6,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'What did you like about the cafe?',
                  filled: true,
                  fillColor: Colors.white,
                  //hides the default counter, we show our own below
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: borderBlack,
                      width: 1.8,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: borderBlack,
                      width: 1.8,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: logoBlue,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';

                  if (trimmed.isEmpty) {
                    return 'Write something about your visit.';
                  }

                  if (trimmed.length < _minCommentLength) {
                    return 'Please write at least $_minCommentLength characters.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 4),

              //char counter, turns amber once past the minimum
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$commentLength/500',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: commentLength >= _minCommentLength
                        ? Colors.black38
                        : Colors.orange[700],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Add photos (optional)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: borderBlack,
                ),
              ),

              const SizedBox(height: 10),

              //horizontal row of picked photo thumbnails + an add tile
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < _pickedImages.length; i++) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: borderBlack,
                                  width: 1.8,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.memory(
                                _pickedImages[i],
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              customBorder: CircleBorder(),
                              onTap: () {
                                setState(() {
                                  _pickedImages.removeAt(i);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],

                    //add tile, hidden once the max is reached
                    if (_pickedImages.length < _maxPhotos)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _showPhotoSourceSheet,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: borderBlack,
                              width: 1.8,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: darkBlue, size: 22),
                              const SizedBox(height: 4),
                              Text(
                                'Add',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: darkBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _submitReview(booking);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit Review',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              //lets the user leave without reviewing, they can still do it
              //later from the Leave a Review button on the booking
              Center(
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop(false);
                        },
                  child: Text(
                    'Maybe later, leave a review another time',
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
      ),
    );
  }
}