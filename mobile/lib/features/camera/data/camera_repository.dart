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
    required String groupId,
    required String date, // "YYYY-MM-DD"
    required int slotNumber,
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
    required String groupId,
    required String date,
    required int slotNumber,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('uploadPost: no authenticated user');
    }

    // storage.rules caps uploads at 8MB server-side; CaptureController
    // already compresses before this point (that's what actually keeps
    // Storage egress cost down day to day — see its capture() method).
    // This is just a backstop so an oversized upload fails fast with a
    // clear message instead of a generic permission-denied from the rule.
    if (photoBytes.lengthInBytes > 8 * 1024 * 1024) {
      throw StateError('uploadPost: photo exceeds the 8MB limit');
    }

    final postRef = _firestore.collection('posts').doc();
    // Path includes groupId (not just uid) so storage.rules can check
    // group membership without needing custom object metadata — see that
    // file's isGroupMember().
    final storageRef = _storage.ref('posts/$groupId/$uid/${postRef.id}.jpg');

    await storageRef.putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'));
    final photoUrl = await storageRef.getDownloadURL();

    // Matches Post in packages/shared-types/src/index.ts field-for-field
    // (camelCase) — see docs/DATA_MODEL.md and the firestore.rules note
    // about why that consistency matters.
    await postRef.set({
      'groupId': groupId,
      'userId': uid,
      'date': date,
      'slotNumber': slotNumber,
      'photoUrl': photoUrl,
      'postedAt': FieldValue.serverTimestamp(),
    });

    return photoUrl;
  }
}
