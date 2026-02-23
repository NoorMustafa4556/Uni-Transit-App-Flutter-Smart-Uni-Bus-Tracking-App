import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Constants/AppColors.dart';
import '../../Services/AuthService.dart';
import 'Auth/LoginScreen.dart';
import '../../Constants/AppAssets.dart';
import 'Student/StudentDashboard.dart';
import 'Driver/DriverDashboard.dart';
import 'Admin/AdminDashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    // Wait for 3 seconds for branding
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final user = _authService.currentUser;
    if (user != null) {
      // User is logged in, try to get role from Cache first
      final prefs = await SharedPreferences.getInstance();
      String? role = prefs.getString('user_role');

      // If not in cache, fetch from Firestore
      if (role == null) {
        try {
          role = await _authService.getUserRole(user.uid);
          if (role != null) {
            await prefs.setString('user_role', role);
          }
        } catch (e) {
          // If error (e.g. offline), we can't do much if we don't have cache.
          // But if we are here, it means we have no cache and network failed.
        }
      }

      if (mounted) {
        if (role == 'Student') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentDashboard()),
          );
        } else if (role == 'Driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverDashboard()),
          );
        } else if (role == 'Admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        } else {
          // Only redirect to login if we REALLY can't find a role and we are sure
          // For now, if role is null, we might want to stay on splash or show retry?
          // But to be safe, let's go to Login if we genuinely can't identify the user.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } else {
      // User not logged in
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(AppAssets.iubLogo, height: 150),
            const SizedBox(height: 20),
            Text(
              "UniTransit",
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: AppColors.accentAmber),
          ],
        ),
      ),
    );
  }
}
