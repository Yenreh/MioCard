/// A bus expected to arrive at a stop
class BusArrival {
  final String line;
  final String destination;
  final DateTime arrivalTime;
  final String vehicleId;

  /// Stop the bus arrives at. A station spans several platforms, so an
  /// area favorite mixes arrivals from more than one stop.
  final String stopName;

  const BusArrival({
    required this.line,
    required this.destination,
    required this.arrivalTime,
    required this.vehicleId,
    this.stopName = '',
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

  /// Position worked out from several distance readings. Null when the
  /// stop was not seen from enough vantage points to place it.
  final double? latitude;
  final double? longitude;

  const NearbyStop({
    required this.id,
    required this.name,
    required this.distanceMeters,
    this.arrivals = const [],
    this.latitude,
    this.longitude,
  });

  bool get hasPosition => latitude != null && longitude != null;

  NearbyStop withPosition(double latitude, double longitude) {
    return NearbyStop(
      id: id,
      name: name,
      distanceMeters: distanceMeters,
      arrivals: arrivals,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

/// A stop saved by the user.
///
/// The arrivals API only accepts coordinates, so each favorite keeps the
/// position it was found from: querying a small radius around that anchor
/// brings the stop back from anywhere.
class FavoriteStop {
  final String id;

  /// Name the service reports for the stop
  final String name;

  /// Label the user gave it, shown instead of the real name
  final String? customName;
  final double anchorLatitude;
  final double anchorLongitude;
  final int position;

  /// Stop to follow. When null the favorite covers an area and gathers
  /// the arrivals of every stop around the anchor, which is what a
  /// station with several platforms needs.
  final String? stopId;

  const FavoriteStop({
    required this.id,
    required this.name,
    this.customName,
    required this.anchorLatitude,
    required this.anchorLongitude,
    this.position = 0,
    this.stopId,
  });

  bool get isArea => stopId == null;

  /// What to show as the title
  String get displayName => customName?.isNotEmpty == true ? customName! : name;

  /// The real name, only when a custom one is taking its place
  String? get secondaryName =>
      customName?.isNotEmpty == true ? name : null;

  FavoriteStop copyWith({
    String? name,
    int? position,
    String? customName,
    bool clearCustomName = false,
  }) {
    return FavoriteStop(
      id: id,
      name: name ?? this.name,
      customName: clearCustomName ? null : (customName ?? this.customName),
      anchorLatitude: anchorLatitude,
      anchorLongitude: anchorLongitude,
      position: position ?? this.position,
      stopId: stopId,
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

/// A line serving a stop
class StopLine {
  final String shortName;
  final String name;

  const StopLine({required this.shortName, required this.name});
}
