import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('profile photo is circular, 64px, and changeable', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProfileAvatar(
              name: 'Student',
              photoUrl: 'https://example.invalid/avatar.jpg',
              busy: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    final clip = find.byKey(const Key('profile-photo-clip'));
    expect(clip, findsOneWidget);
    expect(tester.widget<ClipOval>(clip), isA<ClipOval>());
    expect(tester.getSize(clip), const Size(64, 64));
    expect(find.bySemanticsLabel('Change profile photo'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Change profile photo'));
    expect(tapped, isTrue);
  });
}
