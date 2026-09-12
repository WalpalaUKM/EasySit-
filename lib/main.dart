import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/student_home_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/session_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'services/notification_service.dart';
import 'services/session_watcher.dart';
import 'package:flutter/services.dart';
import 'navigator_key.dart';
import 'utils/app_page_route.dart';
import 'utils/app_colors.dart';

// ============================================================================
// APPLICATION ENTRY POINT & SERVICE INITIALIZATION
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase services (Firestore, Auth, Cloud Messaging)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Initialize local notifications plugin for session reminders
  await NotificationService.initialize();

  // 3. Start background real-time session watcher (monitors 2m booked / 10m pending expirations)
  SessionWatcher.start();

  // System UI status bar & navigation bar theme styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarDividerColor: Colors.black26,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const EasySitApp());
}

class EasySitApp extends StatelessWidget {
  const EasySitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 780),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'EasySit',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: EasySitColors.primary,
              primary: EasySitColors.primary,
              surface: EasySitColors.surface,
              surfaceContainerLowest: EasySitColors.appBackground,
            ),
            scaffoldBackgroundColor: EasySitColors.appBackground,
            useMaterial3: true,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
                TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
                TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
                TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
                TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
                TargetPlatform.fuchsia: FadeSlidePageTransitionsBuilder(),
              },
            ),
          ),
          initialRoute: '/splash',
          onGenerateRoute: (settings) {
            Widget screen;
            switch (settings.name) {
              case '/splash':
                screen = const SplashScreen();
                break;
              case '/login':
                screen = const LoginScreen();
                break;
              case '/student_home':
                screen = const StudentHomeScreen();
                break;
              case '/admin_dashboard':
                screen = const AdminDashboardScreen();
                break;
              case '/session':
                screen = const SessionScreen();
                break;
              case '/forgot_password':
                final initialId = settings.arguments as String?;
                screen = ForgotPasswordScreen(initialIdentifier: initialId);
                break;
              default:
                return null;
            }
            return AppPageRoute(builder: (_) => screen, settings: settings);
          },
          builder: (context, widget) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor: Colors.black,
                systemNavigationBarDividerColor: Colors.black26,
                systemNavigationBarIconBrightness: Brightness.light,
              ),
              child: Container(
                color: Colors.black,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: widget ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
