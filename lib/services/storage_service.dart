import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'firestore_image_store.dart';

class StorageService {
  static final ImagePicker _picker = ImagePicker();

  /// Set once Firebase Storage turns out to have no bucket, so later uploads
  /// go straight to the Firestore fallback.
  static bool _storageUnavailable = false;

  /// Storage reports a missing bucket (HTTP 404) with these codes.
  static const _missingBucketCodes = {'object-not-found', 'bucket-not-found', 'project-not-found'};

  /// Opens the gallery. Photos are downscaled and compressed so they stay
  /// small enough for the Firestore fallback (well under 1 MB).
  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
  }

  /// Uploads [file] and returns (imageUrl, storagePath).
  ///
  /// Uses Firebase Storage when the project has a bucket; otherwise saves the
  /// photo in Firestore and returns a `firestore-image:` reference that
  /// [AppNetworkImage] knows how to display.
  static Future<(String, String)> upload(XFile file, {required String folder, required String name}) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('The selected image is empty. Please choose another photo.');

    final ext = _extension(file.name);
    final contentType = file.mimeType ?? (ext == 'png' ? 'image/png' : 'image/jpeg');

    if (!_storageUnavailable) {
      try {
        final path = '$folder/$name.$ext';
        final snapshot = await FirebaseStorage.instance.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
        if (snapshot.state != TaskState.success) {
          throw StateError('The image upload did not finish. Please try again.');
        }
        // URL is requested only after the upload has completed.
        return (await snapshot.ref.getDownloadURL(), path);
      } on FirebaseException catch (e) {
        if (!_missingBucketCodes.contains(e.code)) rethrow;
        _storageUnavailable = true;
      }
    }

    final reference = await FirestoreImageStore.save(
      bytes,
      contentType: contentType,
      ownerId: FirebaseAuth.instance.currentUser?.uid ?? '',
      label: '$folder/$name',
    );
    return (reference, reference);
  }

  /// Best-effort delete of a replaced or removed image.
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      if (FirestoreImageStore.isReference(path)) {
        await FirestoreImageStore.delete(path);
      } else {
        await FirebaseStorage.instance.ref(path).delete();
      }
    } on FirebaseException {
      // Already gone or not ours to delete; nothing else references it.
    }
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
    return const ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
  }
}
