import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../domain/entities/pa_verification_result.dart';
import 'pa_service.dart';

final _log = Logger('HttpPaService');

/// PA Service client that calls the REST API for Passive Authentication.
class HttpPaService implements PaService {
  final String baseUrl;
  final String? apiKey;
  final http.Client _client;

  HttpPaService({
    required this.baseUrl,
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<PaVerificationResult> verify({
    required Uint8List sodBytes,
    required Uint8List dg1Bytes,
    required Uint8List dg2Bytes,
    String? issuingCountry,
    String? documentNumber,
  }) async {
    final uri = Uri.parse('$baseUrl/api/pa/verify');

    final body = <String, dynamic>{
      'sod': base64Encode(sodBytes),
      'dataGroups': <String, String>{
        '1': base64Encode(dg1Bytes),
        '2': base64Encode(dg2Bytes),
      },
    };

    if (issuingCountry != null && issuingCountry.isNotEmpty) {
      body['issuingCountry'] = issuingCountry;
    }
    if (documentNumber != null && documentNumber.isNotEmpty) {
      body['documentNumber'] = documentNumber;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['X-API-Key'] = apiKey!;
    }

    try {
      _log.info('Sending PA verification request to $uri');
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final success = json['success'] as bool? ?? false;

        if (success) {
          return PaVerificationResult.fromJson(json);
        } else {
          final error = json['error'] as String? ?? 'Verification failed';
          _log.warning('PA API returned error: $error');
          return PaVerificationResult.error(error);
        }
      } else if (response.statusCode == 429) {
        final retryAfter = response.headers['retry-after'] ?? '60';
        _log.warning('PA API rate limited, retry after ${retryAfter}s');
        return PaVerificationResult.error(
          'Rate limit exceeded. Retry after ${retryAfter}s',
        );
      } else if (response.statusCode == 403) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final message = json['message'] as String? ?? 'Access denied';
        _log.warning('PA API forbidden: $message');
        return PaVerificationResult.error(message);
      } else {
        _log.warning('PA API returned status ${response.statusCode}');
        return PaVerificationResult.error(
          'Server error (${response.statusCode})',
        );
      }
    } on http.ClientException catch (e) {
      _log.warning('PA API network error: $e');
      return PaVerificationResult.error('Network error: ${e.message}');
    } catch (e) {
      _log.warning('PA API unexpected error: $e');
      return PaVerificationResult.error('Verification unavailable');
    }
  }
}
