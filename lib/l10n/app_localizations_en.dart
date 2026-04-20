// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'UniTransit';

  @override
  String get loginTitle => 'Welcome Back';

  @override
  String get loginSubtitle => 'Access your university commute in one tap';

  @override
  String get emailLabel => 'Email Address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'LOGIN TO SYSTEM';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get signUpLink => 'Sign Up';

  @override
  String get driverTerminal => 'DRIVER TERMINAL';

  @override
  String get studentDashboard => 'STUDENT DASHBOARD';

  @override
  String get busNavigation => 'BUS NAVIGATION';

  @override
  String get busNumber => 'Bus Number';

  @override
  String get origin => 'Origin';

  @override
  String get destination => 'Destination';

  @override
  String get findBuses => 'FIND LIVE BUSES';

  @override
  String get myLocation => 'My Location';

  @override
  String get liveTrackingActive => 'LIVE TRACKING ACTIVE';

  @override
  String get terminateTrip => 'TERMINATE TRIP';

  @override
  String get commenceTracking => 'COMMENCE TRACKING';

  @override
  String get schedule => 'Schedule';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get support => 'Support';

  @override
  String get signOut => 'Sign Out';

  @override
  String get destinationReached => 'Destination Reached';

  @override
  String arrivalMessage(String destination) {
    return 'You have arrived at $destination. Trip will auto-end.';
  }

  @override
  String get endTrip => 'END TRIP';

  @override
  String get tripInitialization => 'TRIP INITIALIZATION';

  @override
  String get enterBusNumber => 'Enter Bus Number (e.g. 45)';

  @override
  String get currentRoute => 'CURRENT ROUTE';

  @override
  String get joinTitle => 'Join UniTransit';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get universityEmail => 'University Email';

  @override
  String get signUpButton => 'CREATE ACCOUNT';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get loginLink => 'LOGIN';

  @override
  String get onboarding1Title => 'Live Bus Tracking';

  @override
  String get onboarding1Desc =>
      'Real-time updates of your university bus at your fingertips.';

  @override
  String get onboarding2Title => 'Arrival Alerts';

  @override
  String get onboarding2Desc => 'Get notified when the bus is near your stop.';

  @override
  String get getStarted => 'GET STARTED';

  @override
  String get next => 'NEXT';
}
