import 'package:shared_preferences/shared_preferences.dart';

//saves and loads the user's chosen CafeHop theme
//same SharedPreferences pattern as MP11, just storing a theme name
class ThemeService {
  static const String _key = 'selectedTheme';

  Future<void> setTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, themeName);
  }

  //returns the saved theme name, defaults to cafe blue for new users
  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'blue';
  }
}