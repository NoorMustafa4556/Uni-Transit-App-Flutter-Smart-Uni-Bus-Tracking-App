import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
      return AuthNotifier(ref.read(authServiceProvider));
    });

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null)) {
    // Listen to auth changes
    _authService.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
    });
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.login(
        email: email,
        password: password,
      );
      if (credential != null) {
        final role = await _authService.getUserRole(credential.user!.uid);
        if (role != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', role);
        }
      }
      state = AsyncValue.data(credential?.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? rollNo,
    String? regNo,
    String? department,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        rollNo: rollNo,
        regNo: regNo,
        department: department,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
      state = AsyncValue.data(_authService.currentUser);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
  }

  Future<void> updateProfile({
    String? profileImageUrl,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
  }) async {
    final user = _authService.currentUser;
    if (user == null) return;
    
    state = const AsyncValue.loading();
    try {
      await _authService.updateProfile(
        uid: user.uid,
        profileImageUrl: profileImageUrl,
        rollNo: rollNo,
        regNo: regNo,
        department: department,
        semester: semester,
      );
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
