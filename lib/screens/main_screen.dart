import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/screens/explore_screen.dart';
import 'package:cafehop/screens/bookings_screen.dart';
import 'package:cafehop/screens/saved_screen.dart';
import 'package:cafehop/screens/profile_screen.dart';
import 'package:cafehop/themes.dart';

class MainScreen extends ConsumerStatefulWidget {
  static String routeName = '/main';

  //which tab to open on, used when coming back from a new booking
  final int initialTab;

  MainScreen({
    this.initialTab = 0,
  });

  @override
  ConsumerState createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  //tracks which bottom tab is currently selected
  int _selectedIndex = 0;

  //list of screens for each bottom tab
  final List<Widget> _screens = [
    ExploreScreen(),
    BookingsScreen(),
    SavedScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    //starts on whichever tab was asked for, defaults to Explore
    _selectedIndex = widget.initialTab;
  }

  //updates the selected bottom tab
  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    //gets the accent colour from the theme currently selected by the user
    final selectedTheme = ref.watch(themeProvider);

    return Scaffold(
      //REMINDER: IndexedStack keeps all 4 tabs alive and only shows one
      //using _screens[_selectedIndex] instead would rebuild them and reset stuff
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      //bottom nav bar with 4 tabs
      //black top border matches CafeHopAppBar's bottom border
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: borderBlack, width: 2),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,

          //fixed keeps all 4 labels visible instead of using shifting mode
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: selectedTheme.primary,
          unselectedItemColor: tabInactiveText,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: 'Saved',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}