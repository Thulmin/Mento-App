// Converts Firebase authentication changes into Mento's session state.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../data/auth_repository.dart';
import '../domain/session_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final bootstrap = ref.watch(bootstrapProvider);
  if (!bootstrap.firebaseReady) {
    throw const AuthFailure(
      'Firebase is unavailable in this build. Configure it or use Demo mode.',
      code: 'firebase-unavailable',
    );
  }
  return AuthRepository();
});

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  StreamSubscription<User?>? _subscription;
  int _syncGeneration = 0;

  @override
  SessionState build() {
    final bootstrap = ref.watch(bootstrapProvider);
    ref.onDispose(() => _subscription?.cancel());
    if (!bootstrap.firebaseReady) {
      return const SessionState(
        status: SessionStatus.signedOut,
        message:
            'Firebase could not start. You can retry after checking setup or explore Demo mode.',
      );
    }

    final repository = ref.watch(authRepositoryProvider);
    _subscription = repository.userChanges.listen(
      _synchroniseUser,
      onError: (_) {
        state = const SessionState(
          status: SessionStatus.signedOut,
          message: 'Your session could not be restored. Please sign in again.',
        );
      },
    );
    Future<void>.microtask(() => _synchroniseUser(repository.currentUser));
    return const SessionState.initializing();
  }

  Future<void> _synchroniseUser(User? user) async {
    final generation = ++_syncGeneration;
    if (user == null) {
      state = const SessionState(status: SessionStatus.signedOut);
      return;
    }
    if (!user.emailVerified &&
        user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
      state = SessionState(
        status: SessionStatus.emailVerificationRequired,
        user: user,
      );
      return;
    }

    if (state.status != SessionStatus.authenticated &&
        state.status != SessionStatus.onboardingRequired) {
      state = SessionState(status: SessionStatus.initializing, user: user);
    }
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (generation != _syncGeneration) return;
      final onboardingComplete = snapshot.data()?['onboardingComplete'] == true;
      state = SessionState(
        status:
            onboardingComplete
                ? SessionStatus.authenticated
                : SessionStatus.onboardingRequired,
        user: user,
      );
    } catch (_) {
      if (generation != _syncGeneration) return;
      state = SessionState(
        status: SessionStatus.onboardingRequired,
        user: user,
        message: 'Profile setup will sync when your connection returns.',
      );
    }
  }

  void enterDemo() {
    _subscription?.cancel();
    state = const SessionState(status: SessionStatus.demo);
  }

  Future<void> refresh() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.reloadUser();
    await _synchroniseUser(repository.currentUser);
  }

  Future<void> onboardingCompleted() async {
    final user = state.user;
    if (user == null) return;
    state = SessionState(status: SessionStatus.authenticated, user: user);
  }

  Future<void> exitSession() async {
    if (state.status == SessionStatus.demo) {
      ref.invalidateSelf();
      return;
    }
    await ref.read(authRepositoryProvider).signOut();
  }
}

final authActionProvider =
    NotifierProvider<AuthActionController, AsyncValue<void>>(
      AuthActionController.new,
    );

class AuthActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> run(
    Future<void> Function(AuthRepository repository) action,
  ) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action(ref.read(authRepositoryProvider));
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  void clearError() => state = const AsyncData(null);
}
