import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Campus boundary of Caraga State University – Cabadbaran Campus.
///
/// Taken from the campus outline on OpenStreetMap (Nominatim search
/// "Caraga State University Cabadbaran"). Every delivery pin and stall
/// pickup pin must fall inside this polygon.
class CampusGeofence {
  static const List<LatLng> boundary = [
    LatLng(9.1151186, 125.5331382),
    LatLng(9.1144012, 125.5348492),
    LatLng(9.1176721, 125.5362782),
    LatLng(9.1184187, 125.5345300),
  ];

  static const LatLng center = LatLng(9.1163954, 125.5346985);

  /// Where the live tracking maps open: CSU Cabadbaran Campus.
  static const LatLng focus = LatLng(9.1172, 125.5350);

  static LatLngBounds get bounds => LatLngBounds.fromPoints(boundary);

  /// Slightly larger area the map camera is allowed to pan within.
  static LatLngBounds get cameraBounds => LatLngBounds(
        const LatLng(9.1110, 125.5295),
        const LatLng(9.1220, 125.5400),
      );

  /// Ray-casting point-in-polygon test.
  static bool contains(LatLng point) {
    bool inside = false;
    for (int i = 0, j = boundary.length - 1; i < boundary.length; j = i++) {
      final a = boundary[i];
      final b = boundary[j];
      final crosses = (a.latitude > point.latitude) != (b.latitude > point.latitude);
      if (crosses &&
          point.longitude <
              (b.longitude - a.longitude) * (point.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Smallest zoom at which a [width]×[height] viewport still fits inside
  /// [bounds]. `CameraConstraint.contain` rejects every pan and zoom when the
  /// viewport is larger than its bounds, so a map's minZoom must not go below this.
  static double zoomToFill(LatLngBounds bounds, double width, double height) {
    double mercatorY(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
    // Size of the bounds in world pixels at zoom 0 (the whole world is 256 px).
    final worldWidth = (bounds.east - bounds.west) / 360 * 256;
    final worldHeight = (mercatorY(bounds.north) - mercatorY(bounds.south)) / (2 * math.pi) * 256;
    return math.max(math.log(width / worldWidth), math.log(height / worldHeight)) / math.ln2;
  }

  static LatLng? fromGeoPoint(GeoPoint? point) => point == null ? null : LatLng(point.latitude, point.longitude);

  static GeoPoint toGeoPoint(LatLng point) => GeoPoint(point.latitude, point.longitude);
}
