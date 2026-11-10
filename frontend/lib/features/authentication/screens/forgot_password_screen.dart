import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_service.dart';
import '../widgets/auth_shell.dart';

/// Step one of the password reset flow: ask for the account email and tell the
/// user what to expect. The backend always responds with the same message, so
/// this screen cannot be used to enumerate registered addresses.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.auth});

  final AuthService? auth;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  late final AuthService _auth = widget.auth ?? AuthService();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _auth.forgotPassword(email: _email.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException catch (err) {
      if (mounted) AppSnackBar.error(context, err.message);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'Something went wrong while sending the reset link. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSignIn() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_sent) {
      return AuthShell(
        title: 'Check your inbox',
        subtitle: 'We sent a reset link if the address is registered.',
        footer: TextButton(
          onPressed: _openSignIn,
          child: const Text('Back to sign in'),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  'If an account exists for that email, a password reset link '
                  'is on its way. Follow it within 30 minutes to choose a new '
                  'password.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Back to sign in',
                onPressed: _openSignIn,
                expand: true,
                size: AppButtonSize.large,
              ),
            ],
          ),
        ),
      );
    }

    return AuthShell(
      title: 'Reset your password',
      subtitle: 'Enter the email you used to sign up.',
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
                  controller: _email,
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.email],
                  enabled: !_loading,
                  onFieldSubmitted: (_) => _submit(),
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
                AppButton(
                  label: _loading ? 'Sending…' : 'Send reset link',
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
