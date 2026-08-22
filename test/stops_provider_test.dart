import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miocard/domain/entities/stop_entity.dart';
import 'package:miocard/domain/repositories/stops_repository.dart';
import 'package:miocard/presentation/providers/stops_provider.dart';

/// Repository that records how the arrivals were asked for
class _FakeStopsRepository implements StopsRepository {
  final List<FavoriteStop> favorites;
  final List<NearbyStop> nearby;

  int nearbyCalls = 0;
  int singleCalls = 0;

  _FakeStopsRepository({required this.favorites, required this.nearby});

  @override
  Future<List<FavoriteStop>> getFavorites() async => favorites;

  @override
  Future<List<NearbyStop>> getNearbyStops(double lat, double lon) async {
    nearbyCalls++;
    return nearby;
  }

  @override
  Future<List<BusArrival>> getArrivals(FavoriteStop stop) async {
    singleCalls++;
    return const [];
  }

  @override
  Future<void> addFavorite(FavoriteStop stop) async {}

  @override
  Future<void> removeFavorite(String stopId) async {}

  @override
  Future<void> updateFavorite(FavoriteStop stop) async {}

  @override
  Future<int> nextPosition() async => 0;

  @override
  Future<List<Station>> getStations() async => const [];

  @override
  Future<List<StopLine>> getLinesByStop(String stopId) async => const [];

  @override
  Future<List<NearbyStop>> getLocatedStops(double lat, double lon) async =>
      nearby;
}

FavoriteStop _favorite(String id, double lat, double lon) => FavoriteStop(
      id: id,
      stopId: id,
      name: 'Stop $id',
      anchorLatitude: lat,
      anchorLongitude: lon,
    );

NearbyStop _stop(String id, {List<BusArrival> arrivals = const []}) =>
    NearbyStop(id: id, name: 'Stop $id', distanceMeters: 10, arrivals: arrivals);

void main() {
  group('StopsNotifier.refreshArrivals', () {
    test('answers stops saved from the same place with one request',
        () async {
      final repository = _FakeStopsRepository(
        favorites: [
          // Two platforms saved from the same spot, one street away.
          _favorite('a', 3.4516, -76.5320),
          _favorite('b', 3.4516, -76.5320),
          _favorite('c', 3.4700, -76.5320),
        ],
        nearby: [_stop('a'), _stop('b'), _stop('c')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      repository.nearbyCalls = 0;
      repository.singleCalls = 0;
      await notifier.refreshArrivals(force: true);

      // Two clusters, and nothing had to be asked for on its own.
      expect(repository.nearbyCalls, 2);
      expect(repository.singleCalls, 0);
    });

    test('asks on its own for a stop the shared answer misses', () async {
      final repository = _FakeStopsRepository(
        favorites: [
          _favorite('a', 3.4516, -76.5320),
          _favorite('missing', 3.4516, -76.5320),
        ],
        nearby: [_stop('a')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      repository.nearbyCalls = 0;
      repository.singleCalls = 0;
      await notifier.refreshArrivals(force: true);

      expect(repository.nearbyCalls, 1);
      expect(repository.singleCalls, 1);
    });

    test('skips a refresh that follows another too closely', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.4516, -76.5320)],
        nearby: [_stop('a')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      repository.nearbyCalls = 0;
      repository.singleCalls = 0;
      await notifier.refreshArrivals(force: true);
      await notifier.refreshArrivals();

      expect(repository.nearbyCalls, 1);
    });
  });
}
