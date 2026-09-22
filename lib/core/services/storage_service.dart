import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads an announcement thumbnail to Firebase Storage and returns the
/// download URL.
Future<String> uploadAnnouncementThumbnail(XFile file) async {
  final uid = _requireAuthUid();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filename = file.name.isNotEmpty ? file.name : '$timestamp.jpg';
  final bytes = await file.readAsBytes();
  final ref = FirebaseStorage.instance
      .ref()
      .child('announcements/thumbnails/$uid/${timestamp}_$filename');

  final uploadTask = await ref.putData(
    bytes,
    SettableMetadata(
      contentType: _contentTypeFor(filename, bytes),
    ),
  );
  return await uploadTask.ref.getDownloadURL();
}

/// Uploads an announcement banner image and returns the download URL.
Future<String> uploadAnnouncementBannerImage(XFile file) async {
  final uid = _requireAuthUid();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filename = file.name.isNotEmpty ? file.name : '$timestamp.jpg';
  final bytes = await file.readAsBytes();
  final ref = FirebaseStorage.instance
      .ref()
      .child('announcements/banners/$uid/${timestamp}_$filename');

  final uploadTask = await ref.putData(
    bytes,
    SettableMetadata(
      contentType: _contentTypeFor(filename, bytes),
    ),
  );
  return await uploadTask.ref.getDownloadURL();
}

/// Uploads multiple announcement banner images and returns download URLs.
Future<List<String>> uploadAnnouncementBannerImages(List<XFile> files) async {
  final urls = <String>[];
  for (final file in files) {
    urls.add(await uploadAnnouncementBannerImage(file));
  }
  return urls;
}

/// Uploads a director/producer profile image and returns the download URL.
Future<String> uploadDirectorProfileImage(XFile file, String uid) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filename = file.name.isNotEmpty ? file.name : '$timestamp.jpg';
  final bytes = await file.readAsBytes();
  final ref = FirebaseStorage.instance
      .ref()
      .child('directors/profile/$uid/${timestamp}_$filename');

  final uploadTask = await ref.putData(
    bytes,
    SettableMetadata(
      contentType: _contentTypeFor(filename, bytes),
    ),
  );
  return await uploadTask.ref.getDownloadURL();
}

/// Uploads an actor profile image and returns the download URL.
Future<String> uploadActorProfileImage(XFile file, String uid) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filename = file.name.isNotEmpty ? file.name : '$timestamp.jpg';
  final bytes = await file.readAsBytes();
  final ref = FirebaseStorage.instance
      .ref()
      .child('actors/profile/$uid/${timestamp}_$filename');

  final uploadTask = await ref.putData(
    bytes,
    SettableMetadata(
      contentType: _contentTypeFor(filename, bytes),
    ),
  );
  return await uploadTask.ref.getDownloadURL();
}

/// Uploads an actor gallery image and returns the download URL.
Future<String> uploadActorGalleryImage(XFile file, String uid) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filename = file.name.isNotEmpty ? file.name : '$timestamp.jpg';
  final bytes = await file.readAsBytes();
  final ref = FirebaseStorage.instance
      .ref()
      .child('actors/gallery/$uid/${timestamp}_$filename');

  final uploadTask = await ref.putData(
    bytes,
    SettableMetadata(
      contentType: _contentTypeFor(filename, bytes),
    ),
  );
  return await uploadTask.ref.getDownloadURL();
}

String _contentTypeFor(String filename, Uint8List bytes) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

String _requireAuthUid() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) {
    throw FirebaseException(
      plugin: 'firebase_storage',
      code: 'unauthenticated',
      message: 'You must be logged in to upload files.',
    );
  }
  return uid;
}
