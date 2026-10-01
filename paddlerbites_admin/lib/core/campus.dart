import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Caraga State University – Cabadbaran Campus.
///
/// Same outline as the mobile app's geofence (`lib/core/campus_geofence.dart`),
/// taken from the campus boundary on OpenStreetMap.
class Campus {
  static const List<LatLng> boundary = [
    LatLng(9.1151186, 125.5331382),
    LatLng(9.1144012, 125.5348492),
    LatLng(9.1176721, 125.5362782),
    LatLng(9.1184187, 125.5345300),
  ];

  /// Centre of the outline's bounding box.
  static const LatLng center = LatLng(9.1164100, 125.5347082);

  static LatLngBounds get bounds => LatLngBounds.fromPoints(boundary);

  /// Area the admin map may show: the campus plus a margin (~350 m) so the
  /// surrounding streets are visible, but no further.
  static LatLngBounds get viewBounds => LatLngBounds(
        const LatLng(9.1112, 125.5300),
        const LatLng(9.1216, 125.5394),
      );

  /// Ray-casting point-in-polygon test.
  static bool contains(LatLng point) {
    bool inside = false;
    for (int i = 0, j = boundary.length - 1; i < boundary.length; j = i++) {
      final a = boundary[i];
      final b = boundary[j];
      if ((a.latitude > point.latitude) != (b.latitude > point.latitude) &&
          point.longitude <
              (b.longitude - a.longitude) * (point.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Smallest zoom at which a [width]×[height] viewport still fits inside
  /// [bounds]. `CameraConstraint.contain` rejects every camera move when the
  /// viewport is larger than its bounds, so the map's minZoom must not go
  /// below this.
  static double zoomToFill(LatLngBounds bounds, double width, double height) {
    double mercatorY(double lat) {
      final rad = lat * math.pi / 180;
      return math.log(math.tan(math.pi / 4 + rad / 2));
    }

    // Size of the bounds in "world units" (the whole world is 256 px at zoom 0).
    final worldWidth = (bounds.east - bounds.west) / 360 * 256;
    final worldHeight = (mercatorY(bounds.north) - mercatorY(bounds.south)) / (2 * math.pi) * 256;
    final zoomForWidth = math.log(width / worldWidth) / math.ln2;
    final zoomForHeight = math.log(height / worldHeight) / math.ln2;
    return math.max(zoomForWidth, zoomForHeight);
  }
}
