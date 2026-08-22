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
  final List<FavoriteStop> saved = [];

  _FakeStopsRepository({required this.favorites, required this.nearby});

  @override
  Future<List<FavoriteStop>> getFavorites() async => favorites;

  @override
  Future<List<NearbyStop>> getNearbyStops(double lat, double lon) async {
    nearbyCalls++;
    return nearby;
  }

  @override
  Future<void> addFavorite(FavoriteStop stop) async {}

  @override
  Future<void> removeFavorite(String stopId) async {}

  @override
  Future<void> updateFavorite(FavoriteStop stop) async => saved.add(stop);

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

/// Let the load the notifier starts on its own finish, then reset the
/// state from the repository so a test counts only what it does itself.
Future<StopsNotifier> _readyNotifier(ProviderContainer container) async {
  final notifier = container.read(stopsProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  await notifier.loadFavorites();
  return notifier;
}

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
      await notifier.refreshArrivals(force: true);

      expect(repository.nearbyCalls, 2);
    });

    test('asks again only when the stop is anchored somewhere else',
        () async {
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
      await notifier.refreshArrivals(force: true);

      // The same anchor gives the same answer: asking twice is waste.
      expect(repository.nearbyCalls, 1);
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
      await notifier.refreshArrivals(force: true);
      await notifier.refreshArrivals();

      expect(repository.nearbyCalls, 1);
    });
  });

  group('StopsNotifier arrivals', () {
    test('hands each favorite the arrivals of its own stop', () async {
      final arrival = BusArrival(
        line: 'T31',
        destination: 'Universidades',
        arrivalTime: DateTime(2026, 1, 1, 12),
        vehicleId: '1',
        stopName: 'Stop a',
      );
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.4516, -76.5320)],
        nearby: [_stop('a', arrivals: [arrival]), _stop('b')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      await notifier.refreshArrivals(force: true);

      expect(container.read(stopsProvider).arrivals['a'], [arrival]);
    });

    test('an area favorite gathers every stop around its anchor', () async {
      final later = BusArrival(
        line: 'A1',
        destination: 'X',
        arrivalTime: DateTime(2026, 1, 1, 12, 5),
        vehicleId: '1',
      );
      final sooner = BusArrival(
        line: 'A2',
        destination: 'Y',
        arrivalTime: DateTime(2026, 1, 1, 12),
        vehicleId: '2',
      );
      final repository = _FakeStopsRepository(
        favorites: [
          const FavoriteStop(
            id: 'station-1',
            name: 'Station',
            anchorLatitude: 3.4516,
            anchorLongitude: -76.5320,
          ),
        ],
        nearby: [
          _stop('a', arrivals: [later]),
          _stop('b', arrivals: [sooner]),
        ],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      await notifier.refreshArrivals(force: true);

      // Both platforms, soonest first.
      expect(
        container.read(stopsProvider).arrivals['station-1'],
        [sooner, later],
      );
    });
  });

  group('StopsNotifier reconciliation', () {
    test('counts a stop the service stops reporting', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('gone', 3.4516, -76.5320)],
        nearby: [_stop('other')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = await _readyNotifier(container);
      repository.saved.clear();

      await notifier.refreshArrivals(force: true);
      expect(repository.saved.single.missingCount, 1);
      expect(container.read(stopsProvider).favorites.single.looksGone, isFalse);

      await notifier.refreshArrivals(force: true);
      await notifier.refreshArrivals(force: true);

      final favorite = container.read(stopsProvider).favorites.single;
      expect(favorite.missingCount, FavoriteStop.missingThreshold);
      expect(favorite.looksGone, isTrue);
    });

    test('picks up a stop that was renamed', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.4516, -76.5320)],
        nearby: const [
          NearbyStop(id: 'a', name: 'Kr 27 con Cl 122', distanceMeters: 5),
        ],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = await _readyNotifier(container);
      repository.saved.clear();
      await notifier.refreshArrivals(force: true);

      expect(repository.saved.single.name, 'Kr 27 con Cl 122');
      expect(
        container.read(stopsProvider).favorites.single.name,
        'Kr 27 con Cl 122',
      );
    });

    test('leaves a favorite alone while nothing changes', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.4516, -76.5320)],
        nearby: [_stop('a')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = await _readyNotifier(container);
      repository.saved.clear();
      await notifier.refreshArrivals(force: true);

      expect(repository.saved, isEmpty);
    });
  });
}
