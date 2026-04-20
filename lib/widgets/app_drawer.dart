import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/app_assets.dart';
import 'package:uni_transit/services/auth_service.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Logout", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: const Text("Are you sure you want to end your session?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Logout", style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          final userData = snapshot.data;
          final String role = userData?['role'] ?? 'Student';
          
          return Column(
            children: [
              _buildHeader(userData),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 20),
                    _buildSectionTitle("MAIN NAVIGATION"),
                    
                    // Specific routes for Student
                    if (role == 'Student') ...[
                      _DrawerTile(
                        icon: Icons.directions_bus_rounded,
                        title: "Live Tracking",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, '/student_dashboard');
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.map_outlined,
                        title: "Bus Routes",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, '/student_dashboard');
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.calendar_month_rounded,
                        title: "Schedule",
                        onTap: () {
                          Navigator.pop(context);
                          // It's a tab in Student Dashboard
                          Navigator.pushReplacementNamed(context, '/student_dashboard');
                        },
                      ),
                    ],

                    // Specific routes for Driver
                    if (role == 'Driver') ...[
                      _DrawerTile(
                        icon: Icons.dashboard_rounded,
                        title: "Driver Dashboard",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, '/driver_dashboard');
                        },
                      ),
                    ],

                    const SizedBox(height: 20),
                    _buildSectionTitle("ACCOUNT"),
                    _DrawerTile(
                      icon: Icons.person_outline_rounded,
                      title: "My Profile",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    
                    _DrawerTile(
                      icon: Icons.settings_outlined,
                      title: "Settings",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    _buildSectionTitle("SUPPORT & INFO"),
                    _DrawerTile(
                      icon: Icons.help_outline_rounded,
                      title: "Help & Support",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/support');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.info_outline_rounded,
                      title: "About App",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/about');
                      },
                    ),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? userData) {
    String name = userData?['name'] ?? "Welcome User";
    String email = currentUser?.email ?? "uni.transit@iub.edu.pk";
    String role = userData?['role'] ?? "Student";
    String profileUrl = userData?['profileImage'] ?? "";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 30,
        bottom: 30,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentAmber, width: 2),
                ),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white10,
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty 
                    ? const Icon(Icons.person, color: Colors.white, size: 35)
                    : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            email,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          _DrawerTile(
            icon: Icons.logout_rounded,
            title: "Sign Out",
            iconColor: AppColors.error,
            textColor: AppColors.error,
            onTap: _logout,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(AppAssets.iubLogo, height: 20),
              const SizedBox(width: 10),
              Text(
                "UniTransit v1.2.0",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon, 
        color: iconColor ?? (isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.primaryNavy.withValues(alpha: 0.7))
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor ?? (isDark ? Colors.white : AppColors.textDark),
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

