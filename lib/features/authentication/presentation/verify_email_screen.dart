// Guides a newly registered user through email verification and refresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final action = ref.watch(authActionProvider);
    ref.listen(authActionProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AuthFailure ? error.message : 'Please try again.',
            ),
          ),
        );
      }
    });
    return Scaffold(
      body: SafeArea(
        child: MentoPage(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: MentoCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Verify your email',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We sent a verification link to ${session.user?.email ?? 'your email'}. Open it, then return here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    MentoButton(
                      label: 'I have verified my email',
                      loading: action.isLoading,
                      onPressed:
                          () => ref.read(authActionProvider.notifier).run((
                            repo,
                          ) async {
                            await repo.reloadUser();
                            await ref.read(sessionProvider.notifier).refresh();
                          }),
                    ),
                    const SizedBox(height: 8),
                    MentoButton(
                      label: 'Resend email',
                      variant: MentoButtonVariant.text,
                      loading: action.isLoading,
                      onPressed:
                          () => ref
                              .read(authActionProvider.notifier)
                              .run((repo) => repo.resendVerification()),
                    ),
                    MentoButton(
                      label: 'Use another account',
                      variant: MentoButtonVariant.text,
                      onPressed:
                          () =>
                              ref.read(sessionProvider.notifier).exitSession(),
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
}
