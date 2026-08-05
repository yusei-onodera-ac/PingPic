import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Persists an already-captured photo (capture itself is owned by
/// CaptureController, which wraps the `camera` package directly — see
/// application/camera_controller.dart). This repository is decoupled from
/// the `camera` package entirely: it only deals in raw bytes, which keeps
/// it trivially testable and avoids any risk of this file ever importing
/// something named `CameraController` (see the naming-collision note in
/// camera_controller.dart).
abstract class CameraRepository {
  Future<String> uploadPost({
    required Uint8List photoBytes,
    required String date, // "YYYY-MM-DD"
    required int slotNumber,
    required String promptText,
    required bool isPublic,
    required String caption,
  });
}

class CameraRepositoryImpl implements CameraRepository {
  CameraRepositoryImpl({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<String> uploadPost({
    required Uint8List photoBytes,
    required String date,
    required int slotNumber,
    required String promptText,
    required bool isPublic,
    required String caption,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('uploadPost: no authenticated user');
    }
    final uid = user.uid;

    // storage.rules caps uploads at 8MB server-side; CaptureController
    // already compresses before this point (that's what actually keeps
    // Storage egress cost down day to day — see its capture() method).
    // This is just a backstop so an oversized upload fails fast with a
    // clear message instead of a generic permission-denied from the rule.
    if (photoBytes.lengthInBytes > 8 * 1024 * 1024) {
      throw StateError('uploadPost: photo exceeds the 8MB limit');
    }

    final postRef = _firestore.collection('posts').doc();
    final storageRef = _storage.ref('posts/$uid/${postRef.id}.jpg');

    await storageRef.putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'));
    final photoUrl = await storageRef.getDownloadURL();

    // Matches Post in packages/shared-types/src/index.ts field-for-field
    // (camelCase) — see docs/DATA_MODEL.md and the firestore.rules note
    // about why that consistency matters. likeCount MUST start at 0 —
    // firestore.rules' posts.create check enforces that too, since it's
    // the one field non-admins never write directly after creation (see
    // functions/src/triggers/likes.ts).
    await postRef.set({
      'userId': uid,
      'authorDisplayName': user.displayName ?? user.email ?? '匿名ユーザー',
      'date': date,
      'slotNumber': slotNumber,
      'photoUrl': photoUrl,
      'postedAt': FieldValue.serverTimestamp(),
      'promptText': promptText,
      'isPublic': isPublic,
      'caption': caption,
      'likeCount': 0,
    });

    return photoUrl;
  }
}
