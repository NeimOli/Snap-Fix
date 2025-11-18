import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  final http.Client _client = http.Client();

  Future<Map<String, String>> _buildHeaders({bool authenticated = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await TokenStorage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Uri _buildUri(String path) => Uri.parse(AppConfig.endpoint(path));

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final headers = await _buildHeaders(authenticated: authenticated);
    final response = await _client.post(
      _buildUri(path),
      headers: headers,
      body: jsonEncode(body ?? {}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _buildHeaders(authenticated: authenticated);
    final uri = _buildUri(path).replace(queryParameters: queryParameters);
    final response = await _client.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = data['message']?.toString() ?? 'Something went wrong';
    throw ApiException(message, statusCode: response.statusCode);
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

