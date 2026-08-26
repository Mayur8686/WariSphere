import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../models/app_user.dart';
import '../../../state/auth_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';

/// Registration: creates the pilgrim's Wari ID (offline in Phase 1/2).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _emgName = TextEditingController();
  final TextEditingController _emgPhone = TextEditingController();
  final TextEditingController _dindi = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String _gender = AppConstants.genders.first;
  String _bloodGroup = AppConstants.bloodGroups.first;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name, _phone, _age, _emgName, _emgPhone, _dindi, _city, _password, _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final AuthProvider auth = context.read<AuthProvider>();
    auth.clearError();

    final String stamp =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final AppUser newUser = AppUser(
      id: 'WRI-${stamp.substring(stamp.length - 6)}',
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      age: int.parse(_age.text.trim()),
      gender: _gender,
      bloodGroup: _bloodGroup,
      emergencyContactName: _emgName.text.trim(),
      emergencyContactPhone: _emgPhone.text.trim(),
      homeCity: _city.text.trim().isEmpty ? null : _city.text.trim(),
      dindiName: _dindi.text.trim().isEmpty ? null : _dindi.text.trim(),
      createdAt: DateTime.now(),
    );

    final bool ok = await auth.register(newUser, password: _password.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (Route<dynamic> r) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Could not register')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Wari ID')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: <Widget>[
              Text(
                AppStrings.registerSubtitleMr,
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _FieldLabel('Who are you?'),
                    AppTextField(
                      label: 'Full name',
                      hint: 'e.g. Ramesh Deshmukh',
                      controller: _name,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Mobile number',
                      hint: 'Your own number',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_android_rounded,
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: AppTextField(
                            label: 'Age',
                            controller: _age,
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.cake_outlined,
                            validator: Validators.age,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _DropdownField(
                            label: 'Gender',
                            value: _gender,
                            items: AppConstants.genders,
                            onChanged: (String? v) =>
                                setState(() => _gender = v ?? _gender),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DropdownField(
                      label: 'Blood group',
                      value: _bloodGroup,
                      items: AppConstants.bloodGroups,
                      onChanged: (String? v) =>
                          setState(() => _bloodGroup = v ?? _bloodGroup),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _FieldLabel('Emergency contact (ICE)'),
                    Text(
                      'This person is called if your SOS goes out.',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Contact name',
                      hint: 'e.g. Sunita (wife)',
                      controller: _emgName,
                      prefixIcon: Icons.contact_emergency_outlined,
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Contact mobile',
                      controller: _emgPhone,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_in_talk_rounded,
                      validator: Validators.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _FieldLabel('Optional details'),
                    AppTextField(
                      label: 'Dindi / group name',
                      hint: 'e.g. Tukaram Maval Dindi',
                      controller: _dindi,
                      prefixIcon: Icons.groups_2_rounded,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Home city / village',
                      hint: 'e.g. Alandi',
                      controller: _city,
                      prefixIcon: Icons.home_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _FieldLabel('Security'),
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      obscure: true,
                      prefixIcon: Icons.lock_rounded,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Confirm password',
                      controller: _confirm,
                      obscure: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: Validators.confirmPassword(() => _password.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Create my Wari ID',
                busy: auth.busy,
                icon: Icons.badge_rounded,
                onPressed: _submit,
              ),
              const SizedBox(height: 10),
              Text(
                'Your details are stored on this phone and used inside the app. '
                'Cloud sync turns on with Firebase in Phase 3.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.maroon,
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: items
              .map(
                (String item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 15)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
