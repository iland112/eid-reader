import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:eid_reader/features/passport_reader/data/datasources/http_pa_service.dart';

void main() {
  final testSodBytes = Uint8List.fromList([1, 2, 3]);
  final testDg1Bytes = Uint8List.fromList([4, 5, 6]);
  final testDg2Bytes = Uint8List.fromList([7, 8, 9]);

  group('HttpPaService', () {
    test('sends correct request body', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'status': 'VALID'},
          }),
          200,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
        issuingCountry: 'KR',
        documentNumber: 'M12345678',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['sod'], base64Encode(testSodBytes));
      expect(
        (capturedBody!['dataGroups'] as Map)['1'],
        base64Encode(testDg1Bytes),
      );
      expect(
        (capturedBody!['dataGroups'] as Map)['2'],
        base64Encode(testDg2Bytes),
      );
      expect(capturedBody!['issuingCountry'], 'KR');
      expect(capturedBody!['documentNumber'], 'M12345678');
    });

    test('omits optional fields when null', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'status': 'VALID'},
          }),
          200,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(capturedBody!.containsKey('issuingCountry'), false);
      expect(capturedBody!.containsKey('documentNumber'), false);
    });

    test('parses VALID response correctly', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'status': 'VALID',
              'verificationId': 'uuid-123',
              'processingDurationMs': 200,
              'certificateChainValidation': {'valid': true},
              'sodSignatureValidation': {
                'valid': true,
                'hashAlgorithm': 'SHA-256',
              },
              'dataGroupValidation': {
                'totalGroups': 2,
                'validGroups': 2,
                'invalidGroups': 0,
              },
            },
          }),
          200,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final result = await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(result.isValid, true);
      expect(result.verificationId, 'uuid-123');
      expect(result.certificateChainValid, true);
      expect(result.sodSignatureValid, true);
      expect(result.validGroups, 2);
    });

    test('handles API error response', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'SOD parsing failed: Invalid CMS structure',
          }),
          200,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final result = await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(result.isValid, false);
      expect(result.status, 'ERROR');
      expect(
        result.errorMessage,
        'SOD parsing failed: Invalid CMS structure',
      );
    });

    test('handles HTTP error status code', () async {
      final mockClient = MockClient((_) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final result = await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(result.isValid, false);
      expect(result.status, 'ERROR');
      expect(result.errorMessage, 'Server error (500)');
    });

    test('handles network error', () async {
      final mockClient = MockClient((_) async {
        throw http.ClientException('Connection refused');
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final result = await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(result.isValid, false);
      expect(result.status, 'ERROR');
      expect(result.errorMessage, contains('Network error'));
    });

    test('sends request to correct URL', () async {
      Uri? capturedUri;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'status': 'VALID'},
          }),
          200,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://192.168.1.100:8080',
        client: mockClient,
      );

      await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(capturedUri.toString(), 'http://192.168.1.100:8080/api/pa/verify');
    });

    test('sets correct content-type header', () async {
      Map<String, String>? capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'status': 'VALID'},
          }),
          200,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(capturedHeaders!['Content-Type'], 'application/json');
    });

    test('includes X-API-Key header when apiKey is provided', () async {
      Map<String, String>? capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'status': 'VALID'},
          }),
          200,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        apiKey: 'icao_TEST1234_ABCDEF',
        client: mockClient,
      );

      await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(capturedHeaders!['X-API-Key'], 'icao_TEST1234_ABCDEF');
    });

    test('omits X-API-Key header when apiKey is null', () async {
      Map<String, String>? capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'status': 'VALID'},
          }),
          200,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(capturedHeaders!.containsKey('X-API-Key'), false);
    });

    test('handles 429 rate limit response', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': 'Rate limit exceeded',
            'message': 'Per-minute rate limit exceeded (60/min)',
            'retryAfter': 45,
          }),
          429,
          headers: {'retry-after': '45'},
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final result = await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(result.isValid, false);
      expect(result.status, 'ERROR');
      expect(result.errorMessage, contains('Rate limit'));
      expect(result.errorMessage, contains('45'));
    });

    test('handles 403 forbidden response', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': 'Forbidden',
            'message': 'Insufficient permissions. Required: pa:verify',
          }),
          403,
        );
      });

      final service = HttpPaService(
        baseUrl: 'http://localhost:8080',
        apiKey: 'icao_INVALID_KEY',
        client: mockClient,
      );

      final result = await service.verify(
        sodBytes: testSodBytes,
        dg1Bytes: testDg1Bytes,
        dg2Bytes: testDg2Bytes,
      );

      expect(result.isValid, false);
      expect(result.status, 'ERROR');
      expect(result.errorMessage, contains('permissions'));
    });
  });
}
