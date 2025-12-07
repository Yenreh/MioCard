import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/card_entity.dart';
import '../../data/repositories/card_repository_impl.dart';
import '../../domain/repositories/card_repository.dart';

/// Provider for the card repository
final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepositoryImpl();
});

/// State class for cards list
class CardsState {
  final List<CardEntity> cards;
  final bool isLoading;
  final String? error;
  final String? refreshingCardId;
  final CardEntity? cardToDelete;
  final bool showDeleteDialog;
  final bool isDeletingCard;
  final bool lastRefreshSuccess;

  const CardsState({
    this.cards = const [],
    this.isLoading = false,
    this.error,
    this.refreshingCardId,
    this.cardToDelete,
    this.showDeleteDialog = false,
    this.isDeletingCard = false,
    this.lastRefreshSuccess = false,
  });

  CardsState copyWith({
    List<CardEntity>? cards,
    bool? isLoading,
    String? error,
    String? refreshingCardId,
    CardEntity? cardToDelete,
    bool? showDeleteDialog,
    bool? isDeletingCard,
    bool? lastRefreshSuccess,
    bool clearError = false,
    bool clearRefreshing = false,
    bool clearCardToDelete = false,
  }) {
    return CardsState(
      cards: cards ?? this.cards,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      refreshingCardId:
          clearRefreshing ? null : (refreshingCardId ?? this.refreshingCardId),
      cardToDelete:
          clearCardToDelete ? null : (cardToDelete ?? this.cardToDelete),
      showDeleteDialog: showDeleteDialog ?? this.showDeleteDialog,
      isDeletingCard: isDeletingCard ?? this.isDeletingCard,
      lastRefreshSuccess: lastRefreshSuccess ?? false,
    );
  }
}

/// Notifier for cards state management
class CardsNotifier extends Notifier<CardsState> {
  static const _uuid = Uuid();

  CardRepository get _repository => ref.read(cardRepositoryProvider);

  @override
  CardsState build() {
    // Load cards when provider is first accessed
    Future.microtask(() => loadCards());
    return const CardsState();
  }

  /// Load all cards
  Future<void> loadCards() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cards = await _repository.getAllCards();
      state = state.copyWith(cards: cards, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Create a new card
  Future<bool> createCard({
    required String id,
    required String name,
    String prefix = '',
    String suffix = '',
    int position = 0,
  }) async {
    try {
      final card = CardEntity(
        internalId: _uuid.v4(),
        id: id,
        name: name,
        prefix: prefix,
        suffix: suffix,
        position: position,
      );
      await _repository.createCard(card);
      await loadCards();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update an existing card
  Future<bool> updateCard(CardEntity card) async {
    try {
      await _repository.updateCard(card);
      await loadCards();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Refresh card balance from API
  Future<void> refreshCardBalance(String cardId) async {
    // Find the card to get full entity with prefix/suffix
    final card = state.cards.firstWhere(
      (c) => c.id == cardId,
      orElse: () => throw Exception('Card not found'),
    );

    state = state.copyWith(refreshingCardId: cardId, lastRefreshSuccess: false);
    try {
      final balance = await _repository.refreshCardBalance(card);
      await _repository.updateCardBalance(
          cardId, balance.balance, balance.balanceDate);
      await loadCards();
      state = state.copyWith(lastRefreshSuccess: true, clearRefreshing: true);
    } catch (e) {
      state = state.copyWith(error: e.toString(), clearRefreshing: true);
    }
  }

  /// Show delete confirmation dialog
  void showDeleteDialog(CardEntity card) {
    state = state.copyWith(cardToDelete: card, showDeleteDialog: true);
  }

  /// Hide delete dialog
  void hideDeleteDialog() {
    state = state.copyWith(showDeleteDialog: false, clearCardToDelete: true);
  }

  /// Delete card by ID directly
  Future<void> deleteCardById(String cardId) async {
    try {
      await _repository.deleteCard(cardId);
      await loadCards();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete card (after confirmation) - legacy method
  Future<void> deleteCard() async {
    final card = state.cardToDelete;
    if (card == null) return;

    state = state.copyWith(isDeletingCard: true);
    try {
      await _repository.deleteCard(card.id);
      state = state.copyWith(
        isDeletingCard: false,
        showDeleteDialog: false,
        clearCardToDelete: true,
      );
      await loadCards();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isDeletingCard: false,
        showDeleteDialog: false,
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Export all cards to JSON file and share
  Future<bool> exportCards() async {
    try {
      if (state.cards.isEmpty) {
        state = state.copyWith(error: 'No hay tarjetas para exportar');
        return false;
      }

      final cardsJson = state.cards.map((c) => c.toJson()).toList();
      final exportData = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'cards': cardsJson,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/miocard_backup.json');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'MIOCard Backup',
        ),
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al exportar: $e');
      return false;
    }
  }

  /// Import cards from JSON file
  Future<int> importCards() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return 0;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = json.decode(jsonString) as Map<String, dynamic>;

      final cardsList = data['cards'] as List<dynamic>;
      int importedCount = 0;

      for (final cardJson in cardsList) {
        final card = CardEntity.fromJson(cardJson as Map<String, dynamic>);
        
        // Check if card with same ID already exists
        final exists = state.cards.any((c) => c.id == card.id);
        if (!exists) {
          // Generate new internal ID to avoid conflicts
          final newCard = card.copyWith(internalId: _uuid.v4());
          await _repository.createCard(newCard);
          importedCount++;
        }
      }

      await loadCards();
      return importedCount;
    } catch (e) {
      state = state.copyWith(error: 'Error al importar: $e');
      return -1;
    }
  }
}

/// Provider for cards state
final cardsProvider = NotifierProvider<CardsNotifier, CardsState>(() {
  return CardsNotifier();
});
