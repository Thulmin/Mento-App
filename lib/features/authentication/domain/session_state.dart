// Describes the small set of session states that control app navigation.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum SessionStatus {
  initializing,
  signedOut,
  emailVerificationRequired,
  onboardingRequired,
  authenticated,
  demo,
}

@immutable
class SessionState {
  const SessionState({required this.status, this.user, this.message});

  const SessionState.initializing() : this(status: SessionStatus.initializing);

  final SessionStatus status;
  final User? user;
  final String? message;

  bool get isAuthenticated =>
      status == SessionStatus.authenticated || status == SessionStatus.demo;

  String get displayName {
    if (status == SessionStatus.demo) return 'Alex';
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;
    return user?.email?.split('@').first ?? 'Student';
  }
}
