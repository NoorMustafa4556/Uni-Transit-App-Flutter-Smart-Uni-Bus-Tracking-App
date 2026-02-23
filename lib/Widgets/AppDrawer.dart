import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Constants/AppColors.dart';
import '../../Constants/AppAssets.dart';
import '../Services/AuthService.dart';
import '../Screens/Auth/LoginScreen.dart';
import '../Screens/Common/SettingsScreen.dart';
import '../Screens/Common/ProfileScreen.dart'; // Will create this shortly

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final User? currentUser = AuthService().currentUser;

  Future<Map<String, dynamic>?> _fetchUserData() async {
    if (currentUser == null) return null;
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  void _logout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchUserData(),
            builder: (context, snapshot) {
              String name = "User";
              String email = currentUser?.email ?? "";
              String initial = "U";

              if (snapshot.hasData && snapshot.data != null) {
                name = snapshot.data!['name'] ?? "User";
                if (name.isNotEmpty) initial = name[0].toUpperCase();
              }

              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primaryNavy),
                accountName: Text(
                  name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(email, style: GoogleFonts.poppins()),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: AppColors.accentAmber,
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                otherAccountsPictures: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Image.asset(AppAssets.iubLogo),
                    ),
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: Text("Home", style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context); // Close Drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text("Profile", style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text("Settings", style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              "Logout",
              style: GoogleFonts.poppins(color: Colors.red),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
