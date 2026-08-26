import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../models/app_user.dart';
import '../../../state/auth_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';

/// Edit the signed-in Warkari's details (saved offline instantly).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _emgName = TextEditingController();
  final TextEditingController _emgPhone = TextEditingController();
  final TextEditingController _dindi = TextEditingController();
  final TextEditingController _city = TextEditingController();

  String _gender = AppConstants.genders.first;
  String _bloodGroup = AppConstants.bloodGroups.first;

  @override
  void initState() {
    super.initState();
    final AppUser? user = context.read<AuthProvider>().user;
    if (user != null) {
      _name.text = user.fullName;
      _age.text = '${user.age}';
      _emgName.text = user.emergencyContactName;
      _emgPhone.text = user.emergencyContactPhone;
      _dindi.text = user.dindiName ?? '';
      _city.text = user.homeCity ?? '';
      _gender = user.gender;
      _bloodGroup = user.bloodGroup;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _emgName.dispose();
    _emgPhone.dispose();
    _dindi.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final AppUser? current = context.read<AuthProvider>().user;
    if (current == null) return;

    await context.read<AuthProvider>().updateProfile(
          current.copyWith(
            fullName: _name.text.trim(),
            age: int.parse(_age.text.trim()),
            gender: _gender,
            bloodGroup: _bloodGroup,
            emergencyContactName: _emgName.text.trim(),
            emergencyContactPhone: _emgPhone.text.trim(),
            dindiName: _dindi.text.trim().isEmpty ? null : _dindi.text.trim(),
            homeCity: _city.text.trim().isEmpty ? null : _city.text.trim(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: <Widget>[
              AppTextField(
                label: 'Full name',
                controller: _name,
                prefixIcon: Icons.person_outline_rounded,
                validator: Validators.name,
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
                      validator: Validators.age,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Gender',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          isExpanded: true,
                          items: AppConstants.genders
                              .map((String g) => DropdownMenuItem<String>(
                                    value: g,
                                    child: Text(g),
                                  ))
                              .toList(),
                          onChanged: (String? v) =>
                              setState(() => _gender = v ?? _gender),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Blood group',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _bloodGroup,
                    isExpanded: true,
                    items: AppConstants.bloodGroups
                        .map((String b) => DropdownMenuItem<String>(
                              value: b,
                              child: Text(b),
                            ))
                        .toList(),
                    onChanged: (String? v) =>
                        setState(() => _bloodGroup = v ?? _bloodGroup),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Emergency contact name',
                controller: _emgName,
                prefixIcon: Icons.contact_emergency_outlined,
                validator: Validators.name,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Emergency contact number',
                controller: _emgPhone,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_in_talk_rounded,
                validator: Validators.phone,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Dindi / group name',
                controller: _dindi,
                prefixIcon: Icons.groups_2_rounded,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Home city / village',
                controller: _city,
                prefixIcon: Icons.home_outlined,
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.all(12),
                borderColor: AppColors.saffronLight,
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppColors.saffronDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mobile number can\'t be changed in offline mode. '
                        'It becomes editable once Firebase is connected.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Save changes',
                icon: Icons.save_rounded,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
