import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/stops_provider.dart';
import '../widgets/stop_details_sheet.dart';
import 'map_stops_screen.dart';
import 'station_stops_screen.dart';

/// Add a favorite stop, either from nearby stops or from the station catalog
class AddStopScreen extends ConsumerStatefulWidget {
  const AddStopScreen({super.key});

  @override
  ConsumerState<AddStopScreen> createState() => _AddStopScreenState();
}

class _AddStopScreenState extends ConsumerState<AddStopScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.addStop),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.nearbyStops),
              Tab(text: l10n.mapTab),
              Tab(text: l10n.stationCatalog),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NearbyTab(l10n: l10n),
            const MapStopsScreen(),
            _StationsTab(
              l10n: l10n,
              controller: _searchController,
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stops around the device, with the buses coming to each
class _NearbyTab extends ConsumerWidget {
  final AppLocalizations l10n;

  const _NearbyTab({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(nearbyStopsProvider);

    return nearby.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Message(
        icon: Icons.location_off_rounded,
        text: error is LocationUnavailableException
            ? (error.permanentlyDenied
                ? l10n.locationDeniedForever
                : l10n.locationUnavailable)
            : l10n.couldNotLoadArrivals,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(nearbyStopsProvider),
      ),
      data: (result) {
        if (result.stops.isEmpty) {
          return _Message(
            icon: Icons.signpost_rounded,
            text: l10n.noStopsNearby,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(nearbyStopsProvider),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(nearbyStopsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: result.stops.length,
            itemBuilder: (context, index) {
              final stop = result.stops[index];
              return ListTile(
                leading: const Icon(Icons.signpost_rounded),
                title: Text(stop.name),
                subtitle: Text(
                  '${l10n.metersAway(stop.distanceMeters.round())}'
                  '${stop.arrivals.isEmpty ? '' : ' · ${stop.arrivals.map((a) => a.line).toSet().take(4).join(', ')}'}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => StopDetailsSheet.show(
                  context,
                  stop: stop,
                  anchorLatitude: result.lat,
                  anchorLongitude: result.lon,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Searchable MIO station catalog, no location permission needed
class _StationsTab extends ConsumerWidget {
  final AppLocalizations l10n;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _StationsTab({
    required this.l10n,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.searchStation,
              prefixIcon: const Icon(Icons.search_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: stations.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _Message(
              icon: Icons.cloud_off_rounded,
              text: l10n.couldNotLoadArrivals,
              actionLabel: l10n.retry,
              onAction: () => ref.invalidate(stationsProvider),
            ),
            data: (all) {
              final needle = query.trim().toLowerCase();
              final filtered = needle.isEmpty
                  ? all
                  : all
                      .where((s) =>
                          s.name.toLowerCase().contains(needle) ||
                          s.address.toLowerCase().contains(needle))
                      .toList(growable: false);

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final Station station = filtered[index];
                  return ListTile(
                    leading: const Icon(Icons.directions_bus_rounded),
                    title: Text(station.name),
                    subtitle: Text(station.address),
                    trailing: const Icon(Icons.star_outline_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StationStopsScreen(station: station),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
