import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/admin_ui.dart';
import '../core/user_roles.dart';
import '../services/admin_service.dart';

// -----------------------------------------------------------------------------
// 3 & 4. USER MANAGEMENT & APPROVAL FLOW VIEW
// -----------------------------------------------------------------------------
/// One account can hold several roles, each with its own approval status, so
/// the same student can appear under Customers, Vendors and Delivery.
class UserManagementView extends StatefulWidget {
  final String initialRole;
  final String initialStatus;
  const UserManagementView({super.key, this.initialRole = 'Customers', this.initialStatus = 'All'});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  static const _roleSegments = {'Customers': UserRoles.customer, 'Vendors': UserRoles.vendor, 'Delivery': UserRoles.delivery};

  final _users = FirebaseFirestore.instance.collection('users').snapshots();
  late String selectedRoleSegment = widget.initialRole;
  late String _statusFilter = widget.initialStatus;
  String _query = '';
  String? _selectedUserId;

  List<String> _statusSegments(String role) => role == UserRoles.customer
      ? ['All', RoleStatus.approved, RoleStatus.suspended]
      : ['All', RoleStatus.pending, RoleStatus.approved, RoleStatus.rejected, RoleStatus.suspended];

  @override
  Widget build(BuildContext context) {
    final role = _roleSegments[selectedRoleSegment]!;
    if (_selectedUserId != null) {
      return UserDetailView(userId: _selectedUserId!, role: role, onBack: () => setState(() => _selectedUserId = null));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _users,
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        bool holdsRole(QueryDocumentSnapshot<Map<String, dynamic>> d, String r) => UserRoles.statusOf(d.data(), r) != null;
        final roleDocs = allDocs.where((d) => holdsRole(d, role)).toList();
        final roleCounts = {for (final e in _roleSegments.entries) e.key: allDocs.where((d) => holdsRole(d, e.value)).length};
        final statuses = _statusSegments(role);
        final statusCounts = {
          for (final s in statuses)
            s: s == 'All' ? roleDocs.length : roleDocs.where((d) => UserRoles.statusOf(d.data(), role) == s).length,
        };

        final docs = roleDocs.where((d) {
          final data = d.data();
          if (_statusFilter != 'All' && UserRoles.statusOf(data, role) != _statusFilter) return false;
          if (_query.isEmpty) return true;
          return '${data['name']} ${data['email']} ${data['studentId'] ?? ''}'.toLowerCase().contains(_query);
        }).toList()
          // Pending applications first, then newest.
          ..sort((a, b) {
            final aPending = UserRoles.statusOf(a.data(), role) == RoleStatus.pending ? 0 : 1;
            final bPending = UserRoles.statusOf(b.data(), role) == RoleStatus.pending ? 0 : 1;
            if (aPending != bPending) return aPending - bPending;
            final aDate = toDate(_submittedAt(a.data(), role)) ?? DateTime(2000);
            final bDate = toDate(_submittedAt(b.data(), role)) ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Users',
              subtitle: '${allDocs.length} registered accounts',
              searchHint: 'Search by name, email or student ID',
              onSearch: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: 24),
            FilterChips(
              options: _roleSegments.keys.toList(),
              selected: selectedRoleSegment,
              counts: roleCounts,
              onSelected: (segment) => setState(() {
                selectedRoleSegment = segment;
                _statusFilter = 'All';
              }),
            ),
            const SizedBox(height: 12),
            _StatusChips(
              options: statuses,
              selected: _statusFilter,
              counts: statusCounts,
              onSelected: (s) => setState(() => _statusFilter = s),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: AdminCard(
                padding: EdgeInsets.zero,
                child: !snapshot.hasData
                    ? (snapshot.hasError
                        ? EmptyState('Could not load users: ${snapshot.error}')
                        : const Center(child: CircularProgressIndicator()))
                    : docs.isEmpty
                        ? const EmptyState('No matching user records found in this category.')
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                horizontalMargin: 24,
                                showCheckboxColumn: false,
                                columns: [
                                  _column('NAME'),
                                  _column('EMAIL'),
                                  if (role == UserRoles.delivery) _column('STUDENT ID'),
                                  _column(role == UserRoles.customer ? 'JOINED' : 'SUBMITTED'),
                                  _column('OTHER ROLES'),
                                  _column('STATUS'),
                                  _column(''),
                                ],
                                rows: docs.map((doc) => _buildUserTableRow(doc.id, doc.data(), role)).toList(),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        );
      },
    );
  }

  DataColumn _column(String label) =>
      DataColumn(label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));

  DataRow _buildUserTableRow(String userId, Map<String, dynamic> data, String role) {
    final status = UserRoles.statusOf(data, role);
    final isPending = status == RoleStatus.pending;
    final otherRoles = [UserRoles.customer, UserRoles.vendor, UserRoles.delivery]
        .where((r) => r != role && UserRoles.statusOf(data, r) == RoleStatus.approved)
        .map(UserRoles.label)
        .join(', ');
    void open() => setState(() => _selectedUserId = userId);

    return DataRow(
      onSelectChanged: (_) => open(),
      cells: [
        DataCell(Row(
          children: [
            CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade200, child: const Icon(Icons.person, size: 16, color: Colors.grey)),
            const SizedBox(width: 12),
            Text(data['name'] ?? 'Unnamed User', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (UserRoles.isAdmin(data)) ...[
              const SizedBox(width: 8),
              const Icon(Icons.admin_panel_settings, size: 16, color: Colors.grey),
            ],
          ],
        )),
        DataCell(Text(data['email'] ?? 'No Email')),
        if (role == UserRoles.delivery) DataCell(Text(data['studentId'] ?? 'Not submitted')),
        DataCell(Text(formatDate(_submittedAt(data, role)))),
        DataCell(Text(otherRoles.isEmpty ? '—' : otherRoles, style: const TextStyle(color: Colors.grey))),
        DataCell(StatusPill(status ?? 'Not applied')),
        DataCell(isPending
            ? ElevatedButton(
                onPressed: open,
                style: ElevatedButton.styleFrom(backgroundColor: AdminColors.accent, foregroundColor: Colors.black, elevation: 0),
                child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            : IconButton(icon: const Icon(Icons.chevron_right), onPressed: open)),
      ],
    );
  }
}

dynamic _submittedAt(Map<String, dynamic> user, String role) => switch (role) {
      UserRoles.delivery => user['deliveryAppliedAt'] ?? user['registeredAt'] ?? user['createdAt'],
      UserRoles.vendor => user['vendorAppliedAt'] ?? user['createdAt'],
      _ => user['createdAt'],
    };

/// [FilterChips] with role-status labels ('pending' → 'Pending').
class _StatusChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;
  const _StatusChips({required this.options, required this.selected, required this.counts, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    String label(String s) => s == 'All' ? 'All' : RoleStatus.label(s);
    return FilterChips(
      options: options.map(label).toList(),
      selected: label(selected),
      counts: {for (final s in options) label(s): counts[s] ?? 0},
      onSelected: (picked) => onSelected(options.firstWhere((s) => label(s) == picked)),
    );
  }
}

// -----------------------------------------------------------------------------
// USER DETAIL + APPLICATION REVIEW (for one role)
// -----------------------------------------------------------------------------
class UserDetailView extends StatefulWidget {
  final String userId;

  /// The role being reviewed: 'customer', 'vendor' or 'delivery'.
  final String role;
  final VoidCallback onBack;
  const UserDetailView({super.key, required this.userId, required this.role, required this.onBack});

  @override
  State<UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends State<UserDetailView> {
  late final _user = FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots();
  bool _isSaving = false;

  String get role => widget.role;

  Future<void> _decide(Map<String, dynamic> user, String? current, String next) async {
    final name = user['name'] ?? 'this user';
    final roleLabel = UserRoles.label(role);
    final (String title, String message, String confirmText) = switch (next) {
      RoleStatus.approved when current == RoleStatus.pending => (
          'Approve $name as $roleLabel?',
          role == UserRoles.delivery
              ? '$name will be able to open the Delivery module and accept jobs right away.'
              : 'Their stall becomes visible to customers and the Vendor dashboard unlocks.',
          'Approve',
        ),
      RoleStatus.approved => ('Reinstate $name\'s $roleLabel access?', 'They can use the $roleLabel module again.', 'Reinstate'),
      RoleStatus.rejected => (
          'Reject $name\'s $roleLabel application?',
          'They will see your reason in the app and can resubmit.',
          'Reject',
        ),
      _ => (
          'Suspend $name\'s $roleLabel access?',
          'They are locked out of the $roleLabel module until reinstated. Their other profiles are not affected.',
          'Suspend',
        ),
    };

    final note = await showAdminConfirm(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      isDestructive: next != RoleStatus.approved,
      askReason: next != RoleStatus.approved,
    );
    if (note == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await AdminService.setRoleStatus(userId: widget.userId, user: user, role: role, status: next, note: note);
      if (mounted) showAdminSnackBar(context, '$name: $roleLabel ${RoleStatus.label(next).toLowerCase()}');
    } catch (e) {
      if (mounted) showAdminSnackBar(context, 'Could not update $name: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _user,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final user = snapshot.data!.data();
        if (user == null) return const EmptyState('This user no longer exists.');
        final status = UserRoles.statusOf(user, role);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Navigation anchor
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                label: const Text('Back to users list', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    role == UserRoles.delivery
                        ? 'Delivery application'
                        : role == UserRoles.vendor
                            ? 'Vendor application'
                            : 'Customer account',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  StatusPill(status ?? 'Not applied'),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: _buildProfileCard(user)),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        if (role == UserRoles.delivery) _buildStudentIdCard(user),
                        if (role == UserRoles.vendor) _VendorStallCard(stallId: user['stallId']),
                        if (role != UserRoles.vendor) _ActivityStatsCard(userId: widget.userId, role: role),
                        if (status != null) ...[
                          const SizedBox(height: 24),
                          _buildDecisionCard(user, status),
                        ],
                        const SizedBox(height: 24),
                        _AdminAccessCard(userId: widget.userId, user: user),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> user) {
    final note = UserRoles.reviewNoteOf(user, role);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 30, backgroundColor: Colors.grey.shade200, child: const Icon(Icons.person, size: 36, color: Colors.grey)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? 'Unnamed User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(user['email'] ?? 'No Email', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 170, child: Text('Profiles', style: TextStyle(color: Colors.grey))),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in [UserRoles.customer, UserRoles.vendor, UserRoles.delivery])
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${UserRoles.label(r)}: ', style: const TextStyle(fontSize: 12)),
                            StatusPill(UserRoles.statusOf(user, r) ?? 'Not applied'),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (role == UserRoles.delivery) ...[
            const Divider(height: 1),
            MetaRow('Student ID number', user['studentId'] ?? 'Not submitted'),
            const Divider(height: 1),
            MetaRow('Contact number', user['contactNumber'] ?? 'Not submitted'),
            const Divider(height: 1),
            MetaRow('Delivery mode', user['deliveryMode'] ?? 'On foot'),
            const Divider(height: 1),
            MetaRow('Online now', user['isOnline'] == true ? 'Yes' : 'No'),
          ],
          const Divider(height: 1),
          MetaRow(role == UserRoles.customer ? 'Joined' : 'Submitted', formatDateTime(_submittedAt(user, role))),
          if (user['${role}ReviewedAt'] != null || user['reviewedAt'] != null) ...[
            const Divider(height: 1),
            MetaRow('Last reviewed',
                '${formatDateTime(user['${role}ReviewedAt'] ?? user['reviewedAt'])} by ${user['${role}ReviewedBy'] ?? user['reviewedBy'] ?? 'admin'}'),
          ],
          if (note.isNotEmpty) ...[
            const Divider(height: 1),
            MetaRow('Review note', note),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentIdCard(Map<String, dynamic> user) {
    final idUrl = (user['idImageUrl'] ?? '') as String;
    final email = (user['email'] ?? '') as String;
    final contact = (user['contactNumber'] ?? '') as String;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Uploaded student ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              const Spacer(),
              if (idUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () => showImagePreview(context, idUrl, title: 'Student ID — ${user['name'] ?? ''}'),
                  icon: const Icon(Icons.zoom_in, size: 18),
                  label: const Text('View full size'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: idUrl.isEmpty ? null : () => showImagePreview(context, idUrl, title: 'Student ID — ${user['name'] ?? ''}'),
            child: Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(color: AdminColors.panel, borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: AdminNetworkImage(idUrl, fit: BoxFit.contain, placeholderIcon: Icons.badge),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Verification checklist', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _check('Institutional @csucc.edu.ph email', email.toLowerCase().endsWith('@csucc.edu.ph')),
          _check('Student ID number provided', (user['studentId'] ?? '').toString().isNotEmpty),
          _check('Valid PH mobile number (09XXXXXXXXX)', RegExp(r'^09\d{9}$').hasMatch(contact)),
          _check('Student ID photo uploaded', idUrl.isNotEmpty),
          const SizedBox(height: 8),
          Text('Compare the name and ID number above with the photo before approving.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _check(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 18, color: ok ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: ok ? Colors.black87 : Colors.red.shade700)),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(Map<String, dynamic> user, String status) {
    Widget approve(String label) => Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : () => _decide(user, status, RoleStatus.approved),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
    Widget deny(String label, String next) => Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => _decide(user, status, next),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );

    final List<Widget> buttons = switch (status) {
      RoleStatus.pending => [deny('Reject', RoleStatus.rejected), const SizedBox(width: 16), approve('Approve')],
      RoleStatus.approved => [deny('Suspend ${UserRoles.label(role)} access', RoleStatus.suspended)],
      _ => [approve('Reinstate ${UserRoles.label(role)} access')],
    };

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status == RoleStatus.pending ? 'Decision' : '${UserRoles.label(role)} access',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Only affects this profile; the user\'s other roles stay as they are.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 16),
          Row(children: buttons),
          if (_isSaving) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        ],
      ),
    );
  }
}

/// Stall submitted by a vendor applicant.
class _VendorStallCard extends StatelessWidget {
  final String? stallId;
  const _VendorStallCard({required this.stallId});

  @override
  Widget build(BuildContext context) {
    if (stallId == null) {
      return const AdminCard(child: Text('No stall submitted yet.', style: TextStyle(color: Colors.grey)));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('stalls').doc(stallId).snapshots(),
      builder: (context, snapshot) {
        final stall = snapshot.data?.data();
        if (stall == null) return const AdminCard(child: Text('Loading stall…', style: TextStyle(color: Colors.grey)));
        final pickup = stall['pickupPoint'] as GeoPoint?;
        return AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Submitted stall', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: AdminNetworkImage(stall['imageUrl'], placeholderIcon: Icons.storefront),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stall['stallName'] ?? 'Unnamed stall', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(stall['program'] ?? '', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  StatusPill(stall['status'] ?? AccountStatus.active),
                ],
              ),
              const SizedBox(height: 8),
              MetaRow('Category', (stall['category'] ?? '').isEmpty ? '—' : stall['category']),
              const Divider(height: 1),
              MetaRow('Operating hours', (stall['operatingHours'] ?? '').isEmpty ? '—' : stall['operatingHours']),
              const Divider(height: 1),
              MetaRow('Pickup pin',
                  pickup == null ? 'Not pinned' : '${pickup.latitude.toStringAsFixed(5)}, ${pickup.longitude.toStringAsFixed(5)}'),
            ],
          ),
        );
      },
    );
  }
}

/// Order stats for customers (as buyer) and riders (as deliverer).
class _ActivityStatsCard extends StatelessWidget {
  final String userId;
  final String role;
  const _ActivityStatsCard({required this.userId, required this.role});

  @override
  Widget build(BuildContext context) {
    final field = role == UserRoles.delivery ? 'deliveryPersonId' : 'customerId';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').where(field, isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        final orders = snapshot.data?.docs.map((d) => d.data()).toList() ?? [];
        final delivered = orders.where((o) => o['status'] == OrderStatus.delivered).toList();
        final active = orders.where((o) => OrderStatus.active.contains(o['status'])).length;
        final amount = delivered.fold<double>(
          0,
          (total, o) => total + ((role == UserRoles.delivery ? o['deliveryFee'] : o['totalPrice']) as num? ?? 0).toDouble(),
        );
        return Padding(
          padding: EdgeInsets.only(top: role == UserRoles.delivery ? 24 : 0),
          child: Row(
            children: [
              Expanded(
                child: _stat(role == UserRoles.delivery ? 'Deliveries done' : 'Orders placed',
                    '${role == UserRoles.delivery ? delivered.length : orders.length}'),
              ),
              const SizedBox(width: 16),
              Expanded(child: _stat('In progress', '$active')),
              const SizedBox(width: 16),
              Expanded(child: _stat(role == UserRoles.delivery ? 'Fees earned' : 'Total spent', formatPeso(amount))),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) {
    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


/// Grants or removes access to this admin console.
class _AdminAccessCard extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> user;
  const _AdminAccessCard({required this.userId, required this.user});

  @override
  State<_AdminAccessCard> createState() => _AdminAccessCardState();
}

class _AdminAccessCardState extends State<_AdminAccessCard> {
  bool _isSaving = false;

  Future<void> _set(bool grant) async {
    final name = widget.user['name'] ?? 'this user';
    final note = await showAdminConfirm(
      context,
      title: grant ? 'Make $name an admin?' : "Remove $name's admin access?",
      message: grant
          ? 'They will be able to approve vendors and riders, manage stalls and cancel orders in this console.'
          : 'They will no longer be able to open this console. Their customer, vendor and rider profiles are not affected.',
      confirmText: grant ? 'Make admin' : 'Remove access',
      isDestructive: !grant,
    );
    if (note == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await AdminService.setAdminAccess(widget.userId, grant);
      if (mounted) showAdminSnackBar(context, grant ? '$name is now an admin' : "Removed $name's admin access");
    } catch (e) {
      if (mounted) showAdminSnackBar(context, 'Could not update $name: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['isAdmin'] == true;
    final isMe = widget.userId == FirebaseAuth.instance.currentUser?.uid;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, color: isAdmin ? Colors.black87 : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  isMe
                      ? 'This is you. Another admin has to change your access.'
                      : isAdmin
                          ? 'Can use this admin console.'
                          : 'Cannot open this admin console.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!isMe)
            _isSaving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : isAdmin
                    ? OutlinedButton(onPressed: () => _set(false), child: const Text('Remove access'))
                    : ElevatedButton(
                        onPressed: () => _set(true),
                        style: ElevatedButton.styleFrom(backgroundColor: AdminColors.accent, foregroundColor: Colors.black, elevation: 0),
                        child: const Text('Make admin', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
        ],
      ),
    );
  }
}
