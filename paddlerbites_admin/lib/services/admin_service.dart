import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/admin_ui.dart';
import '../core/user_roles.dart';

/// All admin writes. Every decision records who made it and when, so the
/// mobile app can show the outcome and there is an audit trail.
class AdminService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Map<String, dynamic> get _audit => {
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      };

  /// Stall documents keep the 'Active' / 'Pending Review' / 'Suspended' values
  /// the mobile app filters on.
  static String stallStatusFor(String roleStatus) => switch (roleStatus) {
        RoleStatus.approved => AccountStatus.active,
        RoleStatus.pending => AccountStatus.pending,
        _ => AccountStatus.suspended,
      };

  /// Sets one role's approval — 'approved', 'rejected' or 'suspended' — on
  /// `users/{uid}.<role>Status` without touching the user's other roles.
  ///
  /// The mobile app streams the user document, so an approved rider or
  /// vendor gets access immediately. For vendors the stall status is kept in
  /// sync because it controls customer visibility.
  static Future<void> setRoleStatus({
    required String userId,
    required Map<String, dynamic> user,
    required String role,
    required String status,
    String note = '',
  }) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(userId), {
      '${role}Status': status,
      '${role}ReviewNote': note,
      '${role}ReviewedAt': FieldValue.serverTimestamp(),
      '${role}ReviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      // Riders who lose approval drop off the available-riders pool.
      if (role == UserRoles.delivery && status != RoleStatus.approved) 'isOnline': false,
    });
    final stallId = user['stallId'];
    if (role == UserRoles.vendor && stallId is String && stallId.isNotEmpty) {
      final stallStatus = stallStatusFor(status);
      batch.set(
        _db.collection('stalls').doc(stallId),
        {'status': stallStatus, if (stallStatus != AccountStatus.active) 'isOpen': false, ..._audit},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Stall-side approval/suspension; mirrors the decision onto the owner's
  /// `vendorStatus`.
  static Future<void> setStallStatus({required String stallId, required Map<String, dynamic> stall, required String status}) async {
    final batch = _db.batch();
    batch.update(_db.collection('stalls').doc(stallId), {
      'status': status,
      if (status != AccountStatus.active) 'isOpen': false,
      ..._audit,
    });
    final ownerId = stall['ownerId'];
    if (ownerId is String && ownerId.isNotEmpty) {
      final owner = await _db.collection('users').doc(ownerId).get();
      if (owner.exists) {
        batch.update(owner.reference, {
          'vendorStatus': status == AccountStatus.active
              ? RoleStatus.approved
              : status == AccountStatus.pending
                  ? RoleStatus.pending
                  : RoleStatus.suspended,
          'vendorReviewedAt': FieldValue.serverTimestamp(),
          'vendorReviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        });
      }
    }
    await batch.commit();
  }

  /// Grants or removes access to this console. Only admins can do this
  /// (enforced by the Firestore rules); nobody can grant it to themselves.
  static Future<void> setAdminAccess(String userId, bool isAdmin) {
    if (userId == FirebaseAuth.instance.currentUser?.uid) {
      throw StateError("You can't change your own admin access.");
    }
    return _db.collection('users').doc(userId).update({
      'isAdmin': isAdmin,
      'adminUpdatedAt': FieldValue.serverTimestamp(),
      'adminUpdatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
    });
  }

  static Future<void> setStallOpen(String stallId, bool isOpen) =>
      _db.collection('stalls').doc(stallId).update({'isOpen': isOpen});

  static Future<void> setMenuItemAvailability(String itemId, bool isAvailable) =>
      _db.collection('menuItems').doc(itemId).update({'isAvailable': isAvailable, 'updatedAt': FieldValue.serverTimestamp()});

  /// Cancels an order that is still in progress.
  static Future<void> cancelOrder(String orderId, String reason) {
    return _db.runTransaction((tx) async {
      final ref = _db.collection('orders').doc(orderId);
      final status = (await tx.get(ref)).data()?['status'];
      if (!OrderStatus.active.contains(status)) {
        throw StateError('Order is already $status.');
      }
      tx.update(ref, {
        'status': OrderStatus.cancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'admin',
        'cancelReason': reason,
      });
    });
  }
}
