import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/admin_ui.dart';
import '../services/admin_service.dart';

// -----------------------------------------------------------------------------
// 5. STALL OVERSIGHT VIEW
// -----------------------------------------------------------------------------
class StallOversightView extends StatefulWidget {
  const StallOversightView({super.key});

  @override
  State<StallOversightView> createState() => _StallOversightViewState();
}

class _StallOversightViewState extends State<StallOversightView> {
  static const _statusSegments = ['All', AccountStatus.pending, AccountStatus.active, AccountStatus.suspended];

  final _stalls = FirebaseFirestore.instance.collection('stalls').snapshots();
  String _statusFilter = 'All';
  String _query = '';
  String? _selectedStallId;

  @override
  Widget build(BuildContext context) {
    if (_selectedStallId != null) {
      return StallDetailView(stallId: _selectedStallId!, onBack: () => setState(() => _selectedStallId = null));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stalls,
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        String statusOf(Map<String, dynamic> d) => d['status'] ?? AccountStatus.active;
        final counts = {
          for (final s in _statusSegments) s: s == 'All' ? allDocs.length : allDocs.where((d) => statusOf(d.data()) == s).length,
        };
        final docs = allDocs.where((d) {
          final data = d.data();
          if (_statusFilter != 'All' && statusOf(data) != _statusFilter) return false;
          return _query.isEmpty || '${data['stallName']} ${data['program']} ${data['category']}'.toLowerCase().contains(_query);
        }).toList()
          ..sort((a, b) => '${a.data()['stallName']}'.toLowerCase().compareTo('${b.data()['stallName']}'.toLowerCase()));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Stalls',
              subtitle: '${allDocs.length} registered stalls · ${allDocs.where((d) => d.data()['isOpen'] == true).length} open now',
              searchHint: 'Search stalls',
              onSearch: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: 24),
            FilterChips(
              options: _statusSegments,
              selected: _statusFilter,
              counts: counts,
              onSelected: (s) => setState(() => _statusFilter = s),
            ),
            const SizedBox(height: 24),
            // Data Sheet Table display list connected to live stalls collection stream
            Expanded(
              child: AdminCard(
                padding: EdgeInsets.zero,
                child: !snapshot.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                        ? const EmptyState('No registered campus food stalls found yet.')
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                horizontalMargin: 24,
                                showCheckboxColumn: false,
                                columns: const [
                                  DataColumn(label: Text('STALL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('RATING', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('ORDERS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('APPROVAL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                  DataColumn(label: Text('')),
                                ],
                                rows: docs.map((doc) => _buildStallRow(doc.id, doc.data())).toList(),
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

  DataRow _buildStallRow(String stallId, Map<String, dynamic> data) {
    void open() => setState(() => _selectedStallId = stallId);
    final rating = (data['rating'] as num?) ?? 0;
    return DataRow(onSelectChanged: (_) => open(), cells: [
      DataCell(Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 28,
              height: 28,
              child: (data['imageUrl'] ?? '').isEmpty
                  ? Container(color: const Color(0xFF0D3B2E), child: const Icon(Icons.storefront, size: 16, color: Colors.white))
                  : AdminNetworkImage(data['imageUrl']),
            ),
          ),
          const SizedBox(width: 12),
          Text(data['stallName'] ?? 'Unnamed Stall', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      )),
      DataCell(Text((data['category'] ?? '').isEmpty ? '—' : data['category'])),
      DataCell(Text(rating > 0 ? '⭐ ${rating.toStringAsFixed(1)}' : '—', style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text('${data['totalOrders'] ?? 0}')),
      DataCell(StatusPill(data['status'] ?? AccountStatus.active)),
      DataCell(StatusPill(data['isOpen'] == true ? 'Open' : 'Closed')),
      DataCell(IconButton(icon: const Icon(Icons.chevron_right), onPressed: open)),
    ]);
  }
}

// -----------------------------------------------------------------------------
// STALL DETAIL: owner, stats, approval, menu moderation
// -----------------------------------------------------------------------------
class StallDetailView extends StatefulWidget {
  final String stallId;
  final VoidCallback onBack;
  const StallDetailView({super.key, required this.stallId, required this.onBack});

  @override
  State<StallDetailView> createState() => _StallDetailViewState();
}

class _StallDetailViewState extends State<StallDetailView> {
  final _db = FirebaseFirestore.instance;
  late final _stall = _db.collection('stalls').doc(widget.stallId).snapshots();
  late final _menu = _db.collection('menuItems').where('stallId', isEqualTo: widget.stallId).snapshots();
  late final _orders = _db.collection('orders').where('stallId', isEqualTo: widget.stallId).snapshots();
  bool _isSaving = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _isSaving = true);
    try {
      await action();
      if (mounted) showAdminSnackBar(context, success);
    } catch (e) {
      if (mounted) showAdminSnackBar(context, 'Action failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setStatus(Map<String, dynamic> stall, String status) async {
    final name = stall['stallName'] ?? 'this stall';
    final isActivate = status == AccountStatus.active;
    final confirmed = await showAdminConfirm(
      context,
      title: isActivate ? 'Approve $name?' : 'Suspend $name?',
      message: isActivate
          ? 'The stall becomes visible to customers and can take orders once the vendor opens it.'
          : 'The stall is closed and hidden from customers until reinstated.',
      confirmText: isActivate ? 'Approve' : 'Suspend',
      isDestructive: !isActivate,
    );
    if (confirmed == null) return;
    await _run(
      () => AdminService.setStallStatus(stallId: widget.stallId, stall: stall, status: status),
      '$name is now ${status.toLowerCase()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stall,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final stall = snapshot.data!.data();
        if (stall == null) return const EmptyState('This stall no longer exists.');
        final status = stall['status'] ?? AccountStatus.active;
        final pickup = stall['pickupPoint'] as GeoPoint?;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                label: const Text('Back to stalls', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(stall['stallName'] ?? 'Unnamed Stall', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  StatusPill(status),
                  const SizedBox(width: 8),
                  StatusPill(stall['isOpen'] == true ? 'Open' : 'Closed'),
                ],
              ),
              const SizedBox(height: 24),
              _buildStats(),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        AdminCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 160,
                                  width: double.infinity,
                                  child: AdminNetworkImage(stall['imageUrl'], placeholderIcon: Icons.storefront),
                                ),
                              ),
                              const SizedBox(height: 16),
                              MetaRow('Program / org', (stall['program'] ?? '').isEmpty ? '—' : stall['program']),
                              const Divider(height: 1),
                              MetaRow('Category', (stall['category'] ?? '').isEmpty ? '—' : stall['category']),
                              const Divider(height: 1),
                              MetaRow('Operating hours', (stall['operatingHours'] ?? '').isEmpty ? '—' : stall['operatingHours']),
                              const Divider(height: 1),
                              MetaRow('Pickup pin', pickup == null
                                  ? 'Not pinned'
                                  : '${pickup.latitude.toStringAsFixed(5)}, ${pickup.longitude.toStringAsFixed(5)}'),
                              const Divider(height: 1),
                              MetaRow('Registered', formatDateTime(stall['createdAt'])),
                              const Divider(height: 1),
                              _OwnerRow(ownerId: stall['ownerId']),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildActions(stall, status),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: _buildMenu()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _orders,
      builder: (context, snapshot) {
        final orders = snapshot.data?.docs.map((d) => d.data()).toList() ?? [];
        final today = orders.where((o) => isToday(o['createdAt']) && o['status'] != OrderStatus.cancelled).toList();
        final active = orders.where((o) => OrderStatus.active.contains(o['status'])).length;
        final revenue = orders
            .where((o) => o['status'] == OrderStatus.delivered)
            .fold<double>(0, (total, o) => total + ((o['subtotal'] ?? o['totalPrice']) as num? ?? 0).toDouble());
        final cancelled = orders.where((o) => o['status'] == OrderStatus.cancelled).length;
        Widget stat(String label, String value) => Expanded(
              child: AdminCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
        return Row(
          children: [
            stat('Orders today', '${today.length}'),
            const SizedBox(width: 16),
            stat('In progress', '$active'),
            const SizedBox(width: 16),
            stat('Delivered sales', formatPeso(revenue)),
            const SizedBox(width: 16),
            stat('Cancelled', '$cancelled'),
          ],
        );
      },
    );
  }

  Widget _buildActions(Map<String, dynamic> stall, String status) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stall actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Open for orders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: const Text('Normally controlled by the vendor'),
            value: stall['isOpen'] == true,
            activeColor: Colors.amber,
            contentPadding: EdgeInsets.zero,
            onChanged: _isSaving || status != AccountStatus.active
                ? null
                : (v) => _run(() => AdminService.setStallOpen(widget.stallId, v), v ? 'Stall opened' : 'Stall closed'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (status != AccountStatus.active)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _setStatus(stall, AccountStatus.active),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: Text(status == AccountStatus.pending ? 'Approve stall' : 'Reinstate stall',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              if (status != AccountStatus.active && status != AccountStatus.suspended) const SizedBox(width: 16),
              if (status != AccountStatus.suspended)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _setStatus(stall, AccountStatus.suspended),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(status == AccountStatus.pending ? 'Reject stall' : 'Suspend stall',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return AdminCard(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _menu,
        builder: (context, snapshot) {
          final items = [...?snapshot.data?.docs]
            ..sort((a, b) => '${a.data()['name']}'.toLowerCase().compareTo('${b.data()['name']}'.toLowerCase()));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Menu (${items.length} items)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Turn an item off to hide it from customers as sold out.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              if (!snapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else if (items.isEmpty)
                const EmptyState('This stall has no menu items yet.')
              else
                ...items.map((doc) {
                  final item = doc.data();
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(width: 48, height: 48, child: AdminNetworkImage(item['imageUrl'], placeholderIcon: Icons.fastfood)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${item['category'] ?? ''} · ${formatPeso(item['price'])}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch(
                          value: item['isAvailable'] ?? true,
                          activeColor: Colors.amber,
                          onChanged: (v) => _run(
                            () => AdminService.setMenuItemAvailability(doc.id, v),
                            '${item['name']} ${v ? 'available' : 'marked sold out'}',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  final String? ownerId;
  const _OwnerRow({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    if (ownerId == null) return const MetaRow('Owner', 'Unknown (legacy stall)');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(ownerId).snapshots(),
      builder: (context, snapshot) {
        final owner = snapshot.data?.data();
        return MetaRow('Owner', owner == null ? '—' : '${owner['name'] ?? 'Unnamed'} (${owner['email'] ?? ''})');
      },
    );
  }
}
