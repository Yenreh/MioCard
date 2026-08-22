import '../entities/stop_entity.dart';

/// Repository interface for stops and arrivals
abstract class StopsRepository {
  /// Stops saved by the user
  Future<List<FavoriteStop>> getFavorites();

  /// Save a stop, appending it to the end of the list
  Future<void> addFavorite(FavoriteStop stop);

  /// Remove a saved stop
  Future<void> removeFavorite(String stopId);

  /// Position to assign to the next saved stop
  Future<int> nextPosition();

  /// Stops around a position, with their upcoming buses
  Future<List<NearbyStop>> getNearbyStops(double latitude, double longitude);

  /// Upcoming buses for a saved stop
  Future<List<BusArrival>> getArrivals(FavoriteStop stop);

  /// MIO station catalog
  Future<List<Station>> getStations();

  /// Lines serving a stop
  Future<List<StopLine>> getLinesByStop(String stopId);

  /// Stops around a point, placed on the map where possible
  Future<List<NearbyStop>> getLocatedStops(double latitude, double longitude);
}
