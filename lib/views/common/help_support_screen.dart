import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uni_transit/services/auth_service.dart';
import 'package:intl/intl.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  
  List<Map<String, dynamic>> _userTickets = [];
  String? _userRole;
  bool _isSubmitting = false;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserTickets();
    _prefillUserData();
  }

  void _prefillUserData() {
    if (_currentUser != null) {
      _nameController.text = _currentUser.displayName ?? '';
      _emailController.text = _currentUser.email ?? '';
      _phoneController.text = _currentUser.phoneNumber ?? '';
      
      AuthService().getUserRole(_currentUser.uid).then((role) {
        if (mounted) {
          setState(() {
            _userRole = role;
          });
        }
      });
    }
  }

  void _fetchUserTickets() {
    if (_currentUser == null) return;

    _firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: _currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      final List<Map<String, dynamic>> loadedTickets = [];
      for (var doc in snapshot.docs) {
        final ticket = doc.data();
        ticket['id'] = doc.id;
        loadedTickets.add(ticket);
      }

      if (mounted) {
        setState(() {
          _userTickets = loadedTickets;
        });
      }
    }, onError: (error) {
      debugPrint("Error fetching tickets: $error");
    });
  }

  Future<void> _submitTicket() async {
    if (_nameController.text.trim().isEmpty) {
      _showToast("Please enter your name", Colors.orange);
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showToast("Please enter your phone number", Colors.orange);
      return;
    }

    if (_issueController.text.trim().isEmpty) {
      _showToast("Please describe your issue", Colors.orange);
      return;
    }

    if (_currentUser == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestore.collection('support_tickets').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'issue': _issueController.text.trim(),
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
        'userEmail': _currentUser.email,
        'userName': _currentUser.displayName ?? 'Anonymous',
        'userRole': _userRole ?? 'Unknown',
        'userId': _currentUser.uid,
      });

      _issueController.clear();
      _showToast("Issue submitted successfully!", Colors.green);
    } catch (e) {
      _showToast("Error: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showToast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

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
                _buildCustomHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIssueReporter(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 10,
        bottom: 32,
        left: 24,
        right: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                "SUPPORT",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            "How can we\nhelp you today?",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primaryYellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
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
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildIssueReporter() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel("Full Name"),
          _buildTextField(_nameController, "Enter your name", Icons.person_outline_rounded),
          const SizedBox(height: 24),
          
          _buildInputLabel("Email Address"),
          _buildTextField(_emailController, "Enter your email", Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 24),
          
          _buildInputLabel("Phone Number"),
          _buildTextField(_phoneController, "Enter your phone", Icons.phone_android_rounded, keyboardType: TextInputType.phone),
          const SizedBox(height: 24),
          
          _buildInputLabel("Describe your issue"),
          _buildTextField(_issueController, "Provide details about your problem...", Icons.chat_bubble_outline_rounded, maxLines: 4),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppColors.primaryYellow.withOpacity(0.3),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : Text(
                      "Submit", 
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800, 
                        fontSize: 16,
                        letterSpacing: 1,
                      )
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white24, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryYellow),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryYellow, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final timestamp = ticket['timestamp'] as Timestamp?;
    final date = timestamp != null 
        ? DateFormat('MMM dd, hh:mm a').format(timestamp.toDate())
        : 'Recently';
    
    final status = ticket['status'] ?? 'Pending';
    final statusColor = status == 'Resolved' ? Colors.green : AppColors.primaryYellow;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 11, 
                        fontWeight: FontWeight.w800, 
                        color: statusColor,
                        letterSpacing: 0.5
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                date, 
                style: GoogleFonts.poppins(
                  fontSize: 11, 
                  fontWeight: FontWeight.w600,
                  color: Colors.white38
                )
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            ticket['issue'] ?? 'No description provided.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              height: 1.6,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
