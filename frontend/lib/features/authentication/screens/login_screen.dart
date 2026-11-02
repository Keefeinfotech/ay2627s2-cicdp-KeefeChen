import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_service.dart';
import '../data/session_store.dart';
import '../widgets/auth_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});

  final AuthService? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  late final AuthService _auth = widget.auth ?? AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final session = await _auth.login(
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
        _showError('Something went wrong while signing in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    AppSnackBar.error(context, message);
  }

  void _openSignup() {
    Navigator.pushNamed(context, AppRoutes.signup);
  }

  void _continueOffline() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.home,
      arguments: const HomeArgs(ownerId: AppConstants.guestOwnerId),
    );
  }

  /// The backend exposes no password-reset endpoint, so the link explains the
  /// limitation instead of presenting a reset flow that cannot complete.
  Future<void> _showPasswordHelp() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Password reset'),
          content: const Text(
            'Password reset is not available in this version of Auxilia. '
            'You can create a new account, or continue without an account and '
            'keep using tasks on this device.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthShell(
      title: 'Welcome to Auxilia',
      subtitle: 'Sign in to continue organising your day.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            'New to Auxilia?',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _openSignup,
            child: const Text('Create Account'),
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
                controller: _email,
                labelText: 'Email address',
                hintText: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.email],
                enabled: !_loading,
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
                hintText: 'Enter your password',
                obscureText: true,
                showObscureToggle: true,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                onFieldSubmitted: (_) => _login(),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your password'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _showPasswordHelp,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: _loading ? 'Signing In...' : 'Sign In',
                onPressed: _loading ? null : _login,
                isLoading: _loading,
                expand: true,
                size: AppButtonSize.large,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'or',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Continue offline',
                icon: Icons.cloud_off_outlined,
                onPressed: _loading ? null : _continueOffline,
                variant: AppButtonVariant.outline,
                expand: true,
                size: AppButtonSize.large,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your tasks stay on this device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // Google and GitHub sign-in are intentionally absent: the current
              // backend exposes only email/password authentication, so rendering
              // provider buttons would promise a flow that cannot complete.
            ],
          ),
        ),
      ),
    );
  }
}
