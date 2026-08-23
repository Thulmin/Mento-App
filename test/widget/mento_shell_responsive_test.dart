import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mento/app/router/mento_shell.dart';
import 'package:mento/app/theme/app_theme.dart';
import 'package:mento/core/services/connectivity_service.dart';

void main() {
  testWidgets(
    'short landscape rail scrolls to Progress and Profile without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(891, 411));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/focus',
        routes: [
          StatefulShellRoute.indexedStack(
            builder:
                (context, state, navigationShell) =>
                    MentoShell(navigationShell: navigationShell),
            branches: [
              _branch('/today', 'Today branch'),
              _branch('/plan', 'Plan branch'),
              _branch('/focus', 'Focus branch'),
              _branch('/progress', 'Progress branch'),
              _branch('/profile', 'Profile branch'),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp.router(
            theme: MentoTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigationScroll = find.byKey(const Key('mento-navigation-scroll'));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(navigationScroll, findsOneWidget);
      expect(tester.takeException(), isNull);

      final scrollable = find.descendant(
        of: navigationScroll,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Profile'),
        100,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(find.text('Progress branch'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile branch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

StatefulShellBranch _branch(String path, String label) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => Scaffold(body: Center(child: Text(label))),
      ),
    ],
  );
}
