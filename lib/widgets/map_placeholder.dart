import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Reusable map placeholder for interactive map
class MapPlaceholder extends StatelessWidget {
  final double height;

  const MapPlaceholder({this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Center(
        child: Text(
          'Map view',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.black38,
          ),
        ),
      ),
    );
  }
}