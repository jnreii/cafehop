import 'package:cafehop/screens/booking_summary_screen.dart';
import 'package:cafehop/screens/cafe_profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cafehop/firebase_options.dart';
import 'package:cafehop/providers/firebase_provider.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/screens/login_screen.dart';
import 'package:cafehop/screens/signup_screen.dart';
import 'package:cafehop/screens/reset_password_screen.dart';
import 'package:cafehop/screens/main_screen.dart';
import 'package:cafehop/screens/booking_form_screen.dart';
import 'package:cafehop/screens/booking_detail_screen.dart';
import 'package:cafehop/screens/review_form_screen.dart';
import 'package:cafehop/screens/view_all_screen.dart';
import 'package:cafehop/screens/all_reviews_screen.dart';
import 'package:cafehop/services/notification_service.dart';
import 'package:cafehop/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

late final ProviderContainer appContainer;

Future _handleNotificationTap(String? payload) async {
if (payload == null) return;

final firebaseService =
appContainer.read(firebaseServiceProvider);

//booking reminder opens the exact booking when tapped
if (payload.startsWith('booking:')) {
final bookingId =
payload.substring('booking:'.length);

final booking =
    await firebaseService.getBookingById(bookingId);

if (booking == null) return;

navigatorKey.currentState?.pushNamedAndRemoveUntil(
  BookingDetailScreen.routeName,
  (route) => false,
  arguments: booking,
);
return;
}

//visit reminder brings user back to the Bookings tab
if (payload.startsWith('visit:')) {
navigatorKey.currentState?.pushAndRemoveUntil(
MaterialPageRoute(
builder: (context) => MainScreen(initialTab: 1),
),
(route) => false,
);
return;
}

//AI recommendation opens the exact recommended cafe
if (payload.startsWith('recommendation:')) {
final cafeId =
payload.substring('recommendation:'.length);

final cafe =
    await firebaseService.getCafeById(cafeId);

if (cafe == null) return;

navigatorKey.currentState?.pushNamedAndRemoveUntil(
  CafeProfileScreen.routeName,
  (route) => false,
  arguments: cafe,
);
return;
}

//keeps older notifications working even if they were scheduled before exact ids were added
if (payload == 'booking' || payload == 'visit') {
navigatorKey.currentState?.pushAndRemoveUntil(
MaterialPageRoute(
builder: (context) => MainScreen(initialTab: 1),
),
(route) => false,
);
} else if (payload == 'recommendation') {
navigatorKey.currentState?.pushAndRemoveUntil(
MaterialPageRoute(
builder: (context) => MainScreen(initialTab: 0),
),
(route) => false,
);
}
}

void main() async {
WidgetsFlutterBinding.ensureInitialized();

await Firebase.initializeApp(
options: DefaultFirebaseOptions.currentPlatform, //initialises Firebase using the settings for the current platform
);

appContainer = ProviderContainer();

await NotificationService.initialize(
onNotificationTap: (payload) {
_handleNotificationTap(payload);
},
);

final launchPayload =
await NotificationService.getLaunchPayload();

runApp(
UncontrolledProviderScope(
container: appContainer,
child: MyApp(
initialNotificationPayload: launchPayload,
),
),
);

await NotificationService.requestPermission();
}

class MyApp extends ConsumerStatefulWidget {
final String? initialNotificationPayload;

MyApp({
this.initialNotificationPayload,
});

@override
ConsumerState createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
//makes sure a notification that opened CafeHop from closed state only gets handled once
bool _initialNotificationHandled = false;

//shows the splash first before moving into login or the main app
bool _showSplash = true;

@override
Widget build(BuildContext context) {
final authState = ref.watch(authStateProvider);

//gets the theme currently selected by the user
final selectedTheme = ref.watch(themeProvider);

return MaterialApp(
  navigatorKey: navigatorKey,
  title: 'CafeHop',
  debugShowCheckedModeBanner: false, //removes the debug banner at the top right
  scrollBehavior: const MaterialScrollBehavior().copyWith(
    overscroll: false,
  ),
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: selectedTheme.primary,
    ),
    useMaterial3: true,
  ),
  home: _showSplash
      ? SplashScreen(
          onFinished: () {
            if (mounted) {
              setState(() {
                _showSplash = false;
              });
            }
          },
        )
      : authState.when(
    data: (user) {
      if (user == null) {
        return LoginScreen();
      }

      //waits until MaterialApp is built before navigating from a
      //notification that opened CafeHop while the app was closed
      if (!_initialNotificationHandled &&
          widget.initialNotificationPayload != null) {
        _initialNotificationHandled = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(
            widget.initialNotificationPayload,
          );
        });
      }

      return MainScreen();
    },
    loading: () => const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    ),
    error: (err, stack) => const Scaffold(
      body: Center(
        child: Text('Something went wrong'),
      ),
    ),
  ),

  //routes used to move between the different CafeHop screens
  routes: {
    MainScreen.routeName: (_) {
      return MainScreen();
    },
    LoginScreen.routeName: (_) {
      return LoginScreen();
    },
    SignupScreen.routeName: (_) {
      return SignupScreen();
    },
    ResetPasswordScreen.routeName: (_) {
      return ResetPasswordScreen();
    },
    CafeProfileScreen.routeName: (_) {
      return CafeProfileScreen();
    },
    BookingFormScreen.routeName: (_) {
      return BookingFormScreen();
    },
    BookingSummaryScreen.routeName: (_) {
      return BookingSummaryScreen();
    },
    BookingDetailScreen.routeName: (_) {
      return BookingDetailScreen();
    },
    ReviewFormScreen.routeName: (_) {
      return ReviewFormScreen();
    },
    ViewAllScreen.routeName: (_) {
      return ViewAllScreen();
    },
    AllReviewsScreen.routeName: (_) {
      return AllReviewsScreen();
    },
  },
);
}
}