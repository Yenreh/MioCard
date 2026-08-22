import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/stops_provider.dart';
import '../widgets/stop_details_sheet.dart';

/// Pick any place on the map and inspect the stops around it.
///
/// Tiles come from OpenStreetMap, which needs no API key.
class MapStopsScreen extends ConsumerStatefulWidget {
  const MapStopsScreen({super.key});

  /// Cali city centre, used until a position is known
  static const LatLng _caliCenter = LatLng(3.4516, -76.5320);

  @override
  ConsumerState<MapStopsScreen> createState() => _MapStopsScreenState();
}

class _MapStopsScreenState extends ConsumerState<MapStopsScreen> {
  final _mapController = MapController();
  MapPoint? _searched;
  String? _selectedStopId;
  bool _mapReady = false;
  bool _locating = false;
  double _rotation = 0;

  StreamSubscription<MapEvent>? _events;

  @override
  void initState() {
    super.initState();
    _centreOnDevice(askForPermission: false);
    // Rotation is only reported through the event stream, so the needle
    // follows the map as it turns instead of jumping at the end.
    _events = _mapController.mapEventStream.listen((event) {
      final rotation = event.camera.rotation;
      if (mounted && (rotation - _rotation).abs() > 0.1) {
        setState(() => _rotation = rotation);
      }
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Move to where the user is, staying on Cali when that is not known
  Future<void> _centreOnDevice({bool askForPermission = true}) async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final position = await currentDevicePosition(
        requestPermission: askForPermission,
      );
      if (!mounted || !_mapReady) return;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16,
      );
    } catch (_) {
      // No location: the map stays on the city centre.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _searchHere() {
    final center = _mapController.camera.center;
    setState(() {
      _searched = (latitude: center.latitude, longitude: center.longitude);
      _selectedStopId = null;
    });
  }

  /// Highlight a stop and bring the map to it
  void _focus(NearbyStop stop) {
    setState(() => _selectedStopId = stop.id);
    if (!stop.hasPosition || !_mapReady) return;

    _mapController.move(
      LatLng(stop.latitude!, stop.longitude!),
      _mapController.camera.zoom < 16 ? 17 : _mapController.camera.zoom,
    );
  }

  void _openDetails(NearbyStop stop, MapPoint point) {
    _focus(stop);
    StopDetailsSheet.show(
      context,
      stop: stop,
      anchorLatitude: point.latitude,
      anchorLongitude: point.longitude,
    );
  }

  /// One marker per placed stop, the selected one standing out
  List<Marker> _markers(
    BuildContext context,
    AsyncValue<List<NearbyStop>>? results,
  ) {
    final stops = results?.asData?.value;
    if (stops == null) return const [];

    final colorScheme = Theme.of(context).colorScheme;

    return [
      for (final stop in stops.where((s) => s.hasPosition))
        Marker(
          point: LatLng(stop.latitude!, stop.longitude!),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _openDetails(stop, _searched!),
            child: Icon(
              Icons.directions_bus_rounded,
              size: stop.id == _selectedStopId ? 34 : 24,
              color: stop.id == _selectedStopId
                  ? colorScheme.error
                  : colorScheme.primary,
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final point = _searched;
    final results = point == null ? null : ref.watch(stopsAtPointProvider(point));

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: MapStopsScreen._caliCenter,
                  initialZoom: 15,
                  minZoom: 11,
                  maxZoom: 18,
                  onMapReady: () => _mapReady = true,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.miocard',
                  ),
                  MarkerLayer(markers: _markers(context, results)),
                  // The tiles come from the OpenStreetMap Foundation and
                  // its data is ODbL: both ask to be credited on the map.
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    showFlutterMapAttribution: false,
                    animationConfig: const ScaleRAWA(),
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Crosshair marking the point that will be searched
              IgnorePointer(
                child: Icon(
                  Icons.location_on_rounded,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (_rotation.abs() > 0.5)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filled(
                    onPressed: () => _mapController.rotate(0),
                    tooltip: l10n.resetNorth,
                    icon: _CompassNeedle(rotationDegrees: _rotation),
                  ),
                ),
              // Compact and centred, so it hides as little map as
              // possible
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: _searchHere,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(l10n.searchHere),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: IconButton.filledTonal(
                  onPressed: _locating ? null : () => _centreOnDevice(),
                  tooltip: l10n.myLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: results == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.mapHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Text(l10n.couldNotLoadArrivals),
                  ),
                  data: (stops) => stops.isEmpty
                      ? Center(child: Text(l10n.noStopsNearby))
                      : ListView.builder(
                          itemCount: stops.length,
                          itemBuilder: (context, index) {
                            final stop = stops[index];
                            final lines = stop.arrivals
                                .map((a) => a.line)
                                .toSet()
                                .take(4)
                                .join(', ');
                            return ListTile(
                              leading: const Icon(Icons.signpost_rounded),
                              title: Text(stop.name),
                              subtitle: Text(
                                '${l10n.metersAway(stop.distanceMeters.round())}'
                                '${lines.isEmpty ? '' : ' · $lines'}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => StopDetailsSheet.show(
                                context,
                                stop: stop,
                                anchorLatitude: point!.latitude,
                                anchorLongitude: point.longitude,
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

/// Diamond whose coloured half points at true north
class _CompassNeedle extends StatelessWidget {
  final double rotationDegrees;

  const _CompassNeedle({required this.rotationDegrees});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Transform.rotate(
      angle: rotationDegrees * pi / 180,
      child: CustomPaint(
        size: const Size(16, 22),
        painter: _CompassPainter(
          north: colorScheme.error,
          south: colorScheme.onPrimary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final Color north;
  final Color south;

  const _CompassPainter({required this.north, required this.south});

  @override
  void paint(Canvas canvas, Size size) {
    final middleY = size.height / 2;
    final centreX = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    canvas.drawPath(
      ui.Path()
        ..moveTo(centreX, 0)
        ..lineTo(size.width, middleY)
        ..lineTo(0, middleY)
        ..close(),
      paint..color = north,
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(centreX, size.height)
        ..lineTo(size.width, middleY)
        ..lineTo(0, middleY)
        ..close(),
      paint..color = south,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) =>
      oldDelegate.north != north || oldDelegate.south != south;
}
