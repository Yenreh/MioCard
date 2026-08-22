import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/stops_provider.dart';

/// Dashboard of favorite stops with their upcoming buses
class StopsScreen extends ConsumerStatefulWidget {
  const StopsScreen({super.key});

  @override
  ConsumerState<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends ConsumerState<StopsScreen>
    with WidgetsBindingObserver {
  /// Repaints the countdowns between network refreshes
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do not poll the arrivals service while in the background.
    if (state == AppLifecycleState.resumed) {
      _start();
      ref.read(stopsProvider.notifier).refreshArrivals();
    } else {
      _stop();
    }
  }

  void _start() {
    ref.read(stopsProvider.notifier).startAutoRefresh();
    _ticker ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
  }

  void _stop() {
    ref.read(stopsProvider.notifier).stopAutoRefresh();
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(stopsProvider);
    final notifier = ref.read(stopsProvider.notifier);

    ref.listen<StopsState>(stopsProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.couldNotLoadArrivals),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: l10n.retry,
              textColor: Colors.white,
              onPressed: notifier.refreshArrivals,
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favoriteStops),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: l10n.retry,
              onPressed: notifier.refreshArrivals,
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.favorites.isEmpty
              ? _EmptyState(l10n: l10n)
              : RefreshIndicator(
                  onRefresh: notifier.refreshArrivals,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: state.favorites.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final stop = state.favorites[index];
                      return _StopCard(
                        stop: stop,
                        arrivals: state.arrivals[stop.id],
                        l10n: l10n,
                        onRemove: () => notifier.removeFavorite(stop.id),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/stops/add'),
        tooltip: l10n.addStop,
        child: const Icon(Icons.add_location_alt_rounded),
      ),
    );
  }
}

/// One favorite stop with its next buses
class _StopCard extends StatelessWidget {
  final FavoriteStop stop;
  final List<BusArrival>? arrivals;
  final AppLocalizations l10n;
  final VoidCallback onRemove;

  const _StopCard({
    required this.stop,
    required this.arrivals,
    required this.l10n,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final list = arrivals;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.signpost_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stop.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.star_rounded),
                color: colorScheme.primary,
                tooltip: l10n.removeStop,
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (list.isEmpty)
            Text(
              l10n.noBusesComing,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...list.take(5).map(
                  (arrival) => _ArrivalRow(
                    arrival: arrival,
                    l10n: l10n,
                    showStopName: stop.isArea,
                  ),
                ),
        ],
      ),
    );
  }
}

/// A single line/destination/countdown row
class _ArrivalRow extends StatelessWidget {
  final BusArrival arrival;
  final AppLocalizations l10n;
  final bool showStopName;

  const _ArrivalRow({
    required this.arrival,
    required this.l10n,
    this.showStopName = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final minutes = arrival.minutesUntilArrival();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              arrival.line,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrival.destination,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showStopName && arrival.stopName.isNotEmpty)
                  Text(
                    arrival.stopName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            minutes == 0 ? l10n.arrivingNow : l10n.minutesShort(minutes),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: minutes <= 2 ? colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.signpost_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noFavoriteStops,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noFavoriteStopsMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
