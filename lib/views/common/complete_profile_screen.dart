import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

import '../../core/constants/app_colors.dart';
import '../../view_models/auth_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _rollNoController = TextEditingController();
  final _regNoController = TextEditingController();
  final _semesterController = TextEditingController();
  
  String? _selectedDepartment;
  File? _profileImage;
  bool _isLoading = false;

  final List<String> _departments = [
    'Computer Science',
    'Software Engineering',
    'Information Technology',
    'Electrical Engineering',
    'Mechanical Engineering',
    'Civil Engineering',
    'Business Administration',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Other'
  ];

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return null;

      final fileExtension = path.extension(_profileImage!.path);
      final refPath = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}$fileExtension');

      await refPath.putFile(_profileImage!);
      return await refPath.getDownloadURL();
    } catch (e) {
      _showError("Failed to upload image: $e");
      return null;
    }
  }

  void _submitProfile() async {
    final rollNo = _rollNoController.text.trim();
    final regNo = _regNoController.text.trim();
    final semester = _semesterController.text.trim();

    if (_profileImage == null) {
      _showError("Profile picture is strictly required!");
      return;
    }
    if (rollNo.isEmpty) {
      _showError("Roll Number is required");
      return;
    }
    if (regNo.isEmpty) {
      _showError("Registration Number is required");
      return;
    }
    if (_selectedDepartment == null) {
      _showError("Please select a department");
      return;
    }
    if (semester.isEmpty) {
      _showError("Semester is required");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _uploadProfileImage();

      await ref.read(authStateProvider.notifier).updateProfile(
        profileImageUrl: imageUrl,
        rollNo: rollNo,
        regNo: regNo,
        department: _selectedDepartment,
        semester: semester,
      );

      if (!mounted) return;
      
      // Navigate to the Dashboard / Live Tracking
      Navigator.pushReplacementNamed(context, '/student_dashboard');
    } catch (e) {
      if (mounted) {
        _showError("An error occurred. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Complete Your Profile",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We need a bit more info to confirm your academic details.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Profile Image Picker
                    Center(
                      child: GestureDetector(
                        onTap: _isLoading ? null : _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                          child: _profileImage == null
                              ? const Icon(Icons.camera_alt, size: 40, color: AppColors.accentAmber)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        "Upload Profile Picture*",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    _buildTextField(
                      controller: _rollNoController,
                      label: "Roll Number*",
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _regNoController,
                      label: "Registration Number*",
                      icon: Icons.app_registration_outlined,
                    ),
                    const SizedBox(height: 16),
                    
                    // Department Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDepartment,
                      decoration: InputDecoration(
                        labelText: "Department*",
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.school_outlined, color: AppColors.accentAmber),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: AppColors.accentAmber),
                        ),
                      ),
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white),
                      items: _departments.map((dept) {
                        return DropdownMenuItem(value: dept, child: Text(dept));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDepartment = val;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _semesterController,
                      label: "Semester*",
                      icon: Icons.looks_one_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    
                    const SizedBox(height: 48),
                    
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentAmber,
                          foregroundColor: AppColors.primaryNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          )
                        ),
                        child: _isLoading 
                            ? const CircularProgressIndicator(color: AppColors.primaryNavy)
                            : const Text("SAVE PROFILE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: AppColors.accentAmber),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.accentAmber),
        ),
      ),
    );
  }
}
