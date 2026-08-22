import '../../domain/entities/stop_entity.dart';
import '../../domain/repositories/stops_repository.dart';
import '../datasources/stops_local_datasource.dart';
import '../datasources/stops_remote_datasource.dart';

/// Implementation of StopsRepository
class StopsRepositoryImpl implements StopsRepository {
  final StopsLocalDatasource _localDatasource;
  final StopsRemoteDatasource _remoteDatasource;

  StopsRepositoryImpl({
    StopsLocalDatasource? localDatasource,
    StopsRemoteDatasource? remoteDatasource,
  })  : _localDatasource = localDatasource ?? StopsLocalDatasource(),
        _remoteDatasource = remoteDatasource ?? StopsRemoteDatasource();

  @override
  Future<List<FavoriteStop>> getFavorites() => _localDatasource.getFavorites();

  @override
  Future<void> addFavorite(FavoriteStop stop) =>
      _localDatasource.insert(stop);

  @override
  Future<void> removeFavorite(String stopId) =>
      _localDatasource.delete(stopId);

  @override
  Future<void> updateFavorite(FavoriteStop stop) =>
      _localDatasource.update(stop);

  @override
  Future<int> nextPosition() => _localDatasource.nextPosition();

  @override
  Future<List<NearbyStop>> getNearbyStops(double latitude, double longitude) {
    return _remoteDatasource.getNearbyStops(
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<List<BusArrival>> getArrivals(FavoriteStop stop) =>
      _remoteDatasource.getArrivalsForStop(stop);

  @override
  Future<List<Station>> getStations() => _remoteDatasource.getStations();

  @override
  Future<List<StopLine>> getLinesByStop(String stopId) =>
      _remoteDatasource.getLinesByStop(stopId);

  @override
  Future<List<NearbyStop>> getLocatedStops(double latitude, double longitude) {
    return _remoteDatasource.getLocatedStops(
      latitude: latitude,
      longitude: longitude,
    );
  }
}
