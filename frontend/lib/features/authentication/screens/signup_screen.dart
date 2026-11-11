import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_service.dart';
import '../data/session_store.dart';
import '../widgets/auth_shell.dart';

/// Password strength levels, from weakest to strongest.
enum _PasswordStrength { veryWeak, weak, moderate, strong, veryStrong }

/// Evaluates password strength using length, character variety and common
/// password patterns — mirroring the backend rules so the client can give
/// immediate feedback without a round trip.
class _PasswordStrengthChecker {
  static const int minLength = 12;

  static const Set<String> _commonPasswords = <String>{
    'password',
    'password1',
    'password123',
    'password123!',
    '123456',
    '12345678',
    '123456789',
    'qwerty',
    'abc123',
    'admin',
    'letmein',
    'welcome',
    'welcome123!',
    'monkey',
    'dragon',
    'master',
    'login',
    'pass',
    'test',
    'guest',
  };

  /// Returns [0..5] where 0 = too short to evaluate and 5 = very strong.
  static _PasswordStrength evaluate(String password) {
    if (password.length < minLength) {
      return _PasswordStrength.veryWeak;
    }

    final bool hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final bool hasLower = RegExp(r'[a-z]').hasMatch(password);
    final bool hasDigit = RegExp(r'\d').hasMatch(password);
    final bool hasSpecial = RegExp(r'[^A-Za-z\d]').hasMatch(password);
    final int variety = [
      hasUpper,
      hasLower,
      hasDigit,
      hasSpecial,
    ].where((b) => b).length;

    final bool isCommon = _commonPasswords.contains(password.toLowerCase());

    if (isCommon || variety < 3) {
      return _PasswordStrength.weak;
    }
    if (variety == 3) {
      return _PasswordStrength.moderate;
    }
    if (variety == 4 && password.length >= 16) {
      return _PasswordStrength.veryStrong;
    }
    return _PasswordStrength.strong;
  }

  static Color color(_PasswordStrength strength) {
    return switch (strength) {
      _PasswordStrength.veryWeak => AppColors.errorRed,
      _PasswordStrength.weak => AppColors.warningAmber,
      _PasswordStrength.moderate => const Color(0xFFD97706),
      _PasswordStrength.strong => AppColors.successGreen,
      _PasswordStrength.veryStrong => const Color(0xFF15803D),
    };
  }

  static String label(_PasswordStrength strength) {
    return switch (strength) {
      _PasswordStrength.veryWeak => 'Too short',
      _PasswordStrength.weak => 'Weak',
      _PasswordStrength.moderate => 'Moderate',
      _PasswordStrength.strong => 'Strong',
      _PasswordStrength.veryStrong => 'Very strong',
    };
  }
}

/// Password requirements that are checked in real time.
class _PasswordRequirement {
  const _PasswordRequirement({required this.label, required this.check});

  final String label;
  final bool Function(String) check;
}

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
  final TextEditingController _confirmPassword = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  late final AuthService _auth = widget.auth ?? AuthService();
  bool _loading = false;
  final bool _obscurePassword = true;
  final bool _obscureConfirm = true;
  _PasswordStrength _strength = _PasswordStrength.veryWeak;

  static final List<_PasswordRequirement> _requirements =
      <_PasswordRequirement>[
        _PasswordRequirement(
          label: 'At least 12 characters',
          check: (pw) => pw.length >= 12,
        ),
        _PasswordRequirement(
          label: 'At least one uppercase letter',
          check: (pw) => RegExp(r'[A-Z]').hasMatch(pw),
        ),
        _PasswordRequirement(
          label: 'At least one lowercase letter',
          check: (pw) => RegExp(r'[a-z]').hasMatch(pw),
        ),
        _PasswordRequirement(
          label: 'At least one number',
          check: (pw) => RegExp(r'\d').hasMatch(pw),
        ),
        _PasswordRequirement(
          label: 'At least one special character',
          check: (pw) => RegExp(r'[^A-Za-z\d]').hasMatch(pw),
        ),
        _PasswordRequirement(
          label: 'Not a commonly used password',
          check: (pw) => !_PasswordStrengthChecker._commonPasswords.contains(
            pw.toLowerCase(),
          ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final strength = _PasswordStrengthChecker.evaluate(_password.text);
    if (_strength != strength) {
      setState(() => _strength = strength);
    }
  }

  bool get _passwordsMatch {
    final pw = _password.text;
    final confirm = _confirmPassword.text;
    return confirm.isNotEmpty && pw == confirm;
  }

  bool get _canSubmit {
    return !_loading &&
        _strength.index >= _PasswordStrength.strong.index &&
        _passwordsMatch &&
        _email.text.trim().isNotEmpty &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
  }

  Future<void> _signup() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    if (!_canSubmit) return;

    setState(() => _loading = true);
    try {
      final session = await _auth.signup(
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
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

  Widget _buildStrengthBar() {
    final strength = _strength;
    final color = _PasswordStrengthChecker.color(strength);
    final label = _PasswordStrengthChecker.label(strength);

    final int filled = strength.index.clamp(0, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List.generate(5, (index) {
            final active = index < filled;
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: active ? color : AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementRow(_PasswordRequirement req) {
    final bool met = req.check(_password.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: met
                ? AppColors.successGreen
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              req.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: met
                    ? AppColors.successGreen
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: met ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showRequirements = _password.text.isNotEmpty && !_loading;

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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Name field
                AppTextField(
                  controller: _name,
                  labelText: 'Full name',
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

                // Email field
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
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Password field
                AppTextField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  obscureText: _obscurePassword,
                  showObscureToggle: true,
                  enabled: !_loading,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a password';
                    }
                    final strength = _PasswordStrengthChecker.evaluate(value);
                    if (strength.index < _PasswordStrength.strong.index) {
                      return 'Please choose a stronger password';
                    }
                    return null;
                  },
                ),
                if (showRequirements) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _buildStrengthBar(),
                  const SizedBox(height: AppSpacing.sm),
                  ..._requirements.map(_buildRequirementRow),
                ],
                const SizedBox(height: AppSpacing.lg),

                // Confirm password field
                AppTextField(
                  controller: _confirmPassword,
                  focusNode: _confirmFocus,
                  labelText: 'Confirm password',
                  hintText: 'Enter your password again',
                  obscureText: _obscureConfirm,
                  showObscureToggle: true,
                  enabled: !_loading,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signup(),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (!_passwordsMatch) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (!_passwordsMatch &&
                    _confirmPassword.text.isNotEmpty &&
                    !_loading)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    child: Text(
                      'Passwords do not match',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (_passwordsMatch &&
                    _confirmPassword.text.isNotEmpty &&
                    !_loading)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppColors.successGreen,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Passwords match',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.successGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),

                // Create Account button
                AppButton(
                  label: _loading ? 'Creating Account...' : 'Create Account',
                  onPressed: _canSubmit ? _signup : null,
                  isLoading: _loading,
                  expand: true,
                  size: AppButtonSize.large,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
