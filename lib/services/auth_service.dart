import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';

/// Thrown for sign-in problems the user can fix; [message] is shown as-is.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Sign-in, institutional-domain enforcement, profile bootstrap and role
/// switching for the mobile app.
class AuthService {
  static const String domain = 'csucc.edu.ph';
  static const String institutionalDomain = '@$domain';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  // hostedDomain limits Google's account chooser to csucc.edu.ph accounts.
  static final GoogleSignIn _google = GoogleSignIn(hostedDomain: domain);

  static bool isInstitutional(String? email) => (email ?? '').trim().toLowerCase().endsWith(institutionalDomain);

  static DocumentReference<Map<String, dynamic>> _userRef(String uid) => _db.collection('users').doc(uid);

  // ------------------------------------------------------------- Sign in

  /// Returns false if the user closed the Google account picker.
  static Future<bool> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return false;
    if (!isInstitutional(account.email)) {
      await _google.disconnect();
      throw AuthException('Access denied: please use your official $institutionalDomain email address.');
    }
    final auth = await account.authentication;
    final result = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(accessToken: auth.accessToken, idToken: auth.idToken),
    );
    await _afterSignIn(result.user!);
    return true;
  }

  static Future<void> signInWithEmail(String email, String password) async {
    _requireInstitutional(email);
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      await _afterSignIn(result.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e));
    }
  }

  /// Creates an email/password account. The user must verify the address
  /// (proving they own the institutional mailbox) before the app opens.
  static Future<void> registerWithEmail({required String name, required String email, required String password}) async {
    _requireInstitutional(email);
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await result.user!.updateDisplayName(name);
      await result.user!.sendEmailVerification();
      await _afterSignIn(result.user!, name: name);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e));
    }
  }

  static Future<void> resendVerificationEmail() async => _auth.currentUser?.sendEmailVerification();

  /// Refreshes the user so a completed email verification is picked up.
  static Future<void> reloadUser() async => _auth.currentUser?.reload();

  /// Password accounts must verify their mailbox; Google accounts are verified by Google.
  static bool needsEmailVerification(User user) =>
      !user.emailVerified && user.providerData.any((p) => p.providerId == 'password');

  static Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // A rider who signs out stops receiving jobs.
      await _userRef(uid).update({'isOnline': false}).catchError((_) {});
    }
    await _google.signOut().catchError((_) => null);
    await _auth.signOut();
  }

  static void _requireInstitutional(String email) {
    if (!isInstitutional(email)) {
      throw AuthException('Only $institutionalDomain email addresses can be used.');
    }
  }

  static String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Try logging in.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  // ------------------------------------------------------------- Profile

  /// Every login starts at role resolution: a fresh sign-in clears the last
  /// module so users with several approved roles get the profile picker.
  static Future<void> _afterSignIn(User user, {String? name}) async {
    if (!isInstitutional(user.email)) {
      await signOut();
      throw AuthException('Access denied: please use your official $institutionalDomain email address.');
    }
    await ensureProfile(user, name: name);
    await _userRef(user.uid).update({'activeRole': null});
  }

  /// Creates `users/{uid}` with default customer access, or migrates an
  /// older single-role document to the multi-role schema.
  static Future<void> ensureProfile(User user, {String? name}) async {
    final ref = _userRef(user.uid);
    final snap = await ref.get();
    final data = snap.data();

    if (data == null) {
      await ref.set({
        'name': name ?? user.displayName ?? user.email!.split('@').first,
        'email': user.email,
        'isCustomer': true,
        'customerStatus': RoleStatus.approved,
        'activeRole': null,
        'schemaVersion': kUserSchemaVersion,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await ref.update({
      ...AppUser.migrationFor(data),
      if (data['email'] == null) 'email': user.email,
      if ((data['name'] ?? '').toString().isEmpty) 'name': name ?? user.displayName ?? user.email!.split('@').first,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Opens [role]'s module (null returns to the profile picker). Only
  /// approved roles can be activated.
  static Future<void> setActiveRole(AppUser user, UserRole? role) async {
    if (role != null && !user.canAccess(role)) {
      throw AuthException('Your ${role.label} access has not been approved yet.');
    }
    await _userRef(user.uid).update({
      'activeRole': role?.key,
      // Leaving the delivery module takes the rider offline.
      if (role != UserRole.delivery) 'isOnline': false,
    });
  }

  // -------------------------------------------------------- Applications

  /// Submits (or resubmits) a delivery application for admin review.
  static Future<void> submitDeliveryApplication({
    required String uid,
    required String name,
    required String studentId,
    required String contactNumber,
    required String idImageUrl,
    required String idImagePath,
  }) {
    return _userRef(uid).update({
      'name': name,
      'studentId': studentId,
      'contactNumber': contactNumber,
      'idImageUrl': idImageUrl,
      'idImagePath': idImagePath,
      UserRole.delivery.statusField: RoleStatus.pending,
      UserRole.delivery.reviewNoteField: '',
      'deliveryAppliedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks the vendor application as submitted once the stall is saved.
  static Future<void> submitVendorApplication({required String uid, required String stallId}) {
    return _userRef(uid).update({
      'stallId': stallId,
      UserRole.vendor.statusField: RoleStatus.pending,
      UserRole.vendor.reviewNoteField: '',
      'vendorAppliedAt': FieldValue.serverTimestamp(),
    });
  }
}
