import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? AppConstants.baseUrl,
        _httpClient = httpClient ?? http.Client();

  Map<String, String> _buildHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String message = 'Đã xảy ra lỗi (${response.statusCode})';
    if (body is Map<String, dynamic> && body['message'] != null) {
      message = body['message'].toString();
    } else if (response.body.isNotEmpty) {
      message = response.body;
    }

    throw ApiException(statusCode: response.statusCode, message: message);
  }

  Future<dynamic> get(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _httpClient
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(AppConstants.timeoutDuration);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng hoặc đảm bảo máy chủ đang chạy.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Kết nối máy chủ quá thời gian quy định (timeout). Vui lòng thử lại.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Lỗi kết nối: ${e.toString()}');
    }
  }

  Future<dynamic> post(String path, {dynamic body, String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(token: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConstants.timeoutDuration);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng hoặc đảm bảo máy chủ đang chạy.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Kết nối máy chủ quá thời gian quy định (timeout). Vui lòng thử lại.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Lỗi kết nối: ${e.toString()}');
    }
  }
}
