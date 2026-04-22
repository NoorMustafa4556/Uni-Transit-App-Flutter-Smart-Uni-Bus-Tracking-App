import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/app_assets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: Text("ABOUT APP", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                child: Image.asset(AppAssets.iubLogo, height: 100),
              ),
            ),
            const SizedBox(height: 24),
            Text("UNITRANSIT", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryNavy, letterSpacing: 4)),
            Text("Smart Bus Tracking Solution", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 40),
            _buildInfoCard("About Mission", "UniTransit is the official smart transit solution for The Islamia University of Bahawalpur. Our mission is to provide students and staff with real-time tracking, accurate schedules, and enhanced safety during their commute."),
            const SizedBox(height: 20),
            _buildInfoCard("Developer Info", "Developed by the Department of Computer Science & IT. \n\nLead Developer: Noor \nVersion: 1.2.0 (Stable)"),
            const SizedBox(height: 40),
            Text("© 2026 IUB UniTransit. All rights reserved.", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          const SizedBox(height: 12),
          Text(content, textAlign: TextAlign.justify, style: GoogleFonts.poppins(fontSize: 13, height: 1.6, color: Colors.black87)),
        ],
      ),
    );
  }
}
