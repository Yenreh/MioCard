import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _searchHere() {
    final center = _mapController.camera.center;
    setState(() {
      _searched = (latitude: center.latitude, longitude: center.longitude);
      _selectedStopId = null;
    });
  }

  Future<void> _saveArea() async {
    final l10n = AppLocalizations.of(context)!;
    final center = _mapController.camera.center;
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.saveThisArea),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.areaName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    await ref.read(stopsProvider.notifier).addFavorite(
          id: 'area:${center.latitude},${center.longitude}',
          name: name,
          anchorLatitude: center.latitude,
          anchorLongitude: center.longitude,
        );

    if (mounted) Navigator.of(context).pop();
  }

  void _select(NearbyStop stop, MapPoint point) {
    setState(() => _selectedStopId = stop.id);
    if (stop.hasPosition) {
      _mapController.move(
        LatLng(stop.latitude!, stop.longitude!),
        _mapController.camera.zoom,
      );
    }
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
            onTap: () => _select(stop, _searched!),
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
                options: const MapOptions(
                  initialCenter: MapStopsScreen._caliCenter,
                  initialZoom: 15,
                  minZoom: 11,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.miocard',
                  ),
                  MarkerLayer(markers: _markers(context, results)),
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
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _searchHere,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(l10n.searchHere),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _saveArea,
                      tooltip: l10n.saveThisArea,
                      icon: const Icon(Icons.star_outline_rounded),
                    ),
                  ],
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
