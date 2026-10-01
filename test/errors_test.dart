import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paddlerbites/core/errors.dart';

void main() {
  test('missing Storage bucket (reported as object-not-found) gets an actionable message', () {
    final error = FirebaseException(plugin: 'firebase_storage', code: 'object-not-found', message: 'No object exists at the desired reference.');
    expect(friendlyError(error), contains('Firebase Storage'));
  });

  test('Firestore offline and permission errors are readable', () {
    expect(friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), contains('offline'));
    expect(friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')), contains('permission'));
  });

  test('app exceptions keep their own message', () {
    expect(friendlyError(StateError('The image upload did not finish.')), 'The image upload did not finish.');
  });
}
