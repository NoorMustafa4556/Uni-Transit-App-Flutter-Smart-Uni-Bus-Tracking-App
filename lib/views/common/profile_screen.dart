import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/widgets/app_drawer.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;


    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("MY PROFILE", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () {},
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: user == null
          ? const Center(child: Text("Not Logged In"))
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                if (data == null) return const Center(child: Text("No Profile Found"));

                final name = data['name'] ?? "Welcome User";
                final role = data['role'] ?? "Student";
                final email = user.email ?? "user@iub.edu.pk";
                final rollNo = data['rollNo'] ?? "Not Found";
                final dept = data['department'] ?? "Not Set";

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(context, data, name, role, email),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("ACADEMIC DETAILS"),
                            _buildInfoTile(
                              icon: Icons.school_rounded,
                              label: "Department",
                              value: dept,
                            ),
                            _buildInfoTile(
                              icon: Icons.badge_rounded,
                              label: "Roll Number",
                              value: rollNo,
                            ),
                            _buildInfoTile(
                              icon: Icons.assignment_ind_rounded,
                              label: "Registration",
                              value: data['regNo'] ?? "N/A",
                            ),
                            
                            const SizedBox(height: 24),
                            _buildSectionTitle("CONTACT INFO"),
                            _buildInfoTile(
                              icon: Icons.email_rounded,
                              label: "Email Address",
                              value: email,
                            ),
                            _buildInfoTile(
                              icon: Icons.phone_android_rounded,
                              label: "Phone Number",
                              value: data['phone'] ?? "Verification Pending",
                            ),

                            const SizedBox(height: 32),
                            SizedBox(
                              height: 60,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pushReplacementNamed(
                                  context, 
                                  role == 'Driver' ? '/driver_dashboard' : '/student_dashboard'
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNavy,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(
                                  "BACK TO DASHBOARD",
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic>? data, String name, String role, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              backgroundImage: (data?['profileImage'] != null) ? NetworkImage(data!['profileImage']) : null,
              child: (data?['profileImage'] == null) 
                  ? const Icon(Icons.person, color: Colors.white, size: 60) 
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentAmber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey[500],
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryNavy, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
