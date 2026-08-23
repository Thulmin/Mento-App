import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/app/theme/app_theme.dart';
import 'package:mento/core/widgets/mento_controls.dart';

void main() {
  testWidgets('Mento button is semantic, tappable, and themed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: MentoTheme.light,
        home: Scaffold(
          body: MentoButton(label: 'Continue', onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(tapped, isTrue);
  });
}
