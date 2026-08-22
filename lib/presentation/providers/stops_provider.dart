import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/datasources/api_exception.dart';
import '../../data/repositories/stops_repository_impl.dart';
import '../../domain/entities/stop_entity.dart';
import '../../domain/repositories/stops_repository.dart';

/// Provider for the stops repository
final stopsRepositoryProvider = Provider<StopsRepository>((ref) {
  return StopsRepositoryImpl();
});

/// State for the favorite stops dashboard
class StopsState {
  final List<FavoriteStop> favorites;
  final Map<String, List<BusArrival>> arrivals;
  final bool isLoading;
  final bool isRefreshing;
  final ApiException? error;
  final DateTime? lastUpdated;

  const StopsState({
    this.favorites = const [],
    this.arrivals = const {},
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.lastUpdated,
  });

  StopsState copyWith({
    List<FavoriteStop>? favorites,
    Map<String, List<BusArrival>>? arrivals,
    bool? isLoading,
    bool? isRefreshing,
    ApiException? error,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return StopsState(
      favorites: favorites ?? this.favorites,
      arrivals: arrivals ?? this.arrivals,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Favorite stops and their upcoming buses
class StopsNotifier extends Notifier<StopsState> {
  /// The arrivals service takes one request per point, so keep a few in
  /// flight at a time instead of firing all of them at once.
  static const int _maxConcurrentRequests = 4;
  static const Duration autoRefreshInterval = Duration(seconds: 30);

  /// One request covers every stop within 300 m of the point it asks
  /// about, so favorites saved from nearly the same place share it.
  static const double _clusterRadiusMetres = 30;

  /// Arrivals move slowly enough that answering twice in a few seconds
  /// only wastes data.
  static const Duration _minRefreshGap = Duration(seconds: 15);

  Timer? _timer;
  DateTime? _lastRefresh;

  StopsRepository get _repository => ref.read(stopsRepositoryProvider);

  @override
  StopsState build() {
    ref.onDispose(stopAutoRefresh);
    Future.microtask(loadFavorites);
    return const StopsState(isLoading: true);
  }

  /// Load saved stops and their arrivals
  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final favorites = await _sortByDistance(await _repository.getFavorites());
      state = state.copyWith(favorites: favorites, isLoading: false);
      if (favorites.isNotEmpty) await refreshArrivals();
    } on ApiException catch (e) {
      state = state.copyWith(error: e, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: ApiException(e.toString()),
        isLoading: false,
      );
    }
  }

  /// Put the closest stops first when the location is already known.
  ///
  /// Never asks for the permission here: the dashboard has to work
  /// without it, and only the nearby search is worth a prompt.
  Future<List<FavoriteStop>> _sortByDistance(List<FavoriteStop> stops) async {
    if (stops.length < 2) return stops;

    try {
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return stops;

      final position = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 8),
            ),
          );

      final sorted = [...stops]..sort((a, b) {
          final da = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            a.anchorLatitude,
            a.anchorLongitude,
          );
          final db = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            b.anchorLatitude,
            b.anchorLongitude,
          );
          return da.compareTo(db);
        });
      return sorted;
    } catch (_) {
      // Location is optional here: keep the order the user saved.
      return stops;
    }
  }

  /// Refresh the arrivals of every saved stop.
  ///
  /// Favorites anchored to nearly the same place are answered by a
  /// single request; a stop the shared answer does not mention is asked
  /// for on its own.
  Future<void> refreshArrivals({bool force = false}) async {
    if (state.isRefreshing || state.favorites.isEmpty) return;

    final last = _lastRefresh;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minRefreshGap) {
      return;
    }

    state = state.copyWith(isRefreshing: true, clearError: true);

    final results = Map<String, List<BusArrival>>.from(state.arrivals);
    final clusters = _clusterFavorites(state.favorites);
    ApiException? failure;

    for (var i = 0; i < clusters.length; i += _maxConcurrentRequests) {
      final batch = clusters.skip(i).take(_maxConcurrentRequests);
      await Future.wait(
        batch.map((cluster) async {
          try {
            final nearby = await _repository.getNearbyStops(
              cluster.first.anchorLatitude,
              cluster.first.anchorLongitude,
            );

            for (final favorite in cluster) {
              final arrivals = _arrivalsFor(favorite, nearby);
              if (arrivals != null) {
                results[favorite.id] = arrivals;
              } else {
                // Out of range of the shared point: ask on its own.
                results[favorite.id] = await _repository.getArrivals(favorite);
              }
            }
          } on ApiException catch (e) {
            failure ??= e;
          }
        }),
      );
    }

    _lastRefresh = DateTime.now();
    state = state.copyWith(
      arrivals: results,
      isRefreshing: false,
      error: failure,
      lastUpdated: DateTime.now(),
      clearError: failure == null,
    );
  }

  /// Group favorites that a single request can answer together
  List<List<FavoriteStop>> _clusterFavorites(List<FavoriteStop> stops) {
    final clusters = <List<FavoriteStop>>[];

    for (final stop in stops) {
      final match = clusters.where((cluster) {
        final head = cluster.first;
        return Geolocator.distanceBetween(
              head.anchorLatitude,
              head.anchorLongitude,
              stop.anchorLatitude,
              stop.anchorLongitude,
            ) <=
            _clusterRadiusMetres;
      }).firstOrNull;

      if (match != null) {
        match.add(stop);
      } else {
        clusters.add([stop]);
      }
    }

    return clusters;
  }

  /// Arrivals for [favorite] inside a shared answer, or null when that
  /// answer does not cover it
  List<BusArrival>? _arrivalsFor(
    FavoriteStop favorite,
    List<NearbyStop> nearby,
  ) {
    if (favorite.isArea) {
      return nearby.expand((s) => s.arrivals).toList()
        ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
    }

    for (final stop in nearby) {
      if (stop.id == favorite.stopId) return stop.arrivals;
    }
    return null;
  }

  /// Save a stop, or an area when [stopId] is null
  Future<void> addFavorite({
    required String id,
    required String name,
    required double anchorLatitude,
    required double anchorLongitude,
    String? stopId,
  }) async {
    final position = await _repository.nextPosition();
    await _repository.addFavorite(
      FavoriteStop(
        id: id,
        name: name,
        anchorLatitude: anchorLatitude,
        anchorLongitude: anchorLongitude,
        position: position,
        stopId: stopId,
      ),
    );
    await loadFavorites();
  }

  /// Restore stops from a backup, skipping the ones already saved
  Future<int> importFavorites(List<FavoriteStop> stops) async {
    var imported = 0;
    final existing = {for (final s in state.favorites) s.id};

    for (final stop in stops) {
      if (existing.contains(stop.id)) continue;
      await _repository.addFavorite(stop);
      imported++;
    }

    if (imported > 0) await loadFavorites();
    return imported;
  }

  /// Give a stop a label of its own, or drop it when [customName] is empty
  Future<void> renameFavorite(String id, String? customName) async {
    final stop = state.favorites.where((s) => s.id == id).firstOrNull;
    if (stop == null) return;

    final trimmed = customName?.trim();
    await _repository.updateFavorite(
      stop.copyWith(
        customName: trimmed,
        clearCustomName: trimmed == null || trimmed.isEmpty,
      ),
    );
    await loadFavorites();
  }

  /// Remove a saved stop
  Future<void> removeFavorite(String stopId) async {
    await _repository.removeFavorite(stopId);
    final arrivals = Map<String, List<BusArrival>>.from(state.arrivals)
      ..remove(stopId);
    state = state.copyWith(
      favorites: state.favorites.where((s) => s.id != stopId).toList(),
      arrivals: arrivals,
    );
  }

  /// Refresh arrivals periodically while the dashboard is on screen
  void startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(autoRefreshInterval, (_) => refreshArrivals());
  }

  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  void clearError() => state = state.copyWith(clearError: true);
}

/// Provider for the favorite stops dashboard
final stopsProvider = NotifierProvider<StopsNotifier, StopsState>(() {
  return StopsNotifier();
});

/// Raised when the device location cannot be read
class LocationUnavailableException implements Exception {
  final bool permanentlyDenied;

  const LocationUnavailableException({this.permanentlyDenied = false});
}

/// Current position, asking for permission the first time
Future<Position> _currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationUnavailableException();
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationUnavailableException(permanentlyDenied: true);
  }
  if (permission == LocationPermission.denied) {
    throw const LocationUnavailableException();
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

/// Stops around the user, with the position they were found from
typedef NearbyResult = ({List<NearbyStop> stops, double lat, double lon});

/// Stops near the device, refreshed on demand
final nearbyStopsProvider = FutureProvider.autoDispose<NearbyResult>((ref) async {
  final position = await _currentPosition();
  final stops = await ref
      .read(stopsRepositoryProvider)
      .getNearbyStops(position.latitude, position.longitude);
  return (
    stops: stops,
    lat: position.latitude,
    lon: position.longitude,
  );
});

/// MIO station catalog, used to add favorites without GPS
final stationsProvider = FutureProvider<List<Station>>((ref) async {
  return ref.read(stopsRepositoryProvider).getStations();
});

/// A point to look up stops around
typedef MapPoint = ({double latitude, double longitude});

/// Stops around an arbitrary point, so any place can be inspected
/// without saving it first
final stopsAtPointProvider =
    FutureProvider.autoDispose.family<List<NearbyStop>, MapPoint>(
  (ref, point) async {
    return ref
        .read(stopsRepositoryProvider)
        .getLocatedStops(point.latitude, point.longitude);
  },
);

/// Lines serving a stop
final linesByStopProvider =
    FutureProvider.autoDispose.family<List<StopLine>, String>((ref, stopId) {
  return ref.read(stopsRepositoryProvider).getLinesByStop(stopId);
});
