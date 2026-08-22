import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miocard/data/datasources/api_exception.dart';
import 'package:miocard/data/datasources/json_cache.dart';
import 'package:miocard/data/datasources/stops_remote_datasource.dart';
import 'package:miocard/domain/entities/stop_entity.dart';

const _arrivalsBody = '''
[{"idParada":"500800","nombreParada":"Plaza de Cayzedo A1",
  "distanciaMetros":119.52,
  "buses":[{"nombreLinea":"E21","nombreDestino":"Est. Universidades",
            "tiempoEstimadoDeSalida":1787429222000,"vehiculoId":"637001"},
           {"nombreLinea":"P27D","nombreDestino":"Av. Roosevelt-Capri",
            "tiempoEstimadoDeSalida":1787429500000,"vehiculoId":"1144001"}]},
 {"idParada":"500751","nombreParada":"La Ermita A2",
  "distanciaMetros":187.46,"buses":[]}]''';

const _stationsBody = '''
[{"id":1,"name":"Estación Alamos","address":"Av 3N - Cl 52N",
  "neighborhood":"Ciudad Los Alamos","commune":2,
  "longitude":-76.5133880103,"latitude":3.4842460459}]''';

StopsRemoteDatasource _datasource(http.Client client, {JsonCache? cache}) =>
    StopsRemoteDatasource(
      client: client,
      backoff: Duration.zero,
      cache: cache ?? JsonCache.noop(),
    );

void main() {
  group('StopsRemoteDatasource', () {
    test('parses nearby stops with their arrivals', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['latitud'], '3.4516');
        expect(request.url.queryParameters['radio'], '300');
        return http.Response(_arrivalsBody, 200);
      });

      final stops = await _datasource(client)
          .getNearbyStops(latitude: 3.4516, longitude: -76.532);

      expect(stops, hasLength(2));
      expect(stops.first.name, 'Plaza de Cayzedo A1');
      expect(stops.first.distanceMeters, closeTo(119.52, 0.01));
      expect(stops.first.arrivals, hasLength(2));
      expect(stops.first.arrivals.first.line, 'E21');
      expect(
        stops.first.arrivals.first.arrivalTime,
        DateTime.fromMillisecondsSinceEpoch(1787429222000),
      );
      expect(stops.last.arrivals, isEmpty);
    });

    test('caps the radius at what the service accepts', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response('[]', 200);
      });

      await _datasource(client).getNearbyStops(
        latitude: 3.4516,
        longitude: -76.532,
        radiusMeters: 5000,
      );

      expect(requested.queryParameters['radio'], '300');
    });

    test('reports service-level errors returned with HTTP 200', () async {
      final client = MockClient(
        (_) async => http.Response('{"error":"El radio no puede estar vacía."}', 200),
      );

      await expectLater(
        _datasource(client).getNearbyStops(latitude: 1, longitude: 1),
        throwsA(isA<ServerApiException>()),
      );
    });

    test('parses the lines serving a stop', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/linesByStop/512081'));
        return http.Response(
          '[{"lineId":282,"shortName":"P82","name":"TERMINAL CALIPSO"}]',
          200,
        );
      });

      final lines = await _datasource(client).getLinesByStop('512081');

      expect(lines, hasLength(1));
      expect(lines.first.shortName, 'P82');
    });

    test('retries transient failures once', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('Server Error', 500);
        return http.Response(_arrivalsBody, 200);
      });

      final stops = await _datasource(client)
          .getNearbyStops(latitude: 3.4516, longitude: -76.532);

      expect(calls, 2);
      expect(stops, hasLength(2));
    });

    test('places stops by trilaterating three distance readings', () async {
      // A stop 50 m north and 30 m east of the origin, seen from the
      // origin and from two vantage points 120 m away.
      const originLat = 3.4842;
      const originLon = -76.5134;
      const metresPerDegree = 111320.0;
      final lonScale = metresPerDegree * math.cos(originLat * math.pi / 180);

      String body(double distance) =>
          '[{"idParada":"1","nombreParada":"Target","distanciaMetros":'
          '$distance,"buses":[]}]';

      final client = MockClient((request) async {
        final lat = double.parse(request.url.queryParameters['latitud']!);
        final lon = double.parse(request.url.queryParameters['longitud']!);
        final vantageY = (lat - originLat) * metresPerDegree;
        final vantageX = (lon - originLon) * lonScale;
        final distance = math.sqrt(
          math.pow(30 - vantageX, 2) + math.pow(50 - vantageY, 2),
        );
        return http.Response(body(distance), 200);
      });

      final stops = await _datasource(client)
          .getLocatedStops(latitude: originLat, longitude: originLon);

      expect(stops, hasLength(1));
      final stop = stops.single;
      expect(stop.hasPosition, isTrue);
      expect(
        (stop.latitude! - originLat) * metresPerDegree,
        closeTo(50, 1),
      );
      expect((stop.longitude! - originLon) * lonScale, closeTo(30, 1));
    });

    test('keeps stops that only the first reading saw', () async {
      var call = 0;
      final client = MockClient((_) async {
        call++;
        // Only the origin sees the stop; the vantage points are empty.
        return http.Response(call == 1 ? _arrivalsBody : '[]', 200);
      });

      final stops = await _datasource(client)
          .getLocatedStops(latitude: 3.4516, longitude: -76.532);

      expect(stops, hasLength(2));
      expect(stops.every((s) => s.hasPosition), isFalse);
    });

    test('serves the station catalog from cache on the second call',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(_stationsBody, 200);
      });
      final cache = JsonCache();
      final datasource = _datasource(client, cache: cache);

      await datasource.getStations();
      final second = await datasource.getStations();

      expect(calls, 1);
      expect(second.single.name, 'Estación Alamos');
    });

    test('reuses a stop position instead of asking again', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final lat = double.parse(request.url.queryParameters['latitud']!);
        final lon = double.parse(request.url.queryParameters['longitud']!);
        const originLat = 3.4842;
        const originLon = -76.5134;
        const metresPerDegree = 111320.0;
        final lonScale = metresPerDegree * math.cos(originLat * math.pi / 180);
        final vantageY = (lat - originLat) * metresPerDegree;
        final vantageX = (lon - originLon) * lonScale;
        final distance = math.sqrt(
          math.pow(30 - vantageX, 2) + math.pow(50 - vantageY, 2),
        );
        return http.Response(
          '[{"idParada":"1","nombreParada":"Target","distanciaMetros":'
          '$distance,"buses":[]}]',
          200,
        );
      });
      final cache = JsonCache();
      final datasource = _datasource(client, cache: cache);

      final first = await datasource.getLocatedStops(
        latitude: 3.4842,
        longitude: -76.5134,
      );
      expect(calls, 3);
      expect(first.single.hasPosition, isTrue);

      // The position is known now, so the vantage points are skipped.
      final second = await datasource.getLocatedStops(
        latitude: 3.4842,
        longitude: -76.5134,
      );
      expect(calls, 4);
      expect(second.single.hasPosition, isTrue);
    });

    test('parses the station catalog', () async {
      final client = MockClient((_) async => http.Response(_stationsBody, 200));

      final stations = await _datasource(client).getStations();

      expect(stations, hasLength(1));
      expect(stations.first.name, 'Estación Alamos');
      expect(stations.first.latitude, closeTo(3.484246, 0.000001));
    });

    test('counts minutes until arrival', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final arrival = BusArrival(
        line: 'T31',
        destination: 'Universidades',
        arrivalTime: now.add(const Duration(seconds: 150)),
        vehicleId: '1001',
      );

      expect(arrival.minutesUntilArrival(now), 3);
      expect(
        BusArrival(
          line: 'T31',
          destination: 'Universidades',
          arrivalTime: now.subtract(const Duration(seconds: 30)),
          vehicleId: '1001',
        ).minutesUntilArrival(now),
        0,
      );
    });
  });
  group('FavoriteStop naming', () {
    const stop = FavoriteStop(
      id: '500800',
      stopId: '500800',
      name: 'Plaza de Cayzedo A1',
      anchorLatitude: 3.4516,
      anchorLongitude: -76.532,
    );

    test('shows the real name when there is no custom one', () {
      expect(stop.displayName, 'Plaza de Cayzedo A1');
      expect(stop.secondaryName, isNull);
    });

    test('shows the custom name with the real one behind it', () {
      final renamed = stop.copyWith(customName: 'Trabajo');

      expect(renamed.displayName, 'Trabajo');
      expect(renamed.secondaryName, 'Plaza de Cayzedo A1');
    });

    test('falls back to the real name when the custom one is cleared', () {
      final cleared =
          stop.copyWith(customName: 'Trabajo').copyWith(clearCustomName: true);

      expect(cleared.displayName, 'Plaza de Cayzedo A1');
      expect(cleared.secondaryName, isNull);
    });
  });
}
