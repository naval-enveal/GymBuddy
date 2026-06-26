import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/auth/auth_form_controller.dart';

/// The login / signup form, wired to the M1 `/auth/*` endpoints.
///
/// One screen serves both modes (toggled in place) so the user can switch
/// between logging in and creating an account without losing context. Field
/// validation runs client-side; the network exchange and its error state are
/// owned by [authFormControllerProvider]. On success the controller flips the
/// session to authenticated — the `AuthGate` then shows the shell — and this
/// screen pops itself off the signed-out flow.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({this.initialMode = AuthFormMode.register, super.key});

  /// Which mode the screen opens in. "Get started" enters [AuthFormMode.register];
  /// "I already have an account" enters [AuthFormMode.signIn].
  final AuthFormMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  late AuthFormMode _mode = widget.initialMode;

  // Mirrors the server: register requires an 8+ char password; login only
  // requires a non-empty one (strength is enforced at registration).
  static const int _minPasswordLength = 8;
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _isRegister => _mode == AuthFormMode.register;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _isRegister ? AuthFormMode.signIn : AuthFormMode.register;
    });
    // A pending error from the previous mode no longer applies.
    ref.read(authFormControllerProvider.notifier).clearError();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password';
    if (_isRegister && password.length < _minPasswordLength) {
      return 'Use at least $_minPasswordLength characters';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final displayName = _displayNameController.text.trim();
    final succeeded =
        await ref.read(authFormControllerProvider.notifier).submit(
              mode: _mode,
              email: _emailController.text.trim(),
              password: _passwordController.text,
              displayName: _isRegister && displayName.isNotEmpty
                  ? displayName
                  : null,
            );

    // On success the gate has swapped the root to the shell; drop this screen
    // off the signed-out flow so it isn't left covering it.
    if (succeeded && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(authFormControllerProvider);
    final submitting = formState.submitting;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegister ? 'Create account' : 'Log in'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isRegister ? 'Create your account' : 'Welcome back',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _isRegister
                      ? 'Set up GymBuddy to start training.'
                      : 'Log in to pick up where you left off.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  key: const Key('auth-email-field'),
                  controller: _emailController,
                  enabled: !submitting,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _validateEmail,
                ),
                if (_isRegister) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('auth-name-field'),
                    controller: _displayNameController,
                    enabled: !submitting,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      counterText: '',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('auth-password-field'),
                  controller: _passwordController,
                  enabled: !submitting,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (formState.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    formState.errorMessage!,
                    key: const Key('auth-error'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  key: const Key('auth-submit'),
                  label: _isRegister ? 'Create account' : 'Log in',
                  isLoading: submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  key: const Key('auth-toggle'),
                  onPressed: submitting ? null : _toggleMode,
                  child: Text(
                    _isRegister
                        ? 'Already have an account? Log in'
                        : 'New here? Create an account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
