import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mento/features/profile/data/profile_photo_repository.dart';

void main() {
  group('profile photo validation', () {
    test('detects the supported image signatures', () {
      expect(
        detectProfilePhotoContentType(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
        ),
        'image/jpeg',
      );
      expect(
        detectProfilePhotoContentType(
          Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        ),
        'image/png',
      );
      expect(
        detectProfilePhotoContentType(
          Uint8List.fromList([
            0x52,
            0x49,
            0x46,
            0x46,
            0,
            0,
            0,
            0,
            0x57,
            0x45,
            0x42,
            0x50,
          ]),
        ),
        'image/webp',
      );
    });

    test('rejects empty, unsupported, and oversized files', () {
      expect(
        () => validateProfilePhoto(Uint8List(0)),
        throwsA(isA<ProfilePhotoException>()),
      );
      expect(
        () => validateProfilePhoto(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<ProfilePhotoException>()),
      );
      final oversized = Uint8List(maxProfilePhotoBytes + 1)
        ..setRange(0, 3, [0xff, 0xd8, 0xff]);
      expect(
        () => validateProfilePhoto(oversized),
        throwsA(isA<ProfilePhotoException>()),
      );
    });

    test('uses one owner-scoped fixed object path', () {
      expect(
        ProfilePhotoRepository.storagePath('student-123'),
        'users/student-123/profile/avatar',
      );
    });
  });
}
