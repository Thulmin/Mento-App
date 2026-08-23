import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/core/widgets/mento_controls.dart';

void main() {
  testWidgets('MentoButton applies a custom icon size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MentoButton(
            label: 'Continue with Google',
            icon: Icons.g_mobiledata,
            iconSize: 30,
            onPressed: () {},
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.g_mobiledata));
    expect(icon.size, 30);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
