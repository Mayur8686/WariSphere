import 'package:flutter/foundation.dart';

import '../core/services/auth_service.dart';
import '../core/services/storage_service.dart';
import '../models/app_user.dart';

/// Holds the signed-in Warkari and drives Splash → Login/Register → Home.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthService authService, required StorageService storage})
      : _auth = authService,
        _storage = storage;

  final AuthService _auth;
  final StorageService _storage;

  AppUser? _user;
  bool _busy = false;
  String? _error;

  AppUser? get user => _user;
  bool get busy => _busy;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  /// Synchronous session restore from the offline cache (called on splash).
  void restore() {
    _user = _storage.loadUser();
    notifyListeners();
  }

  Future<bool> login({required String phone, required String password}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _auth.login(phone: phone, password: password);
      await _storage.saveUser(_user!);
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> register(AppUser newUser, {required String password}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _auth.register(newUser, password: password);
      await _storage.saveUser(_user!);
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(AppUser updated) async {
    _user = updated;
    await _storage.saveUser(updated);
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
