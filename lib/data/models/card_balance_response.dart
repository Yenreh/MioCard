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

  /// Parse from API JSON response.
  ///
  /// Expects a payload already validated by the datasource:
  /// numeric `balance` and `cardNumber` > 0.
  factory CardBalanceResponse.fromJson(Map<String, dynamic> json) {
    return CardBalanceResponse(
      balance: (json['balance'] as num).toDouble(),
      cardNumber: json['cardNumber'].toString(),
      balanceDate: _parseDate(json['balanceDate']),
      raw: json.toString(),
    );
  }

  /// Parse the balance date, which arrives as epoch milliseconds from the
  /// Metrocali proxy and as a date string from the utryt endpoint.
  static DateTime _parseDate(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
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
