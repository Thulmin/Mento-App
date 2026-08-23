// Wraps account sign-in, linking, reauthentication, and permanent deletion.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  bool _googleInitialized = false;

  // Routing only needs sign-in/sign-out changes. Token refreshes must not
  // rebuild or re-synchronise the app while an authenticated screen is active.
  Stream<User?> get userChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error);
    }
  }

  Future<UserCredential> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) async {
    if (!acceptedTerms) {
      throw const AuthFailure('Please accept the Terms and Privacy Notice.');
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(name.trim());
      await _ensureUserProfile(
        user,
        preferredName: name.trim(),
        termsAccepted: true,
      );
      await user.sendEmailVerification();
      return credential;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error);
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '658609057035-kbdab0ahv0as71biov7469r6928kpb3f.apps.googleusercontent.com',
        );
        _googleInitialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(
          'Google did not return a valid identity token.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      // A federated identity proves ownership of that provider account, not
      // acceptance of Mento's terms. New profiles complete onboarding first.
      await _ensureUserProfile(result.user!, termsAccepted: false);
      return result;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure(
          'Google sign-in was cancelled.',
          code: 'cancelled',
        );
      }
      if (error.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthFailure(
          'Google sign-in was interrupted. Please try again.',
          code: 'interrupted',
        );
      }
      throw const AuthFailure(
        'Google sign-in is not configured for this build. Check the OAuth setup.',
        code: 'provider-configuration',
      );
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error, providerName: 'Google');
    }
  }

  Future<UserCredential> signInWithApple() async {
    if (!AppConfig.appleAuthEnabled) {
      throw const AuthFailure(
        'Apple sign-in is disabled in this build. Complete the Firebase and '
        'Apple OAuth setup, then enable MENTO_APPLE_AUTH_ENABLED.',
        code: 'provider-disabled',
      );
    }
    try {
      final provider =
          AppleAuthProvider()
            ..addScope('email')
            ..addScope('name');
      final result = await _auth.signInWithProvider(provider);
      // Apple authentication must not be treated as legal consent. A new
      // account remains onboarding-incomplete until the user explicitly
      // accepts the Terms and Privacy Notice in onboarding.
      await _ensureUserProfile(result.user!, termsAccepted: false);
      return result;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error, providerName: 'Apple');
    }
  }

  Future<UserCredential> linkGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Your session has expired.');
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '658609057035-kbdab0ahv0as71biov7469r6928kpb3f.apps.googleusercontent.com',
        );
        _googleInitialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const AuthFailure('Google sign-in did not complete.');
      }
      final result = await user.linkWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
      await _syncLinkedGooglePhoto(result.user!);
      return result;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error, providerName: 'Google');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error);
    }
  }

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Your session has expired.');
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error);
    }
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      if (_googleInitialized) GoogleSignIn.instance.signOut(),
    ]);
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('Password re-authentication is unavailable.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error);
    }
  }

  Future<void> deleteAccountAndData() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Your session has expired.');
    const collections = [
      'modules',
      'topics',
      'timetableEvents',
      'assignments',
      'examinations',
      'studyTasks',
      'studyPlans',
      'studySessions',
      'focusSessions',
      'habits',
      'habitLogs',
      'wellnessCheckIns',
      'achievements',
      'topicMastery',
      'notificationPreferences',
      'aiConversations',
      'savedLocations',
    ];
    try {
      await _deleteProfilePhoto(user.uid);
      for (final name in collections) {
        await _deleteCollectionPage(user.uid, name);
      }
      final batch =
          _firestore.batch()
            ..delete(_firestore.collection('publicProfiles').doc(user.uid))
            ..delete(_firestore.collection('users').doc(user.uid));
      await batch.commit();
      await user.delete();
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error);
    }
  }

  Future<void> _deleteProfilePhoto(String uid) async {
    try {
      await _storage.ref('users/$uid/profile/avatar').delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  Future<void> _deleteCollectionPage(String uid, String name) async {
    while (true) {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection(name)
              .limit(200)
              .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _ensureUserProfile(
    User user, {
    String? preferredName,
    bool termsAccepted = false,
  }) async {
    final reference = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) {
        final googlePhotoUrl = _linkedGooglePhotoUrl(user);
        final profile =
            (existing.data()?['profile'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final hasCustomPhoto = profile['photoSource'] == 'custom';
        transaction.update(reference, {
          if (!hasCustomPhoto && googlePhotoUrl != null)
            'profile.photoUrl': googlePhotoUrl,
          if (!hasCustomPhoto && googlePhotoUrl != null)
            'profile.photoSource': 'google',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final googlePhotoUrl = _linkedGooglePhotoUrl(user);
      transaction.set(reference, {
        'uid': user.uid,
        'profile': {
          'preferredName': preferredName ?? user.displayName ?? '',
          'email': user.email ?? '',
          'photoUrl': googlePhotoUrl ?? user.photoURL,
          'photoSource':
              googlePhotoUrl != null || user.photoURL != null ? 'google' : null,
        },
        'preferences': {
          'themeMode': 'system',
          'wellnessEnabled': true,
          'publicAchievements': false,
          'reducedMotion': false,
        },
        ...initialAuthAccountState(termsAccepted: termsAccepted),
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _syncLinkedGooglePhoto(User user) async {
    final photoUrl = _linkedGooglePhotoUrl(user);
    if (photoUrl == null) return;
    final reference = _firestore.collection('users').doc(user.uid);
    var customPhoto = false;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      final profile =
          (snapshot.data()?['profile'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      customPhoto = profile['photoSource'] == 'custom';
      if (customPhoto) return;
      transaction.update(reference, {
        'profile.photoUrl': photoUrl,
        'profile.photoSource': 'google',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (!customPhoto && user.photoURL != photoUrl) {
      await user.updatePhotoURL(photoUrl);
    }
  }

  static String? _linkedGooglePhotoUrl(User user) {
    for (final provider in user.providerData) {
      final photoUrl =
          provider.providerId == 'google.com' ? provider.photoURL : null;
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        return photoUrl.trim();
      }
    }
    return null;
  }
}

Map<String, bool> initialAuthAccountState({required bool termsAccepted}) => {
  'onboardingComplete': false,
  'termsAccepted': termsAccepted,
};

AuthFailure mapFirebaseAuthError(
  FirebaseAuthException error, {
  String? providerName,
}) {
  if (providerName != null) {
    final providerMessage = switch (error.code) {
      'operation-not-allowed' =>
        '$providerName sign-in is not enabled in the connected Firebase project.',
      'invalid-oauth-provider' || 'invalid-provider-id' =>
        '$providerName sign-in is configured incorrectly. Check the OAuth client and Firebase provider settings.',
      'unauthorized-domain' =>
        '$providerName sign-in cannot continue because its OAuth callback domain is not authorized.',
      'invalid-credential' =>
        '$providerName returned a credential that Firebase could not accept. Check the provider configuration and try again.',
      _ => null,
    };
    if (providerMessage != null) {
      return AuthFailure(providerMessage, code: error.code);
    }
  }

  final message = switch (error.code) {
    'invalid-email' ||
    'invalid-recipient-email' ||
    'missing-email' => 'Enter a valid email address.',
    'invalid-sender' || 'invalid-message-payload' =>
      'The authentication email service is not configured correctly. Please contact support.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'The email or password is incorrect.',
    'email-already-in-use' =>
      'An account already uses this email. Sign in and link the provider instead.',
    'weak-password' =>
      'Use at least 8 characters with upper/lowercase letters and a number.',
    'too-many-requests' =>
      'Too many attempts. Please wait a little before trying again.',
    'quota-exceeded' =>
      'The authentication email limit has been reached. Please try again later.',
    'network-request-failed' =>
      'You appear to be offline. Check your connection and retry.',
    'account-exists-with-different-credential' =>
      'This email uses another sign-in method. Sign in that way, then link accounts.',
    'credential-already-in-use' || 'provider-already-linked' =>
      'That sign-in method is already linked to an account.',
    'requires-recent-login' =>
      'For security, sign in again before making this change.',
    'operation-not-allowed' =>
      'This sign-in method has not been enabled by the administrator.',
    'invalid-oauth-provider' || 'invalid-provider-id' =>
      'This sign-in provider is not configured correctly.',
    'user-disabled' => 'This account has been disabled. Contact support.',
    'web-context-cancelled' || 'canceled' => 'Sign-in was cancelled.',
    _ => 'Authentication could not be completed. Please try again.',
  };
  return AuthFailure(message, code: error.code);
}
