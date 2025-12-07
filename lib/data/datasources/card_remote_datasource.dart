import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/card_balance_response.dart';

/// Remote data source for fetching card balance from API
class CardRemoteDatasource {
  static const String _baseUrl =
      'https://www.utryt.com.co/saldo/script/saldo.php';

  static const Map<String, String> _headers = {
    'Accept': 'text/plain, */*; q=0.01',
    'X-Requested-With': 'XMLHttpRequest',
    'User-Agent':
        'Mozilla/5.0 (Android 16; Mobile; rv:68.0) Gecko/68.0 Firefox/145.0',
  };

  final http.Client _client;

  CardRemoteDatasource({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch card balance from the MIO API
  Future<CardBalanceResponse> getCardBalance(String cardId) async {
    final uri = Uri.parse('$_baseUrl?card=$cardId');

    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));

      final body = response.body;
      final contentType = response.headers['content-type'] ?? '';

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Server error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // If the response is JSON or looks like JSON, decode it
      if (contentType.contains('application/json') ||
          body.trim().startsWith('{')) {
        final jsonData = json.decode(body) as Map<String, dynamic>;
        return CardBalanceResponse.fromJson(jsonData);
      }

      // Otherwise treat as text/HTML and extract the balance
      final extractedBalance = _extractBalanceFromText(body);
      return CardBalanceResponse.fromText(
        cardId: cardId,
        raw: body,
        balance: extractedBalance,
      );
    } on FormatException {
      throw const ApiException(message: 'Invalid response format');
    } on http.ClientException catch (e) {
      throw ApiException(message: 'Client error: ${e.message}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Attempt to extract a numeric balance value from HTML/text.
  double? _extractBalanceFromText(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Finds patterns like 12345 or 12.345 or 12,345 etc.
    final regex = RegExp(
      r'(?:(?:saldo|balance)\s*[:\-]?\s*)?(\d{1,3}(?:[.,]\d{3})+|\d+)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(cleaned);
    if (match == null) return null;

    var number = match.group(1)!;

    // Normalize formatting to parse as double
    number = number.replaceAll('.', '').replaceAll(',', '.');

    return double.tryParse(number);
  }
}

/// Exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException: $message';
}
