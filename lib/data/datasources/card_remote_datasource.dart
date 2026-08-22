import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/card_balance_response.dart';
import 'api_exception.dart';

export 'api_exception.dart';

/// Remote data source for fetching card balance.
///
/// Uses two independent public sources:
/// - Primary: the Metrocali proxy used by the official MIO app. It queries
///   the Oracle backend server-side, so its query quota is not tied to the
///   user's IP.
/// - Fallback: the utryt web page endpoint. Rate limited per origin, but it
///   reports precise business errors (invalid card, no movements).
class CardRemoteDatasource {
  static const String _ctsUrl = 'https://metrocali.gov.co/cts/api/cts.php';
  static const String _utrytUrl =
      'https://www.utryt.com.co/saldo/script/saldo.php';

  static const Map<String, String> _ctsHeaders = {
    'Accept': 'application/json',
  };

  static const Map<String, String> _utrytHeaders = {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0',
    'Accept': 'text/plain, */*; q=0.01',
    'Accept-Language': 'en-US,en;q=0.5',
    'X-Requested-With': 'XMLHttpRequest',
    'Connection': 'keep-alive',
    'Referer': 'https://www.utryt.com.co/saldo/',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'same-origin',
  };

  static const int _maxAttempts = 3;
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _baseBackoff = Duration(seconds: 1);
  static const int _maxJitterMs = 500;

  final http.Client _client;
  final Random _random;
  final Duration _backoffBase;

  CardRemoteDatasource({
    http.Client? client,
    Random? random,
    Duration backoffBase = _baseBackoff,
  })  : _client = client ?? http.Client(),
        _random = random ?? Random(),
        _backoffBase = backoffBase;

  /// Fetch card balance, trying the primary source first and falling back
  /// to the secondary one when it fails.
  Future<CardBalanceResponse> getCardBalance(String cardId) async {
    try {
      return await _withRetries(() => _fetchFromCts(cardId));
    } on ApiException catch (primaryError) {
      try {
        return await _withRetries(() => _fetchFromUtryt(cardId));
      } on ApiException catch (fallbackError) {
        // The primary source cannot tell an invalid card from a backend
        // failure, so prefer the fallback when it identified the cause.
        if (fallbackError is InvalidCardApiException ||
            fallbackError is CardNotFoundApiException) {
          rethrow;
        }
        throw primaryError;
      }
    }
  }

  /// Run [request], retrying transient failures with exponential backoff.
  Future<CardBalanceResponse> _withRetries(
    Future<CardBalanceResponse> Function() request,
  ) async {
    ApiException? lastError;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_backoffFor(attempt));
      }
      try {
        return await request();
      } on ApiException catch (e) {
        if (!e.isRetryable) rethrow;
        lastError = e;
      }
    }

    throw lastError!;
  }

  Duration _backoffFor(int attempt) {
    final multiplier = 1 << (attempt - 1);
    final jitter = _random.nextInt(_maxJitterMs);
    return Duration(
      milliseconds: _backoffBase.inMilliseconds * multiplier + jitter,
    );
  }

  Future<http.Response> _get(Uri uri, Map<String, String> headers) async {
    final http.Response response;
    try {
      response =
          await _client.get(uri, headers: headers).timeout(_requestTimeout);
    } on TimeoutException {
      throw const NetworkApiException('Request timed out');
    } on http.ClientException catch (e) {
      throw NetworkApiException('Connection error: ${e.message}');
    }

    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw ServerApiException(
        'Server error: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw ServerApiException(
        'Unexpected status: ${response.statusCode}',
        statusCode: response.statusCode,
        isRetryable: false,
      );
    }

    return response;
  }

  /// Primary source: Metrocali proxy.
  ///
  /// Success: {"cardNumber": 1906051868981, "balance": 15300.0,
  ///           "balanceDate": 1785631011000, ...}
  /// Failure: {"error": "..."} with HTTP 200.
  Future<CardBalanceResponse> _fetchFromCts(String cardId) async {
    final response = await _get(
      Uri.parse('$_ctsUrl?numero=$cardId'),
      _ctsHeaders,
    );
    final payload = _decodeJsonObject(response.body);

    if (payload['error'] != null) {
      // The proxy collapses every upstream problem into one generic
      // message, so do not retry: let the fallback identify the cause.
      throw ServerApiException(
        'Proxy error: ${payload['error']}',
        isRetryable: false,
      );
    }

    return _toResponse(payload);
  }

  /// Fallback source: utryt web page endpoint.
  ///
  /// Returns HTTP 200 even for errors, as an Oracle ORDS error payload.
  Future<CardBalanceResponse> _fetchFromUtryt(String cardId) async {
    final response = await _get(
      Uri.parse('$_utrytUrl?card=$cardId'),
      _utrytHeaders,
    );
    final payload = _decodeJsonObject(response.body);

    if (payload['balance'] == null) {
      final cause = payload['cause']?.toString() ?? '';
      if (cause.contains('ORA-20001')) {
        throw const InvalidCardApiException(
          'Card number must have exactly 13 digits',
        );
      }
      if (cause.contains('ORA-20002')) {
        throw const CardNotFoundApiException(
          'No movements found for this card',
        );
      }
      // ORA-20003 wrapping ORA-20010: rate limited by origin. Retrying
      // immediately only makes it worse; the user must wait.
      if (cause.contains('ORA-20010')) {
        throw const RateLimitApiException(
          'Query limit exceeded for this origin',
        );
      }
      if (payload['code'] != null) {
        throw const ServerApiException('Service error');
      }
      throw const CardNotFoundApiException('Card not found');
    }

    return _toResponse(payload);
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Not a JSON object');
      }
      return decoded;
    } on FormatException {
      // HTML error page, empty body or any non-JSON payload: the service
      // is misbehaving, retrying may help.
      throw const ServerApiException('Unexpected response format');
    }
  }

  CardBalanceResponse _toResponse(Map<String, dynamic> payload) {
    final cardNumber = payload['cardNumber'];
    if (payload['balance'] is! num || cardNumber is! num || cardNumber <= 0) {
      throw const CardNotFoundApiException('Card not found');
    }
    return CardBalanceResponse.fromJson(payload);
  }
}
