import '../../domain/entities/card_balance.dart';

/// API response model for card balance
class CardBalanceResponse {
  final double balance;
  final String cardNumber;
  final DateTime balanceDate;
  final String? raw; // Raw server response for debugging

  const CardBalanceResponse({
    required this.balance,
    required this.cardNumber,
    required this.balanceDate,
    this.raw,
  });

  /// Parse from API JSON response
  factory CardBalanceResponse.fromJson(Map<String, dynamic> json) {
    return CardBalanceResponse(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      cardNumber: json['cardNumber']?.toString() ?? '',
      balanceDate: json['balanceDate'] != null
          ? DateTime.tryParse(json['balanceDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      raw: json.toString(),
    );
  }

  /// Create from extracted text/HTML response
  factory CardBalanceResponse.fromText({
    required String cardId,
    required String raw,
    double? balance,
  }) {
    return CardBalanceResponse(
      balance: balance ?? 0.0,
      cardNumber: cardId,
      balanceDate: DateTime.now(),
      raw: raw,
    );
  }

  /// Convert to domain entity
  CardBalance toEntity() {
    return CardBalance(
      balance: balance,
      cardNumber: cardNumber,
      balanceDate: balanceDate,
    );
  }
}
