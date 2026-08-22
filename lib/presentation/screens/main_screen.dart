import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/card_entity.dart';
import '../../data/datasources/card_remote_datasource.dart';
import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/card_item.dart';
import '../widgets/favorite_stop_card.dart';
import '../providers/stops_provider.dart';
import '../../core/theme/app_theme.dart';

/// Main screen showing the cards, the favorite stops, or both
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
    // Condensed cards leave room for the stops below them.
    final compactCards = showsCards && showsStops && state.cards.length > 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncStopsWatch(showsStops);
    });

    // Listen for refresh state changes
    ref.listen<CardsState>(cardsProvider, (previous, next) {
      // Show success snackbar when refresh succeeds
      if (next.lastRefreshSuccess && !previous!.lastRefreshSuccess) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.balanceUpdated),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // Show typed error snackbar with retry action when refresh fails
      if (next.refreshError != null &&
          next.refreshError != previous?.refreshError) {
        final failedCardId = next.refreshFailedCardId;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_refreshErrorMessage(next.refreshError!, l10n)),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: failedCardId != null
                ? SnackBarAction(
                    label: l10n.retry,
                    textColor: Colors.white,
                    onPressed: () => notifier.refreshCardBalance(failedCardId),
                  )
                : null,
          ),
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          notifier.clearRefreshError();
        });
      }

      // Show error snackbar for non-refresh errors
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.couldNotUpdateBalance),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          notifier.clearError();
        });
      }
    });

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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/stops'),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.signpost_rounded,
                              color: colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                child: _EmptyState(
                  onCreateCard: () =>
                      context.push(showsCards ? '/create' : '/stops/add'),
                  l10n: l10n,
                ),
              )
            else ...[
              if (showsCards)
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
                          onRefreshClick: () =>
                              notifier.refreshCardBalance(card.id),
                          onEditClick: () => context.push('/edit/${card.id}'),
                          onDeleteClick: () =>
                              _showDeleteDialog(context, notifier, card, l10n),
                        ),
                      );
                    }, childCount: state.cards.length),
                  ),
                ),
              if (showsStops) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.favoriteStops,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/stops'),
                          child: Text(l10n.seeAll),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final stop = stops.favorites[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FavoriteStopCard(
                          stop: stop,
                          arrivals: stops.arrivals[stop.id],
                          l10n: l10n,
                          onRemove: () => ref
                              .read(stopsProvider.notifier)
                              .removeFavorite(stop.id),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(showsCards ? '/create' : '/stops/add'),
        tooltip: showsCards ? l10n.newCard : l10n.addStop,
        child: Icon(
          showsCards ? Icons.add_rounded : Icons.add_location_alt_rounded,
        ),
      ),
    );
  }

  /// Map a typed API error to a user-friendly localized message
  String _refreshErrorMessage(ApiException error, AppLocalizations l10n) {
    return switch (error) {
      NetworkApiException() => l10n.networkErrorMessage,
      ServerApiException() => l10n.serverErrorMessage,
      InvalidCardApiException() => l10n.invalidCardMessage,
      CardNotFoundApiException() => l10n.cardNotFoundMessage,
      RateLimitApiException() => l10n.rateLimitMessage,
      _ => l10n.couldNotUpdateBalance,
    };
  }

  void _showDeleteDialog(
      BuildContext context, CardsNotifier notifier, CardEntity card, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _DeleteDialog(
        cardName: card.name,
        l10n: l10n,
        onConfirm: () async {
          Navigator.of(dialogContext).pop();
          await notifier.deleteCardById(card.id);
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateCard;
  final AppLocalizations l10n;

  const _EmptyState({required this.onCreateCard, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: const Icon(
              Icons.credit_card_off_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.noCards,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noCardsMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onCreateCard,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.createFirstCard),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Delete confirmation dialog
class _DeleteDialog extends StatelessWidget {
  final String cardName;
  final AppLocalizations l10n;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _DeleteDialog({
    required this.cardName,
    required this.l10n,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: colorScheme.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.deleteCardTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.deleteCardMessage(cardName),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.delete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
