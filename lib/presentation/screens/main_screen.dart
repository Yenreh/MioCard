import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/card_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/card_item.dart';
import '../../core/theme/app_theme.dart';

/// Main screen showing list of cards
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(cardsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Listen for refresh state changes
    ref.listen<CardsState>(cardsProvider, (previous, next) {
      print('>>> LISTENER: previous.error=${previous?.error}, next.error=${next.error}');
      
      // Show success snackbar when refresh succeeds
      if (next.lastRefreshSuccess && !previous!.lastRefreshSuccess) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.balanceUpdated),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      
      // Show error snackbar when refresh fails
      if (next.error != null && next.error != previous?.error) {
        print('>>> LISTENER: Showing error snackbar!');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.couldNotUpdateBalance),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // Clear error after a delay to avoid the snackbar being cleared
        Future.delayed(const Duration(milliseconds: 100), () {
          notifier.clearError();
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
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
                    // Settings button
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

            // Content
            if (state.isLoading && state.cards.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.cards.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(onCreateCard: () => context.push('/create'), l10n: l10n),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final card = state.cards[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: CardItemWidget(
                        card: card,
                        isRefreshing: state.refreshingCardId == card.id,
                        farePrice: settings.farePrice,
                        onRefreshClick: () =>
                            notifier.refreshCardBalance(card.id),
                        onEditClick: () => context.push('/edit/${card.id}'),
                        onDeleteClick: () => _showDeleteDialog(context, notifier, card, l10n),
                      ),
                    );
                  }, childCount: state.cards.length),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create'),
        tooltip: l10n.newCard,
        child: const Icon(Icons.add_rounded),
      ),
    );
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
