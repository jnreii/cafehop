import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

//color palette
const Color primaryBlue = Color(0xFF1A3C8F);
const Color darkBlue = Color(0xFF00147C);
const Color creamBackground = Color(0xFFFFF8E7);
const Color borderBlack = Color(0xFF1B1B1B); // matches Figma outline colour
const Color secondaryText = Color(0xFF705A4C); // warm brown for secondary text
const Color tabInactiveText = Color(0xFF454654); // dark slate for inactive tabs
const Color ratingBadgeBackground = Color(0xFFF8DAC8); // peachy rating chip
const Color tagBackground = Color(0xFFDFE0FF); // light lavender category tag

//text styles
TextStyle labelStyle = GoogleFonts.plusJakartaSans(
  fontWeight: FontWeight.w600,
  fontSize: 14,
  color: Colors.black87,
);

// Used for body text
TextStyle bodyStyle = GoogleFonts.plusJakartaSans(
  fontSize: 14,
  color: Colors.black87,
);

// Used for secondary/muted text (dates, descriptions)
TextStyle secondaryTextStyle = GoogleFonts.plusJakartaSans(
  fontSize: 14,
  color: secondaryText,
);

//CafeHop logo
const Color logoBlue = Color(0xFF0725B0);

TextStyle logoStyle = GoogleFonts.bricolageGrotesque(
  fontSize: 42,
  fontWeight: FontWeight.bold,
  color: logoBlue,
);

//screen headings
TextStyle headingStyle = GoogleFonts.bricolageGrotesque(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: Colors.black87,
);

//Input Design
// Reusable input border for all TextFormFields
InputDecoration inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black, width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: primaryBlue, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}

//Button Styles
BoxDecoration primaryButtonDecoration = BoxDecoration(
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: borderBlack, width: 1.8),
  boxShadow: [
    BoxShadow(
      color: borderBlack,
      blurRadius: 0,
      offset: Offset(3.6, 3.6),
    ),
  ],
);

//Card Decoration
BoxDecoration cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: borderBlack, width: 1.8),
  boxShadow: [
    BoxShadow(
      color: borderBlack,
      blurRadius: 0,
      offset: Offset(3.6, 3.6),
    ),
  ],
);