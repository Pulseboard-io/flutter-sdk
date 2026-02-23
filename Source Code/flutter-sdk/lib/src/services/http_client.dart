import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/batch_payload.dart';
import '../models/batch_response.dart';
import '../utils/id_generator.dart';
import '../utils/logger.dart';

/// Result of an HTTP batch send attempt.
class SendResult {
  final bool success;
  final int statusCode;
  final BatchResponse? response;
  final String? error;
  final bool shouldRetry;

  const SendResult({
    required this.success,
    required this.statusCode,
    this.response,
    this.error,
    this.shouldRetry = false,
  });
}

/// HTTP client for sending batches to the Pulseboard API.
class AnalyticsHttpClient {
  final AnalyticsConfig _config;
  final http.Client _client;
  final SdkLogger _logger;

  AnalyticsHttpClient({
    required AnalyticsConfig config,
    http.Client? client,
    SdkLogger? logger,
  })  : _config = config,
        _client = client ?? http.Client(),
        _logger = logger ?? SdkLogger();

  /// Send a batch payload to the ingestion endpoint.
  Future<SendResult> sendBatch(BatchPayload payload,
      {String? idempotencyKey}) async {
    final url = Uri.parse('${_config.endpoint}/api/v1/ingest/batch');
    final key = idempotencyKey ?? IdGenerator.idempotencyKey();

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${_config.publicKey}',
          'Idempotency-Key': key,
          'X-SDK-Name': 'flutter',
          'X-SDK-Version': '0.1.0',
        },
        body: jsonEncode(payload.toJson()),
      );

      _logger.debug('Batch response: ${response.statusCode}');

      if (response.statusCode == 202) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return SendResult(
          success: true,
          statusCode: 202,
          response: BatchResponse.fromJson(body),
        );
      }

      if (response.statusCode == 422) {
        return SendResult(
          success: false,
          statusCode: 422,
          error: response.body,
          shouldRetry: false,
        );
      }

      if (response.statusCode == 429) {
        return const SendResult(
          success: false,
          statusCode: 429,
          error: 'Rate limited',
          shouldRetry: true,
        );
      }

      // 5xx errors are retryable
      if (response.statusCode >= 500) {
        return SendResult(
          success: false,
          statusCode: response.statusCode,
          error: 'Server error: ${response.statusCode}',
          shouldRetry: true,
        );
      }

      return SendResult(
        success: false,
        statusCode: response.statusCode,
        error: 'Unexpected status: ${response.statusCode}',
        shouldRetry: false,
      );
    } catch (e) {
      _logger.error('Network error sending batch', e);
      return SendResult(
        success: false,
        statusCode: 0,
        error: e.toString(),
        shouldRetry: true,
      );
    }
  }

  /// Close the underlying HTTP client.
  void close() {
    _client.close();
  }
}
