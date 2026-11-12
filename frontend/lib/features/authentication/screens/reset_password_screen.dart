import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_service.dart';
import '../widgets/auth_shell.dart';

/// Step two of the password reset flow: use the single-use token from the
/// emailed link to set a new password.
///
/// The token is supplied either as a route argument (in-app navigation) or as
/// the `token` query parameter (emailed deep link).
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.auth, this.token});

  static const String routeInformation = '/reset-password';

  final AuthService? auth;
  final String? token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _special = RegExp(r'[^A-Za-z\d]');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  late final AuthService _auth = widget.auth ?? AuthService();
  late final String? _token = widget.token?.trim().isNotEmpty == true
      ? widget.token
      : null;
  bool _loading = false;
  bool _updated = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final token = _token;
    if (token == null) {
      AppSnackBar.error(
        context,
        'The reset link is missing or malformed. Request a new one.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.resetPassword(token: token, password: _password.text);
      if (!mounted) return;
      setState(() => _updated = true);
    } on ApiException catch (err) {
      if (mounted) AppSnackBar.error(context, err.message);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'Something went wrong while updating your password. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSignIn() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _openForgotPassword() {
    Navigator.pushReplacementNamed(context, AppRoutes.forgotPassword);
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your new password';
    if (password.length < 12) {
      return 'Password must be at least 12 characters';
    }
    if (!_upper.hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!_lower.hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!_digit.hasMatch(password)) {
      return 'Password must contain at least one number';
    }
    if (!_special.hasMatch(password)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_updated) {
      return AuthShell(
        title: 'Password updated',
        subtitle: 'Your password has been changed.',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                size: 72,
                color: AppColors.malachite,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'You can now sign in with your new password.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Sign in',
                onPressed: _openSignIn,
                expand: true,
                size: AppButtonSize.large,
              ),
            ],
          ),
        ),
      );
    }

    if (_token == null) {
      return AuthShell(
        title: 'Invalid reset link',
        subtitle: 'This password reset link is invalid or has expired.',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Request a new reset link, then use it within 30 minutes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Request a new link',
                onPressed: _openForgotPassword,
                expand: true,
                size: AppButtonSize.large,
              ),
            ],
          ),
        ),
      );
    }

    return AuthShell(
      title: 'Choose a new password',
      subtitle:
          'Use at least 12 characters with upper, lower, number and '
          'a special character.',
      showBack: false,
      footer: TextButton(
        onPressed: _loading ? null : _openSignIn,
        child: const Text('Back to sign in'),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  controller: _password,
                  labelText: 'New password',
                  hintText: 'Your new password',
                  obscureText: true,
                  showObscureToggle: true,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  validator: _passwordValidator,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _confirm,
                  labelText: 'Confirm new password',
                  hintText: 'Repeat your new password',
                  obscureText: true,
                  showObscureToggle: true,
                  enabled: !_loading,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => (value ?? '') != _password.text
                      ? 'Passwords do not match'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _loading ? 'Updating…' : 'Update password',
                  onPressed: _loading ? null : _submit,
                  isLoading: _loading,
                  expand: true,
                  size: AppButtonSize.large,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
