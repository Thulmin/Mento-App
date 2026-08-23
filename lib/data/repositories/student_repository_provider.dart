// Selects private Firestore data or isolated demo data for the current session.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/application/auth_providers.dart';
import '../../features/authentication/domain/session_state.dart';
import 'demo_student_repository.dart';
import 'firestore_student_repository.dart';
import 'student_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final session = ref.watch(sessionProvider);
  if (session.status == SessionStatus.demo) {
    // A new memory-only repository keeps demo changes away from Firebase.
    final repository = DemoStudentRepository();
    ref.onDispose(repository.dispose);
    return repository;
  }
  final uid = session.user?.uid;
  if (uid == null || uid.isEmpty) {
    throw const StudentRepositoryException(
      'Student data requires an authenticated or Demo session.',
    );
  }
  return FirestoreStudentRepository(ownerId: uid);
});

final studentDataOriginProvider = Provider<String>(
  (ref) => ref.watch(studentRepositoryProvider).dataOriginLabel,
);
