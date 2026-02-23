import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../Constants/AppColors.dart';
import '../../Providers/ThemeProvider.dart';
import '../../Services/AuthService.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  final _authService = AuthService();
  bool _isLoadingName = false;
  bool _isLoadingPass = false;

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  void _loadCurrentName() async {
    final user = _authService.currentUser;
    if (user != null) {
      // Ideally fetch from Firestore to get latest name, but DisplayName is okay for init
      // We can also use AuthService logic if we cached it.
      // For now let's just use what Auth has, assuming it's synced.
      _nameController.text = user.displayName ?? "User";
    }
  }

  void _updateName() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoadingName = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _authService.updateName(user.uid, _nameController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Name Updated!")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoadingName = false);
    }
  }

  void _changePassword() async {
    if (_oldPassController.text.isEmpty ||
        _newPassController.text.isEmpty ||
        _confirmPassController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Fill all password fields")));
      return;
    }

    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match")),
      );
      return;
    }

    setState(() => _isLoadingPass = true);
    try {
      await _authService.changePassword(
        _oldPassController.text,
        _newPassController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password Changed Successfully!")),
        );
        _oldPassController.clear();
        _newPassController.clear();
        _confirmPassController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoadingPass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: GoogleFonts.poppins()),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Section
          ListTile(
            title: Text(
              "Dark Mode",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            trailing: Switch(
              value: isDark,
              onChanged: (val) {
                ref.read(themeProvider.notifier).toggleTheme(val);
              },
              activeColor: AppColors.accentAmber,
            ),
          ),
          const Divider(),

          // Profile Edit Section
          const SizedBox(height: 10),
          Text(
            "Profile Settings",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _updateName(),
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLoadingName ? null : _updateName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
                child:
                    _isLoadingName
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.save),
              ),
            ],
          ),

          const Divider(height: 40),

          // Password Change Section
          Text(
            "Security",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),

          // Old Password
          TextField(
            controller: _oldPassController,
            obscureText: _obscureOld,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: "Old Password",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureOld ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscureOld = !_obscureOld),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // New Password
          TextField(
            controller: _newPassController,
            obscureText: _obscureNew,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: "New Password",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Confirm Password
          TextField(
            controller: _confirmPassController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _changePassword(),
            decoration: InputDecoration(
              labelText: "Confirm New Password",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed:
                    () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoadingPass ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child:
                  _isLoadingPass
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                        "Change Password",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
