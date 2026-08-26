import '../../models/app_user.dart';
import '../constants/app_constants.dart';
import 'storage_service.dart';

/// Thrown by [AuthService] implementations with a human-readable message.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Contract for authentication. Phase 1/2 uses [MockAuthService] (fully
/// offline). Phase 3 swaps in a FirebaseAuthService without touching
/// screens/providers — they only depend on this interface.
abstract class AuthService {
  Future<AppUser> login({required String phone, required String password});
  Future<AppUser> register(AppUser user, {required String password});
  Future<void> logout();
}

/// Offline mock auth: profile is stored locally on the device.
///
/// TODO(Phase 3): implement `FirebaseAuthService extends AuthService` using
/// `firebase_auth` (phone OTP or email/password) + a Firestore `users`
/// document. Register this implementation in app_bootstrap.dart.
class MockAuthService implements AuthService {
  MockAuthService(this._storage);

  final StorageService _storage;

  @override
  Future<AppUser> login({
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700)); // fake latency

    final AppUser? existing = _storage.loadUser();
    final String? storedPassword = _storage.loadLocalPassword();

    if (existing != null) {
      if (existing.phone == phone && storedPassword == password) {
        return existing;
      }
      if (existing.phone != phone) {
        throw const AuthException(
            'No account found for this number. Please register first.');
      }
      throw const AuthException('Incorrect password. Please try again.');
    }

    // Fresh install: allow the advertised demo account so evaluators can
    // log in without registering.
    if (phone == AppConstants.demoPhone && password == AppConstants.demoPassword) {
      final AppUser demo = _buildDemoUser();
      await _storage.saveUser(demo);
      await _storage.saveLocalPassword(AppConstants.demoPassword);
      return demo;
    }

    throw const AuthException(
        'No account found on this device. Please create your Wari ID first.');
  }

  @override
  Future<AppUser> register(AppUser user, {required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900)); // fake latency

    final AppUser? existing = _storage.loadUser();
    if (existing != null && existing.phone == user.phone) {
      throw const AuthException(
          'This number is already registered. Please log in instead.');
    }

    await _storage.saveUser(user);
    await _storage.saveLocalPassword(password);
    return user;
  }

  @override
  Future<void> logout() async {
    await _storage.clearUser();
    await _storage.clearPassword();
  }

  AppUser _buildDemoUser() {
    return AppUser(
      id: 'WRI-DEMO01',
      fullName: 'Demo Warkari',
      phone: AppConstants.demoPhone,
      age: 42,
      gender: 'Male',
      bloodGroup: 'B+',
      emergencyContactName: 'Sunita (wife)',
      emergencyContactPhone: '9876500000',
      homeCity: 'Pune',
      dindiName: 'Tukaram Maval Dindi',
      createdAt: DateTime.now(),
    );
  }
}
