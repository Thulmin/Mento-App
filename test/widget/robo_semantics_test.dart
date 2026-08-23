import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/core/widgets/mento_controls.dart';

void main() {
  testWidgets('Robo controls expose stable Android semantics identifiers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const MentoTextField(
                label: 'Email',
                semanticIdentifier: 'mento_auth_email',
              ),
              const MentoScreenTitle(
                title: 'Study locations',
                semanticIdentifier: 'mento_screen_study_locations',
              ),
              MentoButton(
                label: 'Sign in',
                semanticIdentifier: 'mento_auth_submit',
                onPressed: () {},
              ),
              MentoIconButton(
                icon: Icons.send,
                tooltip: 'Send',
                semanticIdentifier: 'mento_ai_send',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('mento_auth_email'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('mento_screen_study_locations'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('mento_auth_submit'), findsOneWidget);
    expect(find.bySemanticsIdentifier('mento_ai_send'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsIdentifier('mento_auth_email'))
          .getSemanticsData()
          .hasFlag(ui.SemanticsFlag.isTextField),
      isTrue,
    );
    expect(
      tester
          .getSemantics(
            find.bySemanticsIdentifier('mento_screen_study_locations'),
          )
          .getSemanticsData()
          .hasFlag(ui.SemanticsFlag.isHeader),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsIdentifier('mento_auth_submit'))
          .getSemanticsData()
          .hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsIdentifier('mento_ai_send'))
          .getSemanticsData()
          .hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
  });
}
