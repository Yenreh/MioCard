import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/card_item.dart';
import '../widgets/card_refresh_listener.dart';
import '../widgets/favorite_stop_card.dart';
import '../providers/stops_provider.dart';
import '../../core/theme/app_theme.dart';

/// Home dashboard: displays whatever the settings ask for.
///
/// Managing cards and stops lives in their own screens, reachable from
/// the button at the bottom.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  /// Repaints the countdowns between network refreshes
  Timer? _ticker;
  bool _watchingStops = false;

  /// Held so dispose does not have to reach for ref, which is unsafe
  /// once the widget is being unmounted.
  late final StopsNotifier _stopsNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stopsNotifier = ref.read(stopsProvider.notifier);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopWatchingStops();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do not poll the arrivals service while in the background.
    if (state == AppLifecycleState.resumed) {
      if (ref.read(settingsProvider).showsStops) {
        _startWatchingStops();
        _stopsNotifier.refreshArrivals();
      }
    } else {
      _stopWatchingStops();
    }
  }

  void _syncStopsWatch(bool shouldWatch) {
    if (shouldWatch == _watchingStops) return;
    shouldWatch ? _startWatchingStops() : _stopWatchingStops();
  }

  void _startWatchingStops() {
    _watchingStops = true;
    _stopsNotifier.startAutoRefresh();
    _ticker ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
  }

  void _stopWatchingStops() {
    _watchingStops = false;
    _stopsNotifier.stopAutoRefresh();
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardsProvider);
    final settings = ref.watch(settingsProvider);
    final stops = ref.watch(stopsProvider);
    final notifier = ref.read(cardsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final showsCards = settings.showsCards;
    final showsStops = settings.showsStops;
    final showsBoth = showsCards && showsStops;
    // Condensed cards leave room for the stops below them.
    final compactCards = showsBoth && state.cards.length > 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncStopsWatch(showsStops);
    });

    listenCardRefresh(context, ref, l10n);

    final isEmpty = (!showsCards || state.cards.isEmpty) &&
        (!showsStops || stops.favorites.isEmpty);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.manageCards,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (state.isLoading && state.cards.isEmpty && showsCards)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (isEmpty)
              SliverFillRemaining(
                child: _DashboardEmptyState(
                  l10n: l10n,
                  showsCards: showsCards,
                ),
              )
            else ...[
              if (showsCards) ...[
                if (showsBoth)
                  _SectionHeader(
                    title: l10n.myCards,
                    actionLabel: l10n.seeAll,
                    onAction: () => context.push('/cards'),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final card = state.cards[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: compactCards ? 10 : 16,
                        ),
                        child: CardItemWidget(
                          card: card,
                          isRefreshing: state.refreshingCardId == card.id,
                          refreshFailed: state.refreshFailedCardId == card.id,
                          farePrice: settings.farePrice,
                          compact: compactCards,
                          showManageActions: false,
                          onRefreshClick: () =>
                              notifier.refreshCardBalance(card.id),
                          onEditClick: () => context.push('/cards'),
                          onDeleteClick: () => context.push('/cards'),
                        ),
                      );
                    }, childCount: state.cards.length),
                  ),
                ),
              ],
              if (showsStops) ...[
                if (showsBoth)
                  _SectionHeader(
                    title: l10n.favoriteStops,
                    actionLabel: l10n.seeAll,
                    onAction: () => context.push('/stops'),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final stop = stops.favorites[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FavoriteStopCard(
                          stop: stop,
                          arrivals: stops.arrivals[stop.id],
                          l10n: l10n,
                        ),
                      );
                    }, childCount: stops.favorites.length),
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ],
        ),
      ),
      floatingActionButton: _ManageFab(l10n: l10n),
    );
  }
}

/// Section title with a link to the matching management screen
class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

/// Button that unfolds into the cards and the stops screens
class _ManageFab extends StatefulWidget {
  final AppLocalizations l10n;

  const _ManageFab({required this.l10n});

  @override
  State<_ManageFab> createState() => _ManageFabState();
}

class _ManageFabState extends State<_ManageFab> {
  bool _open = false;

  void _go(String route) {
    setState(() => _open = false);
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _FabAction(
          visible: _open,
          icon: Icons.signpost_rounded,
          label: l10n.favoriteStops,
          onPressed: () => _go('/stops'),
        ),
        _FabAction(
          visible: _open,
          icon: Icons.credit_card_rounded,
          label: l10n.myCards,
          onPressed: () => _go('/cards'),
        ),
        FloatingActionButton(
          onPressed: () => setState(() => _open = !_open),
          tooltip: _open ? l10n.cancel : l10n.manageCards,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

/// One of the choices that appear above the button
class _FabAction extends StatelessWidget {
  final bool visible;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _FabAction({
    required this.visible,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.4),
      duration: const Duration(milliseconds: 200),
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !visible,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(label, style: theme.textTheme.labelLarge),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: label,
                  onPressed: onPressed,
                  child: Icon(icon),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing to display yet, with a pointer to where things are managed
class _DashboardEmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final bool showsCards;

  const _DashboardEmptyState({required this.l10n, required this.showsCards});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              showsCards
                  ? Icons.credit_card_off_rounded
                  : Icons.signpost_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            showsCards ? l10n.noCards : l10n.noFavoriteStops,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            showsCards ? l10n.noCardsMessage : l10n.noFavoriteStopsMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
