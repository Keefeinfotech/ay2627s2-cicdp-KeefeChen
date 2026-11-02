import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_service.dart';
import '../data/session_store.dart';
import '../widgets/auth_shell.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.auth});

  final AuthService? auth;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  late final AuthService _auth = widget.auth ?? AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final session = await _auth.signup(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.home,
        arguments: HomeArgs(
          ownerId: session.email,
          displayName: session.displayName,
          session: session,
        ),
      );
    } on ApiException catch (err) {
      if (mounted) _showError(err.message);
    } on SessionException catch (err) {
      if (mounted) _showError(err.message);
    } catch (_) {
      if (mounted) {
        _showError('Something went wrong while creating your account.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    AppSnackBar.error(context, message);
  }

  void _openLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthShell(
      title: 'Create your account',
      subtitle: 'Set up your workspace and keep your tasks secure.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            'Already have an account?',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _openLogin,
            child: const Text('Sign In'),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: _name,
                labelText: 'Name (optional)',
                hintText: 'How should we address you?',
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                enabled: !_loading,
                autofillHints: const <String>[AutofillHints.name],
                validator: (value) {
                  if ((value ?? '').trim().length > 80) {
                    return 'Keep your name under 80 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _email,
                labelText: 'Email address',
                hintText: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
                autofillHints: const <String>[AutofillHints.email],
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return 'Enter your email address';
                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(email)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _password,
                labelText: 'Password',
                hintText: 'At least 8 characters',
                helperText: 'Use at least 8 characters.',
                obscureText: true,
                showObscureToggle: true,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.newPassword],
                onFieldSubmitted: (_) => _signup(),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _loading ? 'Creating Account...' : 'Create Account',
                onPressed: _loading ? null : _signup,
                isLoading: _loading,
                expand: true,
                size: AppButtonSize.large,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
