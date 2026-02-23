import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Constants/AppColors.dart';
import '../Constants/AppAssets.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showLogo;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showLogo = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          if (showLogo) ...[
            Image.asset(AppAssets.iubLogo, height: 30),
            const SizedBox(width: 10),
          ],
          Text(title, style: GoogleFonts.poppins()),
        ],
      ),
      backgroundColor: AppColors.primaryNavy,
      foregroundColor: Colors.white,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
