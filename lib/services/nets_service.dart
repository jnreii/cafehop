import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

class NETSService {
  //passed in at build time with --dart-define, see README
  final String apiKey = const String.fromEnvironment('NETS_API_KEY');
  final String projectId = const String.fromEnvironment('NETS_PROJECT_ID');

  // Generates a NETS QR payment request
  Future<Map<String, dynamic>> requestQR(double amount) async {
    try {
      final url = Uri.parse(
        'https://sandbox.nets.openapipaas.com/api/v1/common/payments/nets-qr/request',
      );

      final txnId =
          'sandbox_nets|m|8ff8e5b6-d43e-4786-8ac5-7accf8c5bd9b';

      debugPrint('NETS txn_id: $txnId');

      final response = await post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
          'project-id': projectId,
        },
        body: jsonEncode({
          'txn_id': txnId,
          'amt_in_dollars': amount,
          'notify_mobile': 0,
        }),
      );

      //temporary debugging so we can see exactly what NETS sends back
      debugPrint('requestQR status: ${response.statusCode}');

      final data = jsonDecode(response.body);

      //dont assume every NETS response contains result.data
      final result = data['result'];
      final responseData = result?['data'];

      if (response.statusCode != 200 ||
          responseData == null ||
          responseData['qr_code'] == null ||
          responseData['txn_retrieval_ref'] == null) {
        debugPrint('NETS RequestAPI did not return QR data.');
        return {};
      }

      return {
        'qrCode': responseData['qr_code'],
        'txnRef': responseData['txn_retrieval_ref'],
      };
    } catch (e) {
      debugPrint('requestQR error: $e');
      return {};
    }
  }

  // SSE stream for real-time payment updates
  Stream<String> webhookStream(String txnRef) async* {
    final client = Client();

    final url = Uri.parse(
      'https://sandbox.nets.openapipaas.com/api/v1/common/payments/nets/webhook?txn_retrieval_ref=$txnRef',
    );

    final request = Request('GET', url)
      ..headers.addAll({
        'Accept': 'text/event-stream',
        'Connection': 'keep-alive',
        'api-key': apiKey,
        'project-id': projectId,
      });

    final response = await client.send(request);

    if (response.statusCode == 200) {
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        yield chunk;
      }
    }
  }

  // Final payment status check
  Future<Map<String, dynamic>> checkPayment(String txnRef) async {
    try {
      final url = Uri.parse(
        'https://sandbox.nets.openapipaas.com/api/v1/common/payments/nets-qr/query',
      );

      final response = await post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
          'project-id': projectId,
        },
        body: jsonEncode({
          'txn_retrieval_ref': txnRef,
          'frontend_timeout_status': 1,
        }),
      );

      final data = jsonDecode(response.body);

      return {
        "response_code": data['result']['data']['response_code'],
        "message": data['result']['data']['message'],
      };
    } catch (e) {
      debugPrint('checkPayment error: $e');
      return {};
    }
  }
}