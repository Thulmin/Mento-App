import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/app/theme/app_theme.dart';
import 'package:mento/data/repositories/repositories.dart';
import 'package:mento/features/focus/presentation/focus_screen.dart';

void main() {
  late DemoStudentRepository repository;

  setUp(() {
    repository = DemoStudentRepository(referenceDate: DateTime(2026, 7, 17));
  });

  tearDown(() => repository.dispose());

  testWidgets(
    'compact focus controls handle long modules and enlarged text without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: MentoTheme.dark,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.3),
              ),
              child: const FocusScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('25m'), findsOneWidget);
      expect(find.text('50m'), findsOneWidget);
      expect(find.text('90m'), findsOneWidget);

      final dropdown = tester.widget<DropdownButton<String?>>(
        find.descendant(
          of: find.byKey(const Key('focus-module-dropdown')),
          matching: find.byWidgetPredicate(
            (widget) => widget is DropdownButton<String?>,
          ),
        ),
      );
      expect(dropdown.isExpanded, isTrue);

      await tester.tap(find.byKey(const Key('focus-module-dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('Mobile Application Engineering'), findsWidgets);
      expect(find.text('Applied Artificial Intelligence'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
