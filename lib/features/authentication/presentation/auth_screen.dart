// Presents sign-in, registration, password reset, providers, and safe demo entry.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../app/responsive/breakpoints.dart';
import '../../../app/theme/mento_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _registering = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final bootstrap = ref.watch(bootstrapProvider);
    ref.listen(authActionProvider, (previous, next) {
      if (next case AsyncError(:final error)) {
        final message =
            error is AuthFailure
                ? error.message
                : 'Sign-in could not be completed. Please try again.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: MentoPage(
          child: AutofillGroup(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _BrandHeader(registering: _registering),
                    const SizedBox(height: 28),
                    if (!bootstrap.firebaseReady) ...[
                      _SetupWarning(
                        message: ref.watch(sessionProvider).message,
                      ),
                      const SizedBox(height: 16),
                    ],
                    MentoCard(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Sign in'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Sign up'),
                                ),
                              ],
                              selected: {_registering},
                              onSelectionChanged:
                                  action.isLoading
                                      ? null
                                      : (value) => setState(() {
                                        _registering = value.first;
                                        ref
                                            .read(authActionProvider.notifier)
                                            .clearError();
                                      }),
                            ),
                            const SizedBox(height: 24),
                            if (_registering) ...[
                              MentoTextField(
                                label: 'Your name',
                                controller: _nameController,
                                prefixIcon: Icons.person_outline,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                validator:
                                    (value) =>
                                        value == null || value.trim().length < 2
                                            ? 'Enter at least 2 characters.'
                                            : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            MentoTextField(
                              label: 'Email',
                              semanticIdentifier: 'mento_auth_email',
                              controller: _emailController,
                              prefixIcon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),
                            MentoPasswordField(
                              label: 'Password',
                              semanticIdentifier: 'mento_auth_password',
                              controller: _passwordController,
                              textInputAction:
                                  _registering
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                              helper:
                                  _registering
                                      ? '8+ characters, upper/lowercase and a number'
                                      : null,
                              validator: _validatePassword,
                              onSubmitted: (_) => _submit(),
                            ),
                            if (_registering) ...[
                              const SizedBox(height: 14),
                              MentoPasswordField(
                                label: 'Confirm password',
                                controller: _confirmController,
                                textInputAction: TextInputAction.done,
                                validator:
                                    (value) =>
                                        value != _passwordController.text
                                            ? 'Passwords do not match.'
                                            : null,
                                onSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 10),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _acceptedTerms,
                                onChanged:
                                    action.isLoading
                                        ? null
                                        : (value) => setState(
                                          () => _acceptedTerms = value ?? false,
                                        ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  'I accept the Terms and Privacy Notice',
                                ),
                                subtitle:
                                    !_acceptedTerms
                                        ? const Text(
                                          'Required to create an account.',
                                        )
                                        : null,
                              ),
                            ] else ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: Semantics(
                                  identifier: 'mento_auth_forgot_password',
                                  child: TextButton(
                                    onPressed:
                                        action.isLoading
                                            ? null
                                            : _showForgotPassword,
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            MentoButton(
                              label: _registering ? 'Sign up' : 'Sign in',
                              semanticIdentifier: 'mento_auth_submit',
                              onPressed:
                                  bootstrap.firebaseReady ? _submit : null,
                              loading: action.isLoading,
                              variant: MentoButtonVariant.gradient,
                            ),
                            const SizedBox(height: 18),
                            const _OrDivider(),
                            const SizedBox(height: 18),
                            MentoButton(
                              label: 'Continue with Google',
                              semanticIdentifier: 'mento_auth_google',
                              icon: Icons.g_mobiledata,
                              iconSize: 30,
                              variant: MentoButtonVariant.outlined,
                              loading: action.isLoading,
                              onPressed:
                                  bootstrap.firebaseReady
                                      ? () => _run((repo) async {
                                        await repo.signInWithGoogle();
                                      })
                                      : null,
                            ),
                            if (AppConfig.appleAuthEnabled) ...[
                              const SizedBox(height: 12),
                              MentoButton(
                                label: 'Continue with Apple',
                                icon: Icons.apple,
                                variant: MentoButtonVariant.outlined,
                                loading: action.isLoading,
                                onPressed:
                                    bootstrap.firebaseReady
                                        ? () => _run((repo) async {
                                          await repo.signInWithApple();
                                        })
                                        : null,
                              ),
                            ],
                            if (_registering) ...[
                              const SizedBox(height: 12),
                              Text(
                                'New provider accounts complete setup and '
                                'accept the Terms and Privacy Notice during '
                                'onboarding.',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: context.mentoColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            MentoButton(
                              label: 'Explore safe demo',
                              semanticIdentifier: 'mento_auth_safe_demo',
                              icon: Icons.explore_outlined,
                              variant: MentoButtonVariant.text,
                              onPressed:
                                  () =>
                                      ref
                                          .read(sessionProvider.notifier)
                                          .enterDemo(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI suggestions support planning and are not guaranteed academic, medical, or professional advice.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.mentoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (!_registering && password.isNotEmpty) return null;
    if (password.length < 8 ||
        !RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp('[0-9]').hasMatch(password)) {
      return 'Use 8+ characters with upper/lowercase letters and a number.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_registering && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the Terms and Privacy Notice to continue.'),
        ),
      );
      return;
    }
    await _run((repository) async {
      if (_registering) {
        await repository.registerWithEmail(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          acceptedTerms: _acceptedTerms,
        );
      } else {
        await repository.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    });
  }

  Future<void> _run(Future<void> Function(AuthRepository) action) =>
      ref.read(authActionProvider.notifier).run(action);

  Future<void> _showForgotPassword() async {
    final controller = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    final requested = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset password'),
            content: Form(
              key: formKey,
              child: MentoTextField(
                label: 'Email',
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Send reset link'),
              ),
            ],
          ),
    );
    if (requested == true && mounted) {
      final success = await ref
          .read(authActionProvider.notifier)
          .run((repo) => repo.sendPasswordReset(controller.text));
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If this is an email/password account, a reset link will arrive '
              'shortly. Check Spam or Junk too. Accounts created with Google '
              'must use Continue with Google.',
            ),
          ),
        );
      }
    }
    controller.dispose();
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.registering});
  final bool registering;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: MentoColors.indigoViolet.withValues(alpha: 0.25),
              blurRadius: 30,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset('assets/images/mento_logo.png'),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        registering ? 'Start with calm clarity' : 'Welcome back',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        registering
            ? 'Build a balanced plan around your real student life.'
            : 'Pick up your plan exactly where you left it.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: context.mentoColors.textSecondary,
        ),
      ),
    ],
  );
}

class _SetupWarning extends StatelessWidget {
  const _SetupWarning({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.mentoColors.warning.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.mentoColors.warning),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.build_circle_outlined, color: context.mentoColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ??
                  'Firebase configuration is unavailable. Real sign-in is disabled; Demo mode still works.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'or',
          style: TextStyle(color: context.mentoColors.textSecondary),
        ),
      ),
      const Expanded(child: Divider()),
    ],
  );
}
