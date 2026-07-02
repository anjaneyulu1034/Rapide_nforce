import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/utils/api_logger.dart';
import 'package:rapide_nforce/services/api_config.dart';
import 'package:rapide_nforce/services/auth_service.dart';

/// Shared HTTP client — mirrors web `api.ts` (Bearer + optional X-Company-Id).
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String get _baseUrl => ApiConfig.baseUrl;

  Map<String, String> _headers({bool json = true, String? companyId}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';

    final token = AuthService.instance.currentUser?.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final carrierId = companyId ?? AuthService.instance.selectedCompanyId;
    if (carrierId != null &&
        carrierId.isNotEmpty &&
        carrierId != ApiConstants.allCarriersId) {
      headers['X-Company-Id'] = carrierId;
    }

    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? params]) {
    final base = Uri.parse('$_baseUrl$path');
    if (params == null || params.isEmpty) return base;

    final query = <String, String>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      query[entry.key] = value.toString();
    }

    return base.replace(queryParameters: query.isEmpty ? null : query);
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(dynamic body, int statusCode) {
    if (body is Map<String, dynamic>) {
      final message = body['message'] as String?;
      if (message != null && message.trim().isNotEmpty) return message.trim();

      final nestedError = body['error'];
      if (nestedError is String && nestedError.trim().isNotEmpty) {
        return nestedError.trim();
      }
      if (nestedError is Map) {
        final nestedMessage = nestedError['message'] as String?;
        if (nestedMessage != null && nestedMessage.trim().isNotEmpty) {
          return nestedMessage.trim();
        }
      }

      final general = (body['errors'] as Map<String, dynamic>?)?['general'];
      if (general is List && general.isNotEmpty) {
        return general.first.toString();
      }
    }
    return 'Request failed ($statusCode)';
  }

  void _logRequest(String method, Uri uri) {
    ApiLogger.request(method, uri.toString());
  }

  void _logResponse(String method, Uri uri, http.Response response, dynamic body) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      ApiLogger.response(method, uri.toString(), response.statusCode, body);
    } else {
      ApiLogger.failure(
        method,
        uri.toString(),
        response.statusCode,
        _errorMessage(body, response.statusCode),
      );
      if (kDebugMode) {
        ApiLogger.response(method, uri.toString(), response.statusCode, body);
      }
    }
  }

  Future<http.Response> get(
    String path, {
    Map<String, dynamic>? params,
    String? companyId,
  }) async {
    final uri = _uri(path, params);
    _logRequest('GET', uri);
    final response = await http.get(
      uri,
      headers: _headers(companyId: companyId),
    );
    _logResponse('GET', uri, response, _decodeBody(response));
    return response;
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, dynamic>? params,
    String? companyId,
  }) async {
    final uri = _uri(path, params);
    _logRequest('POST', uri);
    final response = await http.post(
      uri,
      headers: _headers(companyId: companyId),
      body: body == null ? null : jsonEncode(body),
    );
    _logResponse('POST', uri, response, _decodeBody(response));
    return response;
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, dynamic>? params,
    String? companyId,
  }) async {
    final uri = _uri(path, params);
    _logRequest('PUT', uri);
    final response = await http.put(
      uri,
      headers: _headers(companyId: companyId),
      body: body == null ? null : jsonEncode(body),
    );
    _logResponse('PUT', uri, response, _decodeBody(response));
    return response;
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? params,
    String? companyId,
  }) async {
    final uri = _uri(path, params);
    _logRequest('PATCH', uri);
    final response = await http.patch(
      uri,
      headers: _headers(companyId: companyId),
      body: body == null ? null : jsonEncode(body),
    );
    _logResponse('PATCH', uri, response, _decodeBody(response));
    return response;
  }

  Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? params,
    String? companyId,
  }) async {
    final uri = _uri(path, params);
    _logRequest('DELETE', uri);
    final response = await http.delete(
      uri,
      headers: _headers(companyId: companyId),
    );
    _logResponse('DELETE', uri, response, _decodeBody(response));
    return response;
  }

  Future<http.Response> postMultipart(
    String path,
    http.MultipartRequest request, {
    String? companyId,
  }) async {
    final headers = _headers(json: false, companyId: companyId);
    final forwarded = http.MultipartRequest(request.method, _uri(path))
      ..fields.addAll(request.fields)
      ..files.addAll(request.files);
    forwarded.headers.addAll(headers);
    final streamed = await forwarded.send();
    return http.Response.fromStream(streamed);
  }

  Future<T> parseJson<T>(
    Future<http.Response> Function() request, {
    required T Function(dynamic body) onSuccess,
  }) async {
    final response = await request();
    final body = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return onSuccess(body);
    }

    throw ApiClientException(
      _errorMessage(body, response.statusCode),
      response.statusCode,
    );
  }
}

class ApiClientException implements Exception {
  ApiClientException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
