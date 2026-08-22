import 'package:flutter/material.dart';

import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';

/// One favorite stop with its next buses
class FavoriteStopCard extends StatelessWidget {
  final FavoriteStop stop;
  final List<BusArrival>? arrivals;
  final AppLocalizations l10n;
  /// Removing lives in the stops screen; null hides the action
  final VoidCallback? onRemove;

  /// Renaming lives in the stops screen too; null hides the action
  final VoidCallback? onRename;

  const FavoriteStopCard({
    super.key,
    required this.stop,
    required this.arrivals,
    required this.l10n,
    this.onRemove,
    this.onRename,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (stop.secondaryName != null)
                      Text(
                        stop.secondaryName!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onRename != null)
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  color: colorScheme.onSurfaceVariant,
                  tooltip: l10n.editStop,
                  onPressed: onRename,
                ),
              if (onRemove != null)
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
