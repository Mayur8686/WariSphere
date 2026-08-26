import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../state/auth_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/wari_logo.dart';

/// Login with mobile number + password (mock now, Firebase Auth in Phase 3).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthProvider>().clearError();
    final bool ok = await context.read<AuthProvider>().login(
          phone: _phone.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (Route<dynamic> r) => false);
    } else {
      final String? err = context.read<AuthProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Could not sign in')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 12),
                  const WariLogo(size: 84),
                  const SizedBox(height: 28),
                  Text(
                    AppStrings.loginTitle,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.loginSubtitleMr,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 28),
                  AppTextField(
                    label: 'Mobile number',
                    hint: '10-digit number',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_android_rounded,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscure: _obscure,
                    prefixIcon: Icons.lock_rounded,
                    validator: Validators.password,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.inkSoft,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Sign in',
                    busy: auth.busy,
                    icon: Icons.login_rounded,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'New to the wari?',
                        style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                        child: const Text('Create Wari ID'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    borderColor: AppColors.saffronLight,
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.info_outline_rounded,
                            size: 20, color: AppColors.saffronDark),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.ink,
                                height: 1.45,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                    text: 'Demo mode\n',
                                    style: TextStyle(fontWeight: FontWeight.w800)),
                                TextSpan(
                                    text:
                                        '${AppConstants.demoPhone} / ${AppConstants.demoPassword} — or register a fresh Wari ID. Data stays on this device until Firebase is connected (Phase 3).'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
