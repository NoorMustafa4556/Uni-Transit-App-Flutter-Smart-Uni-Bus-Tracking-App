import 'package:flutter/material.dart';

// Auth & Splash
import '../../views/splash_screen.dart';
import '../../views/auth/login_screen.dart';
import '../../views/auth/signup_screen.dart';

// Common
import '../../views/common/complete_profile_screen.dart';
import '../../views/onboarding_screen.dart';
import '../../views/common/profile_screen.dart';
import '../../views/common/settings_screen.dart';
import '../../views/common/about_screen.dart';

// Dashboards & Tracking
import '../../views/driver/driver_dashboard.dart';
import '../../views/student/student_dashboard.dart';
import '../../views/live_tracking_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String completeProfile = '/complete_profile';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String tracking = '/tracking';
  static const String driverDashboard = '/driver_dashboard';
  static const String studentDashboard = '/student_dashboard';
  static const String support = '/support';
  static const String about = '/about';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => const SplashScreen(),
      onboarding: (context) => const OnboardingScreen(),
      login: (context) => const LoginScreen(),
      signup: (context) => const SignUpScreen(),
      completeProfile: (context) => const CompleteProfileScreen(),
      profile: (context) => const ProfileScreen(),
      settings: (context) => const SettingsScreen(),
      tracking: (context) => const LiveTrackingScreen(),
      driverDashboard: (context) => const DriverDashboard(),
      studentDashboard: (context) => const StudentDashboard(),
      support: (context) => const AboutScreen(), // reusing About for now as support mock
      about: (context) => const AboutScreen(),
    };
  }
}
