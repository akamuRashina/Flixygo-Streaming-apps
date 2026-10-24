import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../env.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

ApiException wrapSupabaseError(Object error) {
  try {
    final dynamic e = error;
    final m = e.message;
    if (m is String && m.isNotEmpty) return ApiException(m);
  } catch (_) {}
  return ApiException(error.toString());
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String get baseUrl {
    if (Env.apiBaseUrl.isNotEmpty) {
      return Env.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }
    // Android emulator cannot access host machine via "localhost" -> use 10.0.2.2
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParameters}) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final baseUri = Uri.parse('$baseUrl$cleanPath');
    final uri = queryParameters != null && queryParameters.isNotEmpty
        ? baseUri.replace(queryParameters: queryParameters)
        : baseUri;

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['success'] == false) {
          throw ApiException(
            body['error']?.toString() ?? body['message']?.toString() ?? 'Gagal memuat data dari backend',
            statusCode: response.statusCode,
          );
        }
        return body is Map && body.containsKey('data') ? body['data'] : body;
      }
      throw ApiException(
        'Server backend error (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal terhubung ke server FlixyGo ($uri): $e');
    }
  }
}
