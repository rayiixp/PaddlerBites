import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

/// Shortcuts to the signed-in user's id and Firestore document.
class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  static DocumentReference<Map<String, dynamic>> get currentUserRef => _db.collection('users').doc(uid);

  static Future<void> signOut() => AuthService.signOut();
}
