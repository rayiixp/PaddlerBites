/// Multi-role user schema shared with the mobile app (`lib/models/app_user.dart`).
///
/// `users/{uid}` holds one approval status per role:
/// `customerStatus`, `vendorStatus`, `deliveryStatus` ∈
/// null (not applied) | 'pending' | 'approved' | 'rejected' | 'suspended',
/// plus `<role>ReviewNote`, `<role>ReviewedAt`, `<role>ReviewedBy`.
class RoleStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const suspended = 'suspended';

  static String label(String? status) => switch (status) {
        pending => 'Pending',
        approved => 'Approved',
        rejected => 'Rejected',
        suspended => 'Suspended',
        _ => 'Not applied',
      };

  /// Accepts current values and the older 'Active' / 'Pending Review' strings.
  static String? normalize(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'approved':
      case 'active':
        return approved;
      case 'pending':
      case 'pending review':
        return pending;
      case 'rejected':
        return rejected;
      case 'suspended':
        return suspended;
      default:
        return null;
    }
  }
}

/// Role keys: 'customer', 'vendor', 'delivery'.
class UserRoles {
  static const customer = 'customer';
  static const vendor = 'vendor';
  static const delivery = 'delivery';

  static String label(String role) => switch (role) {
        vendor => 'Vendor',
        delivery => 'Delivery Personnel',
        _ => 'Customer',
      };

  /// Approval status of [role] for a user document, reading legacy
  /// single-role documents (`role` + `status`) the same way the app does.
  static String? statusOf(Map<String, dynamic> user, String role) {
    final legacyRole = user['role'];
    if (role == customer) {
      final explicit = RoleStatus.normalize(user['customerStatus']);
      if (explicit == RoleStatus.suspended) return RoleStatus.suspended;
      if (explicit == null && legacyRole == customer && RoleStatus.normalize(user['status']) == RoleStatus.suspended) {
        return RoleStatus.suspended;
      }
      return (user['isCustomer'] ?? true) == true ? RoleStatus.approved : null;
    }
    var status = RoleStatus.normalize(user['${role}Status']);
    if (status == null && legacyRole == role) status = RoleStatus.normalize(user['status']);
    final applied = role == vendor ? user['stallId'] != null : user['studentId'] != null;
    if (status == RoleStatus.pending && !applied) return null;
    return status;
  }

  static String reviewNoteOf(Map<String, dynamic> user, String role) =>
      (user['${role}ReviewNote'] ?? (user['role'] == role ? user['reviewNote'] : null) ?? '') as String;

  static bool isAdmin(Map<String, dynamic>? user) => user?['isAdmin'] == true || user?['role'] == 'admin';

  /// Applications waiting for an admin decision.
  static bool isPendingApplication(Map<String, dynamic> user, String role) => statusOf(user, role) == RoleStatus.pending;
}
