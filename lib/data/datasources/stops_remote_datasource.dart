import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/stop_entity.dart';
import 'api_exception.dart';

/// Remote data source for stops, arrivals and the station catalog.
class StopsRemoteDatasource {
  static const String _arrivalsUrl =
      'https://servicios.siur.com.co/buscarutas/api/paradas_con_buses_proximos_a_llegar.php';
  static const String _stationsUrl =
      'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/stations';

  /// The arrivals service rejects anything above this radius.
  static const int maxRadiusMeters = 300;

  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _maxAttempts = 2;

  final http.Client _client;
  final Duration _backoff;

  StopsRemoteDatasource({
    http.Client? client,
    Duration backoff = const Duration(milliseconds: 600),
  })  : _client = client ?? http.Client(),
        _backoff = backoff;

  /// Stops within [radiusMeters] of a position, each with its next buses.
  Future<List<NearbyStop>> getNearbyStops({
    required double latitude,
    required double longitude,
    int radiusMeters = maxRadiusMeters,
  }) async {
    final radius =
        radiusMeters > maxRadiusMeters ? maxRadiusMeters : radiusMeters;
    final uri = Uri.parse(
      '$_arrivalsUrl?latitud=$latitude&longitud=$longitude&radio=$radius',
    );

    final decoded = await _getJson(uri);

    if (decoded is Map && decoded['error'] != null) {
      throw ServerApiException('Arrivals service: ${decoded['error']}');
    }
    if (decoded is! List) {
      throw const ServerApiException('Unexpected arrivals response');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_parseStop)
        .toList(growable: false);
  }

  /// Upcoming buses for a single stop, queried around its saved anchor.
  Future<List<BusArrival>> getArrivalsForStop(FavoriteStop stop) async {
    final stops = await getNearbyStops(
      latitude: stop.anchorLatitude,
      longitude: stop.anchorLongitude,
    );
    for (final nearby in stops) {
      if (nearby.id == stop.id) return nearby.arrivals;
    }
    // The stop is reachable but has no buses coming right now.
    return const [];
  }

  /// The full MIO station catalog, used to add favorites without GPS.
  Future<List<Station>> getStations() async {
    final decoded = await _getJson(Uri.parse(_stationsUrl));

    if (decoded is! List) {
      throw const ServerApiException('Unexpected stations response');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .where((s) => s['latitude'] is num && s['longitude'] is num)
        .map(
          (s) => Station(
            id: (s['id'] as num).toInt(),
            name: s['name']?.toString() ?? '',
            address: s['address']?.toString() ?? '',
            latitude: (s['latitude'] as num).toDouble(),
            longitude: (s['longitude'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  NearbyStop _parseStop(Map<String, dynamic> json) {
    final buses = json['buses'];
    return NearbyStop(
      id: json['idParada']?.toString() ?? '',
      name: json['nombreParada']?.toString() ?? '',
      distanceMeters: (json['distanciaMetros'] as num?)?.toDouble() ?? 0,
      arrivals: buses is List
          ? buses
              .whereType<Map<String, dynamic>>()
              .where((b) => b['tiempoEstimadoDeSalida'] is num)
              .map(
                (b) => BusArrival(
                  line: b['nombreLinea']?.toString() ?? '',
                  destination: b['nombreDestino']?.toString() ?? '',
                  arrivalTime: DateTime.fromMillisecondsSinceEpoch(
                    (b['tiempoEstimadoDeSalida'] as num).toInt(),
                  ),
                  vehicleId: b['vehiculoId']?.toString() ?? '',
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }

  /// GET [uri] and decode its JSON body, retrying transient failures once.
  Future<dynamic> _getJson(Uri uri) async {
    ApiException? lastError;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_backoff);
      try {
        final http.Response response;
        try {
          response = await _client.get(uri).timeout(_requestTimeout);
        } on TimeoutException {
          throw const NetworkApiException('Request timed out');
        } on http.ClientException catch (e) {
          throw NetworkApiException('Connection error: ${e.message}');
        }

        if (response.statusCode == 429 || response.statusCode >= 500) {
          throw ServerApiException(
            'Server error: ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }
        if (response.statusCode != 200) {
          throw ServerApiException(
            'Unexpected status: ${response.statusCode}',
            statusCode: response.statusCode,
            isRetryable: false,
          );
        }

        try {
          return json.decode(response.body);
        } on FormatException {
          throw const ServerApiException('Unexpected response format');
        }
      } on ApiException catch (e) {
        if (!e.isRetryable) rethrow;
        lastError = e;
      }
    }

    throw lastError!;
  }
}
