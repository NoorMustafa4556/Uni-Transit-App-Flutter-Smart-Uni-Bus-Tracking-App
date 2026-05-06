import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/app_assets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 20),
                
                // Brand Section
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 130,
                      height: 130,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryYellow.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Image.asset(AppAssets.iubLogo),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "UniTransit", 
                  style: GoogleFonts.poppins(
                    fontSize: 32, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.white, 
                    letterSpacing: 2
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  "Smart University Transport System", 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    color: AppColors.primaryYellow, 
                    fontWeight: FontWeight.w700, 
                    letterSpacing: 1.5
                  )
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    "Version 1.2.0 (Stable)", 
                    style: GoogleFonts.poppins(
                      fontSize: 11, 
                      fontWeight: FontWeight.w700, 
                      color: Colors.white70
                    )
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Project Details Section
                _buildDetailSection(
                  title: "PROJECT VISION",
                  content: "UniTransit is a state-of-the-art solution designed for The Islamia University of Bahawalpur to digitize the bus tracking experience. It leverages real-time GPS data, Firebase synchronization, and smart routing algorithms to ensure students never miss their commute.",
                ),
                
                const SizedBox(height: 24),
                
                // Contributors Section
                _buildDetailSection(
                  title: "CONTRIBUTORS",
                  isList: true,
                  items: [
                    {"role": "Lead Developer", "name": "Noor Mustafa", "subtitle": "Roll No: F22BDOCS1M01160"},
                    {"role": "Supervisor", "name": "Dr. Umar Farooq Shafi", "subtitle": "Department of CS & IT, IUB"},
                  ],
                ),
                
                const SizedBox(height: 60),
                
                // IUB Branding
                Opacity(
                  opacity: 0.5,
                  child: Column(
                    children: [
                      Text(
                        "THE ISLAMIA UNIVERSITY OF BAHAWALPUR", 
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 10, 
                          fontWeight: FontWeight.w800, 
                          color: Colors.white, 
                          letterSpacing: 1.5
                        )
                      ),
                      const SizedBox(height: 12),
                      const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            "ABOUT APP",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildDetailSection({required String title, String? content, bool isList = false, List<Map<String, String>>? items}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title, 
                style: GoogleFonts.poppins(
                  fontSize: 12, 
                  fontWeight: FontWeight.w800, 
                  color: AppColors.primaryYellow, 
                  letterSpacing: 1.5
                )
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isList && content != null)
            Text(
              content, 
              textAlign: TextAlign.justify, 
              style: GoogleFonts.poppins(
                fontSize: 14, 
                height: 1.7, 
                color: Colors.white.withOpacity(0.7)
              )
            )
          else if (isList && items != null)
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['role']!, 
                    style: GoogleFonts.poppins(
                      fontSize: 10, 
                      color: Colors.white.withOpacity(0.4), 
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['name']!, 
                    style: GoogleFonts.poppins(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white
                    )
                  ),
                  if (item['subtitle'] != null)
                    Text(
                      item['subtitle']!, 
                      style: GoogleFonts.poppins(
                        fontSize: 12, 
                        color: Colors.white.withOpacity(0.5)
                      )
                    ),
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }
}
