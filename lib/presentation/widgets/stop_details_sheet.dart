import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/stops_provider.dart';
import 'stop_name_dialog.dart';

/// Details of a stop: the buses on their way and the lines serving it.
///
/// Opens from any stop list so a place can be checked without saving it.
class StopDetailsSheet extends ConsumerWidget {
  final NearbyStop stop;
  final double anchorLatitude;
  final double anchorLongitude;

  const StopDetailsSheet({
    super.key,
    required this.stop,
    required this.anchorLatitude,
    required this.anchorLongitude,
  });

  static Future<void> show(
    BuildContext context, {
    required NearbyStop stop,
    required double anchorLatitude,
    required double anchorLongitude,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StopDetailsSheet(
        stop: stop,
        anchorLatitude: anchorLatitude,
        anchorLongitude: anchorLongitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final lines = ref.watch(linesByStopProvider(stop.id));
    final isSaved =
        ref.watch(stopsProvider).favorites.any((f) => f.stopId == stop.id);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stop.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              l10n.metersAway(stop.distanceMeters.round()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (stop.arrivals.isEmpty)
              Text(
                l10n.noBusesComing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...stop.arrivals.take(6).map((arrival) {
                final minutes = arrival.minutesUntilArrival();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _LineChip(label: arrival.line),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          arrival.destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        minutes == 0
                            ? l10n.arrivingNow
                            : l10n.minutesShort(minutes),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
            Text(
              l10n.linesServing.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            lines.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => Text(
                l10n.noLinesForStop,
                style: theme.textTheme.bodySmall,
              ),
              data: (data) => data.isEmpty
                  ? Text(l10n.noLinesForStop, style: theme.textTheme.bodySmall)
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final line in data)
                          Tooltip(
                            message: line.name,
                            child: _LineChip(label: line.shortName),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaved
                    ? null
                    : () async {
                        final customName = await showStopNameDialog(
                          context,
                          title: l10n.saveAsFavorite,
                          realName: stop.name,
                        );
                        if (customName == null) return;

                        await ref.read(stopsProvider.notifier).addFavorite(
                              id: stop.id,
                              stopId: stop.id,
                              name: stop.name,
                              anchorLatitude: anchorLatitude,
                              anchorLongitude: anchorLongitude,
                              customName: customName,
                            );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                icon: Icon(
                  isSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                ),
                label: Text(
                  isSaved ? l10n.stopAlreadySaved : l10n.saveAsFavorite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  final String label;

  const _LineChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
