import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miocard/data/datasources/api_exception.dart';
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

StopsRemoteDatasource _datasource(http.Client client) =>
    StopsRemoteDatasource(client: client, backoff: Duration.zero);

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

    test('picks the arrivals of the requested stop only', () async {
      final client = MockClient((_) async => http.Response(_arrivalsBody, 200));

      final arrivals = await _datasource(client).getArrivalsForStop(
        const FavoriteStop(
          id: '500751',
          name: 'La Ermita A2',
          anchorLatitude: 3.4516,
          anchorLongitude: -76.532,
        ),
      );

      expect(arrivals, isEmpty);
    });

    test('returns no arrivals when the stop is out of range', () async {
      final client = MockClient((_) async => http.Response(_arrivalsBody, 200));

      final arrivals = await _datasource(client).getArrivalsForStop(
        const FavoriteStop(
          id: '999999',
          name: 'Unknown',
          anchorLatitude: 3.4516,
          anchorLongitude: -76.532,
        ),
      );

      expect(arrivals, isEmpty);
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
}
