/// Form validators shared by Login / Register / Edit Profile / reports.
class Validators {
  Validators._();

  static String? required(String? v, {String label = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter a name';
    if (v.trim().length < 3) return 'Name looks too short';
    return null;
  }

  /// Indian mobile number: 10 digits starting 6-9.
  static String? phone(String? v) {
    final String value = (v ?? '').trim();
    if (value.isEmpty) return 'Please enter a mobile number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? password(String? v) {
    final String value = v ?? '';
    if (value.isEmpty) return 'Please enter a password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? Function(String?) confirmPassword(String? Function() other) {
    return (String? v) {
      if (v == null || v.isEmpty) return 'Please confirm your password';
      if (v != other()) return 'Passwords do not match';
      return null;
    };
  }

  static String? age(String? v) {
    final String value = (v ?? '').trim();
    if (value.isEmpty) return 'Please enter age';
    final int? parsed = int.tryParse(value);
    if (parsed == null || parsed < 1 || parsed > 120) {
      return 'Enter a valid age (1–120)';
    }
    return null;
  }
}
