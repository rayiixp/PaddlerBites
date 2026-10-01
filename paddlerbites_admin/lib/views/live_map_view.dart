import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/admin_ui.dart';
import '../core/campus.dart';
import '../core/premium_paddling_boat.dart';

/// One delivery in progress, as shown on the live map.
class ActiveDelivery {
  final String orderId;
  final String riderName;
  final String stallName;
  final String status;
  final LatLng position;
  final LatLng? dropoff;
  final DateTime? updatedAt;

  const ActiveDelivery({
    required this.orderId,
    required this.riderName,
    required this.stallName,
    required this.status,
    required this.position,
    this.dropoff,
    this.updatedAt,
  });

  /// Null when the rider hasn't shared a position yet.
  static ActiveDelivery? fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rider = data['riderLocation'];
    if (rider is! GeoPoint) return null;
    final dropoff = data['deliveryPoint'];
    return ActiveDelivery(
      orderId: doc.id,
      riderName: data['deliveryPersonName'] ?? 'Rider',
      stallName: data['stallName'] ?? '',
      status: data['status'] ?? '',
      position: LatLng(rider.latitude, rider.longitude),
      dropoff: dropoff is GeoPoint ? LatLng(dropoff.latitude, dropoff.longitude) : null,
      updatedAt: toDate(data['riderLocationUpdatedAt']),
    );
  }
}

// -----------------------------------------------------------------------------
// LIVE MAP PAGE
// -----------------------------------------------------------------------------
/// Every delivery in progress (Picked up / On the way), streamed from
/// Firestore. Riders' phones write `orders/{id}.riderLocation` as they move.
class LiveMapView extends StatefulWidget {
  const LiveMapView({super.key});

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> {
  final _activeOrders = FirebaseFirestore.instance
      .collection('orders')
      .where('status', whereIn: [OrderStatus.pickedUp, OrderStatus.onTheWay])
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(title: 'Live map', subtitle: 'Deliveries in progress inside CSU Cabadbaran Campus'),
        const SizedBox(height: 24),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activeOrders,
              builder: (context, snapshot) {
                if (snapshot.hasError) return EmptyState('Could not load deliveries: ${snapshot.error}');
                final deliveries = (snapshot.data?.docs ?? []).map(ActiveDelivery.fromDoc).whereType<ActiveDelivery>().toList();
                return LiveDeliveriesMap(deliveries: deliveries, isLoading: !snapshot.hasData);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// LIVE DELIVERIES MAP
// -----------------------------------------------------------------------------
/// Satellite map locked to campus showing each active rider as the animated
/// PaddlerBites boat, with the trail travelled since this page was opened.
class LiveDeliveriesMap extends StatefulWidget {
  final List<ActiveDelivery> deliveries;
  final bool isLoading;

  const LiveDeliveriesMap({super.key, required this.deliveries, this.isLoading = false});

  @override
  State<LiveDeliveriesMap> createState() => _LiveDeliveriesMapState();
}

class _LiveDeliveriesMapState extends State<LiveDeliveriesMap> {
  static const double _minZoom = 16.5;
  static const double _maxZoom = 20.0;
  static const _esriImagery = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const _trailColor = Color(0xFFFC4C02);
  static const _distance = Distance();

  final _mapController = MapController();

  /// Positions seen per order, oldest first; drawn as trails.
  final Map<String, List<LatLng>> _trails = {};

  /// Lowest zoom the current viewport allows (see [build]).
  double _currentMinZoom = _minZoom;

  @override
  void initState() {
    super.initState();
    _recordPositions();
  }

  @override
  void didUpdateWidget(LiveDeliveriesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recordPositions();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Appends each rider's newest position and forgets finished deliveries.
  void _recordPositions() {
    final activeIds = widget.deliveries.map((d) => d.orderId).toSet();
    _trails.removeWhere((id, _) => !activeIds.contains(id));
    for (final d in widget.deliveries) {
      final trail = _trails.putIfAbsent(d.orderId, () => []);
      if (trail.isEmpty || trail.last != d.position) trail.add(d.position);
    }
  }

  double _trailMeters(String orderId) {
    final trail = _trails[orderId] ?? const [];
    var total = 0.0;
    for (var i = 1; i < trail.length; i++) {
      total += _distance.as(LengthUnit.Meter, trail[i - 1], trail[i]);
    }
    return total;
  }

  void _focus(ActiveDelivery d) => _mapController.move(d.position, math.max(_currentMinZoom, 18.5));

  void _recenter() => _mapController.move(Campus.center, math.max(_currentMinZoom, 17.5));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // `contain` freezes the map if the viewport is bigger than its bounds,
        // so on large screens the minimum zoom rises above 16.5 just enough to
        // fit. Rounded up to 0.25 so the map only rebuilds on real size changes.
        final fillZoom = Campus.zoomToFill(Campus.viewBounds, constraints.maxWidth, constraints.maxHeight);
        final minZoom = math.min(_maxZoom, math.max(_minZoom, (fillZoom * 4).ceil() / 4));
        _currentMinZoom = minZoom;

        return Stack(
          children: [
            FlutterMap(
              key: ValueKey(minZoom),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: Campus.center,
                initialZoom: math.max(minZoom, 17.5),
                minZoom: minZoom,
                maxZoom: _maxZoom,
                cameraConstraint: CameraConstraint.contain(bounds: Campus.viewBounds),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate: _esriImagery,
                  userAgentPackageName: 'ph.edu.csucc.paddlerbites.admin',
                  // Esri imagery tops out around 19 here; zoom 20 scales up those tiles.
                  maxNativeZoom: 19,
                  maxZoom: _maxZoom,
                ),
                // Geofence: the area riders are tracked in.
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: Campus.boundary,
                      color: AdminColors.accent.withValues(alpha: 0.12),
                      borderColor: AdminColors.accent,
                      borderStrokeWidth: 3,
                      pattern: StrokePattern.dashed(segments: const [14, 8]),
                    ),
                  ],
                ),
                // Trails travelled since this page opened.
                PolylineLayer(
                  polylines: [
                    for (final trail in _trails.values)
                      if (trail.length > 1)
                        Polyline(
                          points: trail,
                          strokeWidth: 5,
                          color: _trailColor,
                          borderStrokeWidth: 2,
                          borderColor: Colors.white.withValues(alpha: 0.7),
                        ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final d in widget.deliveries)
                      if (d.dropoff != null)
                        Marker(
                          point: d.dropoff!,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on, size: 36, color: Color(0xFFD66400), shadows: [Shadow(blurRadius: 6)]),
                        ),
                    for (final d in widget.deliveries)
                      Marker(point: d.position, width: 140, height: 76, child: _BoatMarker(name: d.riderName)),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('Powered by Esri'),
                    TextSourceAttribution('Esri, Maxar, Earthstar Geographics, and the GIS User Community'),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _DeliveriesPanel(
                deliveries: widget.deliveries,
                isLoading: widget.isLoading,
                trailMeters: _trailMeters,
                onSelect: _focus,
                onRecenter: _recenter,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Rider on the map: name tag above the animated paddling boat.
class _BoatMarker extends StatelessWidget {
  final String name;
  const _BoatMarker({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
          child: Text(name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        const PremiumPaddlingBoatAnimation(size: 44),
      ],
    );
  }
}

/// List of active deliveries overlaid on the map; tap one to fly to it.
class _DeliveriesPanel extends StatelessWidget {
  final List<ActiveDelivery> deliveries;
  final bool isLoading;
  final double Function(String orderId) trailMeters;
  final ValueChanged<ActiveDelivery> onSelect;
  final VoidCallback onRecenter;

  const _DeliveriesPanel({
    required this.deliveries,
    required this.isLoading,
    required this.trailMeters,
    required this.onSelect,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.kayaking, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLoading ? 'Loading deliveries…' : '${deliveries.length} active deliver${deliveries.length == 1 ? 'y' : 'ies'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              IconButton(
                tooltip: 'Recenter on campus',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.center_focus_strong, size: 20),
                onPressed: onRecenter,
              ),
            ],
          ),
          if (!isLoading && deliveries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No riders are delivering right now. They appear here once they pick up an order.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final d in deliveries)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelect(d),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.riderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  '${shortOrderId(d.orderId)} · ${d.stallName} · ${timeAgo(d.updatedAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusPill(d.status),
                              const SizedBox(height: 2),
                              Text('${trailMeters(d.orderId).round()} m', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
