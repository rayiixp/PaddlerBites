import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:paddlerbites/services/rider_location_broadcaster.dart';

void main() {
  late StreamController<LatLng> gps;
  late List<LatLng> published;
  late DateTime now;
  late bool failUploads;
  late RiderLocationBroadcaster broadcaster;

  setUp(() {
    gps = StreamController<LatLng>();
    published = [];
    now = DateTime(2026, 9, 30, 12);
    failUploads = false;
    broadcaster = RiderLocationBroadcaster(
      orderId: 'order1',
      positionSource: () => gps.stream,
      publisher: (id, p) async {
        if (failUploads) throw Exception('offline');
        published.add(p);
      },
      clock: () => now,
    );
  });

  tearDown(() {
    broadcaster.dispose();
    gps.close();
  });

  const start = LatLng(9.1150, 125.5344);
  LatLng north(double meters) => const Distance().offset(start, meters, 0);

  test('publishes the first fix, then at most every 3 s unless the rider moved 20 m', () async {
    final local = <LatLng>[];
    broadcaster.positions.listen(local.add);
    await broadcaster.start();
    expect(broadcaster.status, LocationSharingStatus.sharing);

    gps.add(start);
    await pumpEventQueue();
    expect(published, [start]); // first fix goes out immediately

    now = now.add(const Duration(seconds: 1));
    gps.add(north(5));
    await pumpEventQueue();
    expect(published, hasLength(1)); // 1 s later and only 5 m: throttled

    now = now.add(const Duration(seconds: 1));
    gps.add(north(25));
    await pumpEventQueue();
    expect(published, hasLength(2)); // moved 25 m: sent right away

    now = now.add(const Duration(seconds: 3));
    gps.add(north(27));
    await pumpEventQueue();
    expect(published, hasLength(3)); // 3 s since the last upload

    // The rider's own map still gets every fix.
    expect(local, hasLength(4));
    expect(broadcaster.lastPosition, north(27));
  });

  test('keeps going when an upload fails and recovers on the next fix', () async {
    await broadcaster.start();
    failUploads = true;
    gps.add(start);
    await pumpEventQueue();
    expect(broadcaster.publishFailing, isTrue);

    failUploads = false;
    now = now.add(const Duration(seconds: 4));
    gps.add(north(10));
    await pumpEventQueue();
    expect(broadcaster.publishFailing, isFalse);
    expect(published, [north(10)]);
  });

  test('stop() ends sharing and no further fixes are uploaded', () async {
    await broadcaster.start();
    gps.add(start);
    await pumpEventQueue();
    await broadcaster.stop();
    expect(broadcaster.status, LocationSharingStatus.stopped);

    now = now.add(const Duration(seconds: 10));
    gps.add(north(50));
    await pumpEventQueue();
    expect(published, [start]);
  });
}
