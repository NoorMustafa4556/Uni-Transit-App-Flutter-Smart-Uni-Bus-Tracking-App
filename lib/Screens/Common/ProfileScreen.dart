import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Constants/AppColors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("My Profile", style: GoogleFonts.poppins()),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body:
          user == null
              ? const Center(child: Text("Not Logged In"))
              : FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error fetching profile"));
                  }

                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final name = data?['name'] ?? "User";
                  final role = data?['role'] ?? "N/A";
                  final email = user.email ?? "";

                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.accentAmber,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "U",
                            style: GoogleFonts.poppins(
                              fontSize: 40,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          role,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 40),
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: Text(
                            "Email",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          subtitle: Text(
                            email,
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                        ),
                        const Divider(),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
