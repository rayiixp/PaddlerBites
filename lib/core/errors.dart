import 'package:firebase_core/firebase_core.dart';

/// Turns Firebase and app exceptions into messages a student can act on.
String friendlyError(Object error) {
  if (error is FirebaseException) {
    if (error.plugin == 'firebase_storage') {
      switch (error.code) {
        // Storage reports a missing bucket (HTTP 404) as object-not-found.
        case 'object-not-found':
        case 'bucket-not-found':
        case 'project-not-found':
          return 'Image storage is not set up for PaddlerBites yet. Ask the admin to enable Firebase Storage.';
        case 'unauthorized':
        case 'unauthenticated':
          return 'You don\'t have permission to upload this image.';
        case 'retry-limit-exceeded':
          return 'The upload timed out. Check your connection and try again.';
        case 'quota-exceeded':
          return 'Image storage is full. Please contact the admin.';
        case 'canceled':
          return 'The upload was cancelled.';
      }
    }
    switch (error.code) {
      case 'permission-denied':
        return 'You don\'t have permission to do that.';
      case 'unavailable':
        return 'You appear to be offline. Try again once you\'re connected.';
      case 'deadline-exceeded':
        return 'The request timed out. Please try again.';
      case 'not-found':
        return 'This record no longer exists.';
    }
    return error.message ?? 'Something went wrong (${error.code}).';
  }
  // App exceptions (OrderException, AuthException, StateError…) carry readable messages.
  final text = error.toString();
  return text.startsWith('Bad state: ') ? text.substring(11) : text;
}
