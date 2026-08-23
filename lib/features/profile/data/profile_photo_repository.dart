// Validates, uploads, replaces, and removes the signed-in user's profile photo.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

const int maxProfilePhotoBytes = 5 * 1024 * 1024;

final class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ProfilePhotoSelection {
  const ProfilePhotoSelection({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class ProfilePhotoRepository {
  ProfilePhotoRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _picker = picker ?? ImagePicker();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  static String storagePath(String uid) => 'users/$uid/profile/avatar';

  static String? linkedGooglePhotoUrl(User user) {
    for (final provider in user.providerData) {
      final url =
          provider.providerId == 'google.com' ? provider.photoURL : null;
      if (url != null && url.trim().isNotEmpty) return url.trim();
    }
    return null;
  }

  Future<ProfilePhotoSelection?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1536,
      maxHeight: 1536,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return validateProfilePhoto(bytes);
  }

  Future<String> upload({
    required String uid,
    required ProfilePhotoSelection photo,
  }) async {
    _requireCurrentUser(uid);
    final reference = _storage.ref(storagePath(uid));
    await reference.putData(
      photo.bytes,
      SettableMetadata(
        contentType: photo.contentType,
        cacheControl: 'private,max-age=3600',
        customMetadata: {'ownerId': uid},
      ),
    );
    final downloadUrl = await reference.getDownloadURL();
    // A fixed owner-scoped object path makes replacement and deletion simple,
    // but Firebase can retain the same download token after an overwrite.
    // Persist a changing query component so image caches fetch fresh bytes.
    final separator = downloadUrl.contains('?') ? '&' : '?';
    final photoUrl =
        '$downloadUrl${separator}v=${DateTime.now().millisecondsSinceEpoch}';
    await _firestore.collection('users').doc(uid).update({
      'profile.photoUrl': photoUrl,
      'profile.photoSource': 'custom',
      'profile.customPhotoPath': storagePath(uid),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await _auth.currentUser?.updatePhotoURL(photoUrl);
    } on FirebaseAuthException {
      // Firestore is the source of truth; this Auth profile mirror is best
      // effort and is retried after the next profile edit or upload.
    }
    return photoUrl;
  }

  Future<String?> remove({required String uid}) async {
    final user = _requireCurrentUser(uid);
    final googlePhotoUrl = linkedGooglePhotoUrl(user);
    try {
      await _storage.ref(storagePath(uid)).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
    await _firestore.collection('users').doc(uid).update({
      'profile.photoUrl': googlePhotoUrl,
      'profile.photoSource': googlePhotoUrl == null ? null : 'google',
      'profile.customPhotoPath': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await user.updatePhotoURL(googlePhotoUrl);
    } on FirebaseAuthException {
      // The nested Firestore profile remains authoritative.
    }
    return googlePhotoUrl;
  }

  User _requireCurrentUser(String uid) {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) {
      throw const ProfilePhotoException(
        'Your session expired. Sign in before changing your profile photo.',
      );
    }
    return user;
  }
}

ProfilePhotoSelection validateProfilePhoto(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const ProfilePhotoException('The selected photo is empty.');
  }
  if (bytes.length > maxProfilePhotoBytes) {
    throw const ProfilePhotoException(
      'Choose a profile photo smaller than 5 MB.',
    );
  }
  final contentType = detectProfilePhotoContentType(bytes);
  if (contentType == null) {
    throw const ProfilePhotoException(
      'Choose a JPEG, PNG or WebP profile photo.',
    );
  }
  return ProfilePhotoSelection(bytes: bytes, contentType: contentType);
}

String? detectProfilePhotoContentType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}
