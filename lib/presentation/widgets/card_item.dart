import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/card_entity.dart';
import '../../core/utils/date_utils.dart' as app_date;
import '../../l10n/app_localizations.dart';

/// Card item widget with modern credit card style design
class CardItemWidget extends StatelessWidget {
  final CardEntity card;
  final bool isRefreshing;
  final int farePrice;
  final VoidCallback onRefreshClick;
  final VoidCallback onEditClick;
  final VoidCallback onDeleteClick;

  const CardItemWidget({
    super.key,
    required this.card,
    required this.isRefreshing,
    required this.farePrice,
    required this.onRefreshClick,
    required this.onEditClick,
    required this.onDeleteClick,
  });

  /// Calculate available fares
  int get availableFares {
    if (card.balance == null || card.balance! <= 0 || farePrice <= 0) return 0;
    return (card.balance! / farePrice).floor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF667EEA),
            Color(0xFF764BA2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withAlpha(77),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(26),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(15),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Transport icon and action buttons
                  Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Transport icon
                    Container(
                      width: 45,
                      height: 35,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4CAF50),
                            Color(0xFF2E7D32),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_bus_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CardActionButton(
                          icon: isRefreshing ? null : Icons.refresh_rounded,
                          isLoading: isRefreshing,
                          onPressed: onRefreshClick,
                          tooltip: l10n.updateBalance,
                        ),
                        const SizedBox(width: 8),
                        _CardActionButton(
                          icon: Icons.edit_rounded,
                          onPressed: onEditClick,
                          tooltip: l10n.edit,
                        ),
                        const SizedBox(width: 8),
                        _CardActionButton(
                          icon: Icons.delete_rounded,
                          onPressed: onDeleteClick,
                          tooltip: l10n.delete,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Card Number
                Text(
                  _formatCardNumber(card.displayId),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                  ),
                ),

                const SizedBox(height: 16),

                // Bottom row: Name and Balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Card name and last update
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withAlpha(179),
                              letterSpacing: 1.5,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.name.toUpperCase(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Balance and fares
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.balance.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withAlpha(179),
                            letterSpacing: 1.5,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _BalanceDisplay(balance: card.balance),
                        if (card.balance != null && availableFares > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(38),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions_bus_rounded,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.fares(availableFares),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Last update text
                if (card.lastUpdate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.updatedAt(app_date.DateUtils.formatDateTime(card.lastUpdate!)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withAlpha(128),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Format card number with spaces for readability
  String _formatCardNumber(String number) {
    // Remove existing spaces
    final cleaned = number.replaceAll(' ', '');
    // Add space every 4 characters
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }
}

/// Action button styled for credit card UI
class _CardActionButton extends StatelessWidget {
  final IconData? icon;
  final bool isLoading;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isDestructive;

  const _CardActionButton({
    this.icon,
    this.isLoading = false,
    required this.onPressed,
    required this.tooltip,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.red.withAlpha(51)
                  : Colors.white.withAlpha(38),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 16,
                      color: isDestructive
                          ? const Color(0xFFFF6B6B)
                          : Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Balance display with colored text and currency formatting
class _BalanceDisplay extends StatelessWidget {
  final double? balance;

  const _BalanceDisplay({this.balance});

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (balance == null) {
      return Text(
        '---',
        style: theme.textTheme.titleLarge?.copyWith(
          color: Colors.white.withAlpha(128),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final isPositive = balance! >= 0;

    // Use bright colors that stand out on the gradient background
    final balanceColor = isPositive
        ? const Color(0xFF00FF88) // Bright green
        : const Color(0xFFFF6B6B); // Bright red

    return Text(
      _currencyFormat.format(balance),
      style: theme.textTheme.titleLarge?.copyWith(
        color: balanceColor,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }
}
