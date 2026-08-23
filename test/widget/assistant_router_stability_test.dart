import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/app/router/app_router.dart';
import 'package:mento/app/theme/app_theme.dart';
import 'package:mento/app/theme/theme_controller.dart';
import 'package:mento/features/authentication/application/auth_providers.dart';
import 'package:mento/features/authentication/domain/session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'authenticated session refresh keeps the assistant route and router',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionProvider.overrideWith(_DemoSessionController.new),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      router.go('/assistant');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: MentoTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mento assistant'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/assistant');

      final sessionController =
          container.read(sessionProvider.notifier) as _DemoSessionController;
      sessionController.repeatAuthenticatedState();
      await tester.pumpAndSettle();

      expect(identical(router, container.read(appRouterProvider)), isTrue);
      expect(router.routeInformationProvider.value.uri.path, '/assistant');
      expect(find.text('Mento assistant'), findsOneWidget);
    },
  );
}

final class _DemoSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(status: SessionStatus.demo);

  void repeatAuthenticatedState() {
    state = const SessionState(status: SessionStatus.demo);
  }
}
