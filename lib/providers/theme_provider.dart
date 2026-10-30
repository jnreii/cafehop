import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cafehop/services/theme_service.dart';

//the 3 CafeHop accent themes, cream background and black outlines stay
//the same across all of them, only the accent family changes
class CafeTheme {
  final String name;
  final String label;
  final Color primary; //main accent, buttons and selected states
  final Color dark; //deeper shade, headings and emphasis
  final Color tag; //pale shade, category tags and chips

  const CafeTheme({
    required this.name,
    required this.label,
    required this.primary,
    required this.dark,
    required this.tag,
  });
}

const cafeThemes = <CafeTheme>[
  CafeTheme(
    name: 'blue',
    label: 'Cafe Blue',
    primary: Color.fromARGB(255, 12, 35, 137),
    dark: Color(0xFF00147C),
    tag: Color(0xFFDFE0FF),
  ),
  CafeTheme(
    name: 'matcha',
    label: 'Matcha Green',
    primary: Color(0xFF3F7D3C),
    dark: Color(0xFF1E4A1C),
    tag: Color(0xFFDDECD6),
  ),
  CafeTheme(
    name: 'mocha',
    label: 'Mocha Brown',
    primary: Color.fromARGB(255, 122, 78, 49),
    dark: Color.fromARGB(255, 59, 35, 21),
    tag: Color(0xFFF0E0D2),
  ),
];

final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

//holds the currently selected CafeTheme, loads the saved one on startup
final themeProvider =
    StateNotifierProvider<ThemeController, CafeTheme>((ref) {
  final service = ref.read(themeServiceProvider);
  return ThemeController(service);
});

class ThemeController extends StateNotifier<CafeTheme> {
  final ThemeService service;

  ThemeController(this.service) : super(cafeThemes[0]) {
    loadTheme();
  }

  Future<void> loadTheme() async {
    final savedName = await service.getTheme();
    state = cafeThemes.firstWhere(
      (t) => t.name == savedName,
      orElse: () => cafeThemes[0],
    );
  }

  Future<void> setTheme(CafeTheme theme) async {
    state = theme;
    await service.setTheme(theme.name);
  }
}