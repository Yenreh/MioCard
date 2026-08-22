import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/stops_provider.dart';
import '../widgets/favorite_stop_card.dart';

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

  /// Held so dispose does not have to reach for ref, which is unsafe
  /// once the widget is being unmounted.
  late final StopsNotifier _notifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier = ref.read(stopsProvider.notifier);
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
      _notifier.refreshArrivals();
    } else {
      _stop();
    }
  }

  void _start() {
    _notifier.startAutoRefresh();
    _ticker ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
  }

  void _stop() {
    _notifier.stopAutoRefresh();
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
                      return FavoriteStopCard(
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
