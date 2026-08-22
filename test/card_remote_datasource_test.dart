import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miocard/data/datasources/card_remote_datasource.dart';

/// Random without jitter so retries are instant in tests.
class _NoJitterRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

const _card = '1906051868981';

/// Metrocali proxy (primary source) success payload.
const _ctsSuccessBody = '{"cardNumber":1906051868981,"cd_id":6,'
    '"crd_snr":5186898,"tsn":525,"balance":15300.0,'
    '"balanceDate":1785631011000}';

const _ctsErrorBody = '{"error":"Error al consultar la API externa"}';

/// utryt (fallback source) success payload.
const _utrytSuccessBody = '{"cardNumber": 1906051868981, "balance": 5000, '
    '"balanceDate": "2024-01-15 10:30:00"}';

String _ordsError(String cause) =>
    '{"code": "UserDefinedResourceError", "o:errorCode": "ORDS-25001", '
    '"cause": "SQL Error. $cause"}';

final _invalidCardBody = _ordsError(
  'ORA-20001: El numero TISC debe tener exactamente 13 digitos',
);
final _noMovementsBody = _ordsError(
  'ORA-20002: No se encontraron movimientos para la tarjeta',
);
final _rateLimitedBody = _ordsError(
  'ORA-20003: Error inesperado: ORA-20010: Limite de consultas excedido '
  'para este origen',
);

/// Counts calls per source and serves the configured responses.
class _Sources {
  int ctsCalls = 0;
  int utrytCalls = 0;

  final Future<http.Response> Function(int call)? cts;
  final Future<http.Response> Function(int call)? utryt;

  _Sources({this.cts, this.utryt});

  MockClient get client => MockClient((request) async {
        if (request.url.host.contains('metrocali')) {
          ctsCalls++;
          expect(request.url.queryParameters['numero'], _card);
          if (cts == null) fail('unexpected call to the primary source');
          return cts!(ctsCalls);
        }
        utrytCalls++;
        expect(request.url.queryParameters['card'], _card);
        if (utryt == null) fail('unexpected call to the fallback source');
        return utryt!(utrytCalls);
      });
}

CardRemoteDatasource _datasource(http.Client client) {
  return CardRemoteDatasource(
    client: client,
    random: _NoJitterRandom(),
    backoffBase: Duration.zero,
  );
}

void main() {
  group('CardRemoteDatasource', () {
    test('uses the primary source and parses its epoch balance date',
        () async {
      final sources = _Sources(
        cts: (_) async => http.Response(_ctsSuccessBody, 200),
      );

      final result = await _datasource(sources.client).getCardBalance(_card);

      expect(sources.ctsCalls, 1);
      expect(sources.utrytCalls, 0);
      expect(result.balance, 15300.0);
      expect(result.cardNumber, '1906051868981');
      expect(
        result.balanceDate,
        DateTime.fromMillisecondsSinceEpoch(1785631011000),
      );
    });

    test('falls back to the secondary source when the primary errors',
        () async {
      final sources = _Sources(
        cts: (_) async => http.Response(_ctsErrorBody, 200),
        utryt: (_) async => http.Response(_utrytSuccessBody, 200),
      );

      final result = await _datasource(sources.client).getCardBalance(_card);

      // The generic proxy error is not retried before falling back.
      expect(sources.ctsCalls, 1);
      expect(sources.utrytCalls, 1);
      expect(result.balance, 5000);
    });

    test('retries the primary source on 5xx before succeeding', () async {
      final sources = _Sources(
        cts: (call) async => call < 3
            ? http.Response('Internal Server Error', 500)
            : http.Response(_ctsSuccessBody, 200),
      );

      final result = await _datasource(sources.client).getCardBalance(_card);

      expect(sources.ctsCalls, 3);
      expect(sources.utrytCalls, 0);
      expect(result.balance, 15300.0);
    });

    test('reports an invalid card identified by the fallback', () async {
      final sources = _Sources(
        cts: (_) async => http.Response(_ctsErrorBody, 200),
        utryt: (_) async => http.Response(_invalidCardBody, 200),
      );

      await expectLater(
        _datasource(sources.client).getCardBalance(_card),
        throwsA(isA<InvalidCardApiException>()),
      );
      expect(sources.utrytCalls, 1);
    });

    test('reports a card without movements identified by the fallback',
        () async {
      final sources = _Sources(
        cts: (_) async => http.Response(_ctsErrorBody, 200),
        utryt: (_) async => http.Response(_noMovementsBody, 200),
      );

      await expectLater(
        _datasource(sources.client).getCardBalance(_card),
        throwsA(isA<CardNotFoundApiException>()),
      );
      expect(sources.utrytCalls, 1);
    });

    test('does not retry the fallback when it is rate limited', () async {
      final sources = _Sources(
        cts: (_) async => http.Response(_ctsErrorBody, 200),
        utryt: (_) async => http.Response(_rateLimitedBody, 200),
      );

      // Both sources failed: the primary error is what the user sees.
      await expectLater(
        _datasource(sources.client).getCardBalance(_card),
        throwsA(isA<ServerApiException>()),
      );
      expect(sources.ctsCalls, 1);
      expect(sources.utrytCalls, 1);
    });

    test('retries connection failures on both sources before giving up',
        () async {
      final sources = _Sources(
        cts: (_) async => throw http.ClientException('Connection refused'),
        utryt: (_) async => throw http.ClientException('Connection refused'),
      );

      await expectLater(
        _datasource(sources.client).getCardBalance(_card),
        throwsA(isA<NetworkApiException>()),
      );
      expect(sources.ctsCalls, 3);
      expect(sources.utrytCalls, 3);
    });

    test('treats non-JSON bodies as retryable server errors', () async {
      final sources = _Sources(
        cts: (_) async => http.Response('<html>Service Unavailable</html>', 200),
        utryt: (_) async => http.Response(_utrytSuccessBody, 200),
      );

      final result = await _datasource(sources.client).getCardBalance(_card);

      expect(sources.ctsCalls, 3);
      expect(result.balance, 5000);
    });

    test('does not parse numbers out of HTML error pages', () async {
      // Regression test: the old text-scraping fallback would extract
      // "20001" from this page and report it as a valid balance.
      final sources = _Sources(
        cts: (_) async => http.Response(
          '<html><body>Error ORA-20001 in module saldo.php</body></html>',
          200,
        ),
        utryt: (_) async => http.Response(
          '<html><body>Error ORA-20001 in module saldo.php</body></html>',
          200,
        ),
      );

      await expectLater(
        _datasource(sources.client).getCardBalance(_card),
        throwsA(isA<ServerApiException>()),
      );
    });

    test('rejects payloads without a usable card number', () async {
      final sources = _Sources(
        cts: (_) async => http.Response(
          '{"cardNumber": 0, "balance": 0, "balanceDate": null}',
          200,
        ),
        utryt: (_) async => http.Response(_noMovementsBody, 200),
      );

      await expectLater(
        _datasource(sources.client).getCardBalance(_card),
        throwsA(isA<CardNotFoundApiException>()),
      );
      expect(sources.ctsCalls, 1);
    });

    test('does not retry non-5xx client errors', () async {
      final sources = _Sources(
        cts: (_) async => http.Response('Not Found', 404),
        utryt: (_) async => http.Response('Not Found', 404),
      );

      await expectLater(
        _datasource(sources.client).getCardBalance(_card),
        throwsA(
          isA<ServerApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.isRetryable, 'isRetryable', isFalse),
        ),
      );
      expect(sources.ctsCalls, 1);
      expect(sources.utrytCalls, 1);
    });
  });
}
