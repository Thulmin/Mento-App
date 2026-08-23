import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/core/config/app_config.dart';
import 'package:mento/features/authentication/data/auth_repository.dart';
import 'package:mento/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  group('External feature configuration', () {
    test('maps are enabled while Apple authentication remains opt-in', () {
      expect(AppConfig.appleAuthEnabled, isFalse);
      expect(AppConfig.mapsEnabled, isTrue);
    });
  });

  group('Federated account setup', () {
    test('new OAuth profiles do not imply onboarding or legal consent', () {
      expect(initialAuthAccountState(termsAccepted: false), {
        'onboardingComplete': false,
        'termsAccepted': false,
      });
    });

    test('email consent still does not skip onboarding', () {
      expect(initialAuthAccountState(termsAccepted: true), {
        'onboardingComplete': false,
        'termsAccepted': true,
      });
    });

    test('onboarding requires explicit Terms and Privacy acceptance', () {
      expect(
        validateOnboardingConsent(acceptedTerms: false),
        contains('Terms and Privacy Notice'),
      );
      expect(validateOnboardingConsent(acceptedTerms: true), isNull);
    });
  });

  group('Provider-specific authentication errors', () {
    test('Apple provider setup failures identify Apple and Firebase', () {
      final failure = mapFirebaseAuthError(
        FirebaseAuthException(code: 'operation-not-allowed'),
        providerName: 'Apple',
      );

      expect(failure.code, 'operation-not-allowed');
      expect(failure.message, contains('Apple sign-in'));
      expect(failure.message, contains('Firebase'));
    });

    test('OAuth invalid credentials are not described as bad passwords', () {
      final failure = mapFirebaseAuthError(
        FirebaseAuthException(code: 'invalid-credential'),
        providerName: 'Apple',
      );

      expect(failure.message, contains('Apple'));
      expect(failure.message, isNot(contains('email or password')));
    });
  });

  group('Authentication email errors', () {
    test('invalid sender configuration is reported clearly', () {
      final failure = mapFirebaseAuthError(
        FirebaseAuthException(code: 'invalid-sender'),
      );

      expect(failure.code, 'invalid-sender');
      expect(failure.message, contains('email service'));
      expect(failure.message, contains('contact support'));
    });

    test('email quota errors ask the user to retry later', () {
      final failure = mapFirebaseAuthError(
        FirebaseAuthException(code: 'quota-exceeded'),
      );

      expect(failure.code, 'quota-exceeded');
      expect(failure.message, contains('email limit'));
      expect(failure.message, contains('try again later'));
    });
  });
}
