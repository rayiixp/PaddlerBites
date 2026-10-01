import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Stores photos as documents in the `images` collection. Used when the
/// project has no Firebase Storage bucket (Storage requires the Blaze plan).
///
/// Items keep only a reference (`firestore-image:<docId>`) in their
/// `imageUrl`, so menu lists stay small and each photo is fetched once, when
/// it is actually shown.
class FirestoreImageStore {
  static const String scheme = 'firestore-image:';

  /// Firestore documents are capped at 1 MiB; leave room for the other fields.
  static const int maxBytes = 900 * 1024;

  static final CollectionReference<Map<String, dynamic>> _images = FirebaseFirestore.instance.collection('images');
  static final Map<String, Future<Uint8List?>> _cache = {};

  static bool isReference(String? url) => url != null && url.startsWith(scheme);

  /// Saves [bytes] and returns the reference to store in `imageUrl`.
  static Future<String> save(Uint8List bytes, {required String contentType, required String ownerId, required String label}) async {
    if (bytes.length > maxBytes) {
      throw StateError('This photo is too large (${(bytes.length / 1024).round()} KB). Please choose a smaller photo or crop it.');
    }
    final doc = _images.doc();
    await doc.set({
      'data': Blob(bytes),
      'contentType': contentType,
      'size': bytes.length,
      'ownerId': ownerId,
      'label': label,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final reference = '$scheme${doc.id}';
    _cache[reference] = Future.value(bytes);
    return reference;
  }

  /// Image bytes for a reference; fetched once per app session.
  static Future<Uint8List?> load(String reference) {
    return _cache.putIfAbsent(reference, () async {
      try {
        final doc = await _images.doc(reference.substring(scheme.length)).get();
        final data = doc.data()?['data'];
        return data is Blob ? data.bytes : null;
      } catch (_) {
        _cache.remove(reference); // retry next time instead of caching the failure
        rethrow;
      }
    });
  }

  static Future<void> delete(String reference) async {
    _cache.remove(reference);
    await _images.doc(reference.substring(scheme.length)).delete();
  }
}
