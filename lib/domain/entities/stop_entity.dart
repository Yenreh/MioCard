/// A bus expected to arrive at a stop
class BusArrival {
  final String line;
  final String destination;
  final DateTime arrivalTime;
  final String vehicleId;

  const BusArrival({
    required this.line,
    required this.destination,
    required this.arrivalTime,
    required this.vehicleId,
  });

  /// Minutes left until arrival, floored at zero
  int minutesUntilArrival([DateTime? now]) {
    final diff = arrivalTime.difference(now ?? DateTime.now()).inSeconds;
    return diff <= 0 ? 0 : (diff / 60).round();
  }
}

/// A stop found near a location, with its upcoming buses
class NearbyStop {
  final String id;
  final String name;
  final double distanceMeters;
  final List<BusArrival> arrivals;

  const NearbyStop({
    required this.id,
    required this.name,
    required this.distanceMeters,
    this.arrivals = const [],
  });
}

/// A stop saved by the user.
///
/// The arrivals API only accepts coordinates, so each favorite keeps the
/// position it was found from: querying a small radius around that anchor
/// brings the stop back from anywhere.
class FavoriteStop {
  final String id;
  final String name;
  final double anchorLatitude;
  final double anchorLongitude;
  final int position;

  const FavoriteStop({
    required this.id,
    required this.name,
    required this.anchorLatitude,
    required this.anchorLongitude,
    this.position = 0,
  });

  FavoriteStop copyWith({String? name, int? position}) {
    return FavoriteStop(
      id: id,
      name: name ?? this.name,
      anchorLatitude: anchorLatitude,
      anchorLongitude: anchorLongitude,
      position: position ?? this.position,
    );
  }
}

/// A MIO station from the public catalog
class Station {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const Station({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
