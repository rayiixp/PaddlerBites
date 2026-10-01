import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paddlerbites/models/app_user.dart';

void main() {
  group('role resolution', () {
    test('new account is a customer only and goes straight to the customer module', () {
      final user = AppUser.fromMap('u1', {'isCustomer': true, 'customerStatus': 'approved'});
      expect(user.approvedRoles, [UserRole.customer]);
      expect(user.resolvedModule, UserRole.customer);
    });

    test('several approved roles and no active role asks the user to pick', () {
      final user = AppUser.fromMap('u1', {
        'isCustomer': true,
        'customerStatus': 'approved',
        'deliveryStatus': 'approved',
        'studentId': '2023-00456',
      });
      expect(user.approvedRoles, [UserRole.customer, UserRole.delivery]);
      expect(user.resolvedModule, isNull);
      expect(user.activeRole, isNull);
    });

    test('a pending vendor role is not accessible and does not count as approved', () {
      final user = AppUser.fromMap('u1', {'vendorStatus': 'pending', 'stallId': 'u1', 'activeRole': 'customer'});
      expect(user.canAccess(UserRole.vendor), isFalse);
      expect(user.statusOf(UserRole.vendor), RoleStatus.pending);
      expect(user.resolvedModule, UserRole.customer);
    });

    test('an active role that gets suspended resolves to no module (pending screen)', () {
      final user = AppUser.fromMap('u1', {
        'deliveryStatus': 'suspended',
        'studentId': 'x',
        'activeRole': 'delivery',
      });
      expect(user.resolvedModule, isNull);
      expect(user.activeRole, UserRole.delivery);
    });

    test('suspended customer with no other roles has nothing to open', () {
      final user = AppUser.fromMap('u1', {'customerStatus': 'suspended'});
      expect(user.approvedRoles, isEmpty);
      expect(user.resolvedModule, isNull);
    });
  });

  group('legacy single-role documents', () {
    test('approved legacy vendor keeps vendor access', () {
      final user = AppUser.fromMap('u1', {'role': 'vendor', 'status': 'Active', 'stallId': 'u1'});
      expect(user.vendorStatus, RoleStatus.approved);
      expect(user.canAccess(UserRole.customer), isTrue);
    });

    test('legacy pending rider who never submitted the form has not applied', () {
      final user = AppUser.fromMap('u1', {'role': 'delivery', 'status': 'Pending Review'});
      expect(user.deliveryStatus, isNull);
    });

    test('status saved on an earlier role switch is kept', () {
      final user = AppUser.fromMap('u1', {
        'role': 'customer',
        'status': 'Active',
        'deliveryStatus': 'Active',
        'studentId': 'x',
        'reviewNote': 'ignored for other roles',
      });
      expect(user.deliveryStatus, RoleStatus.approved);
      expect(user.reviewNoteFor(UserRole.delivery), isEmpty);
    });

    test('legacy admin role becomes the isAdmin flag', () {
      expect(AppUser.fromMap('u1', {'role': 'admin'}).isAdmin, isTrue);
    });

    test('migration writes per-role fields and removes role/status', () {
      final updates = AppUser.migrationFor({
        'role': 'delivery',
        'status': 'Suspended',
        'reviewNote': 'Blurry ID',
        'studentId': 'x',
      });
      expect(updates['deliveryStatus'], RoleStatus.suspended);
      expect(updates['deliveryReviewNote'], 'Blurry ID');
      expect(updates['customerStatus'], RoleStatus.approved);
      expect(updates['vendorStatus'], isA<FieldValue>());
      expect(updates['role'], isA<FieldValue>());
      expect(updates['status'], isA<FieldValue>());
      expect(updates['schemaVersion'], kUserSchemaVersion);
    });

    test('already-migrated documents need no update', () {
      expect(AppUser.migrationFor({'schemaVersion': kUserSchemaVersion}), isEmpty);
    });
  });
}
