import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/campus_geofence.dart';
import '../core/app_theme.dart';
import 'custom_dialogs.dart';
import 'premium_paddling_boat.dart';

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.example.paddlerbites';

/// OpenStreetMap view of the campus with the geofence outline and optional
/// pickup (stall), drop-off (customer) and rider markers.
class CampusMap extends StatelessWidget {
  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? rider;
  final MapController? controller;
  final void Function(LatLng point)? onTap;

  const CampusMap({super.key, this.pickup, this.dropoff, this.rider, this.controller, this.onTap});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(bounds: CampusGeofence.bounds, padding: const EdgeInsets.all(32)),
        cameraConstraint: CameraConstraint.containCenter(bounds: CampusGeofence.cameraBounds),
        minZoom: 15,
        maxZoom: 19,
        onTap: onTap == null ? null : (_, point) => onTap!(point),
      ),
      children: [
        TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgent),
        PolygonLayer(
          polygons: [
            Polygon(
              points: CampusGeofence.boundary,
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderColor: AppTheme.secondaryColor,
              borderStrokeWidth: 2,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (pickup != null) _marker(pickup!, Icons.storefront, const Color(0xFF0D3B2E), AppTheme.primaryColor),
            if (dropoff != null) _pin(dropoff!),
            if (rider != null) Marker(point: rider!, width: 44, height: 44, child: const PremiumPaddlingBoatAnimation(size: 44)),
          ],
        ),
        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
      ],
    );
  }

  Marker _marker(LatLng point, IconData icon, Color bg, Color fg) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }

  Marker _pin(LatLng point) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: const Icon(Icons.location_on, color: AppTheme.secondaryColor, size: 44),
    );
  }
}

/// Full-screen pin picker. Pops with the chosen [LatLng]; pins outside the
/// campus boundary are rejected.
class CampusLocationPicker extends StatefulWidget {
  final String title;
  final LatLng? initial;
  final bool isPickup;

  const CampusLocationPicker({super.key, required this.title, this.initial, this.isPickup = false});

  @override
  State<CampusLocationPicker> createState() => _CampusLocationPickerState();
}

class _CampusLocationPickerState extends State<CampusLocationPicker> {
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  void _onTap(LatLng point) {
    if (!CampusGeofence.contains(point)) {
      showAppSnackBar(context, 'Pins must be inside the CSU Cabadbaran campus (outlined area).', isError: true);
      return;
    }
    setState(() => _selected = point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CampusMap(
            onTap: _onTap,
            pickup: widget.isPickup ? _selected : null,
            dropoff: widget.isPickup ? null : _selected,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    _selected == null
                        ? 'Tap a spot inside the outlined campus area.'
                        : 'Pinned at ${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: const Text('Confirm location', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
