import 'package:cloud_firestore/cloud_firestore.dart';

/// The three mobile modules a single @csucc.edu.ph account can hold.
enum UserRole {
  customer('customer', 'Customer', 'assets/images/customer_icon.png'),
  delivery('delivery', 'Delivery Personnel', 'assets/images/delivery_personnel_icon.png'),
  vendor('vendor', 'Vendor', 'assets/images/vendor_icon.png');

  const UserRole(this.key, this.label, this.iconAsset);

  /// Value stored in Firestore (`activeRole`, and the `<key>Status` field name).
  final String key;
  final String label;
  final String iconAsset;

  String get statusField => '${key}Status';
  String get reviewNoteField => '${key}ReviewNote';

  /// Vendor and delivery access must be granted by an admin.
  bool get requiresApproval => this != UserRole.customer;

  static UserRole? fromKey(dynamic key) {
    for (final role in values) {
      if (role.key == key) return role;
    }
    return null;
  }
}

/// Per-role approval state. A missing (null) status means "never applied".
class RoleStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const suspended = 'suspended';

  /// Accepts current values and the older 'Active' / 'Pending Review' /
  /// 'Suspended' strings, so existing documents keep working.
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

/// Current schema version of `users/{uid}`; older documents are migrated on login.
const int kUserSchemaVersion = 2;

/// `users/{uid}`
///
/// ```
/// {
///   name, email, createdAt, updatedAt,
///   isCustomer: true,                 // every institutional account
///   customerStatus: 'approved',       // 'suspended' when an admin blocks the account
///   vendorStatus:   null | 'pending' | 'approved' | 'rejected' | 'suspended',
///   deliveryStatus: null | 'pending' | 'approved' | 'rejected' | 'suspended',
///   vendorReviewNote, deliveryReviewNote, customerReviewNote,   // admin's reason
///   vendorAppliedAt, deliveryAppliedAt,
///   activeRole: 'customer' | 'vendor' | 'delivery' | null,      // module in use
///   isAdmin: bool,                    // web console access
///   stallId,                                                    // vendor application
///   studentId, contactNumber, idImageUrl, idImagePath,          // delivery application
///   schemaVersion: 2,
/// }
/// ```
class AppUser {
  final String uid;
  final String name;
  final String email;
  final bool isCustomer;
  final bool isAdmin;
  final String customerStatus;
  final String? vendorStatus;
  final String? deliveryStatus;
  final UserRole? activeRole;
  final String? stallId;
  final String? studentId;
  final Map<UserRole, String> reviewNotes;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.isCustomer = true,
    this.isAdmin = false,
    this.customerStatus = RoleStatus.approved,
    this.vendorStatus,
    this.deliveryStatus,
    this.activeRole,
    this.stallId,
    this.studentId,
    this.reviewNotes = const {},
  });

  /// Approval state for [role]; null when the user never applied.
  String? statusOf(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return isCustomer ? customerStatus : null;
      case UserRole.vendor:
        return vendorStatus;
      case UserRole.delivery:
        return deliveryStatus;
    }
  }

  bool canAccess(UserRole role) => statusOf(role) == RoleStatus.approved;

  List<UserRole> get approvedRoles => UserRole.values.where(canAccess).toList();

  String reviewNoteFor(UserRole role) => reviewNotes[role] ?? '';

  /// The module to open without asking: the chosen [activeRole] if it is still
  /// approved, otherwise the only approved role. Null means the user must pick
  /// (several approved roles) or their chosen role lost its approval.
  UserRole? get resolvedModule {
    if (activeRole != null) return canAccess(activeRole!) ? activeRole : null;
    final approved = approvedRoles;
    return approved.length == 1 ? approved.first : null;
  }

  factory AppUser.fromDoc(DocumentSnapshot doc) => AppUser.fromMap(doc.id, (doc.data() as Map<String, dynamic>?) ?? {});

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final legacy = _LegacyFields(data);
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      isCustomer: data['isCustomer'] ?? true,
      isAdmin: data['isAdmin'] == true || legacy.role == 'admin',
      customerStatus: legacy.customerStatus,
      vendorStatus: legacy.statusFor(UserRole.vendor),
      deliveryStatus: legacy.statusFor(UserRole.delivery),
      activeRole: UserRole.fromKey(data['activeRole']),
      stallId: data['stallId'],
      studentId: data['studentId'],
      reviewNotes: {
        for (final role in UserRole.values)
          if ((legacy.reviewNoteFor(role)).isNotEmpty) role: legacy.reviewNoteFor(role),
      },
    );
  }

  /// Field updates that convert a pre-multi-role document (single `role` +
  /// `status`) to the current schema. Empty when already migrated.
  static Map<String, dynamic> migrationFor(Map<String, dynamic> data) {
    if (data['schemaVersion'] == kUserSchemaVersion) return {};
    final legacy = _LegacyFields(data);
    return {
      'isCustomer': data['isCustomer'] ?? true,
      'customerStatus': legacy.customerStatus,
      for (final role in [UserRole.vendor, UserRole.delivery])
        role.statusField: legacy.statusFor(role) ?? FieldValue.delete(),
      for (final role in UserRole.values)
        if (legacy.reviewNoteFor(role).isNotEmpty) role.reviewNoteField: legacy.reviewNoteFor(role),
      if (data['isAdmin'] == true || legacy.role == 'admin') 'isAdmin': true,
      'role': FieldValue.delete(),
      'status': FieldValue.delete(),
      'reviewNote': FieldValue.delete(),
      'schemaVersion': kUserSchemaVersion,
    };
  }
}

/// Reads role statuses from both the current fields and the old single-role
/// fields (`role`, `status`, `reviewNote`).
class _LegacyFields {
  final Map<String, dynamic> data;
  _LegacyFields(this.data);

  String? get role => data['role'];

  bool _hasApplication(UserRole role) =>
      role == UserRole.vendor ? data['stallId'] != null : data['studentId'] != null;

  String? statusFor(UserRole role) {
    var status = RoleStatus.normalize(data[role.statusField]);
    if (status == null && role.key == this.role) status = RoleStatus.normalize(data['status']);
    // Older sign-ins marked a role 'pending' before anything was submitted.
    if (status == RoleStatus.pending && !_hasApplication(role)) return null;
    return status;
  }

  String get customerStatus {
    final explicit = RoleStatus.normalize(data['customerStatus']);
    if (explicit == RoleStatus.suspended) return RoleStatus.suspended;
    if (explicit == null && role == 'customer' && RoleStatus.normalize(data['status']) == RoleStatus.suspended) {
      return RoleStatus.suspended;
    }
    return RoleStatus.approved;
  }

  String reviewNoteFor(UserRole role) =>
      (data[role.reviewNoteField] ?? (role.key == this.role ? data['reviewNote'] : null) ?? '') as String;
}
