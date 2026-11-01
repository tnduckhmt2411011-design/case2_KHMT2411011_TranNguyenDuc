import '../models/user.dart';
import 'api_client.dart';
import 'auth_service.dart';

class UserService {
  final ApiClient _apiClient;
  final AuthService _authService;

  UserService({ApiClient? apiClient, AuthService? authService})
      : _apiClient = apiClient ?? ApiClient(),
        _authService = authService ?? AuthService();

  Future<String> _getValidToken() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      await _authService.logout();
      throw ApiException(
        statusCode: 401,
        message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    return token;
  }

  void _handle401(ApiException e) {
    if (e.statusCode == 401) {
      _authService.logout();
      throw ApiException(
        statusCode: 401,
        message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
  }

  // Tim kiem nguoi dung theo ten hoac email
  Future<List<User>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return [];
    }

    final token = await _getValidToken();

    try {
      final encoded = Uri.encodeQueryComponent(trimmed);
      final response = await _apiClient.get('/users/search?q=$encoded', token: token);
      if (response is Map<String, dynamic> && response['users'] is List) {
        final list = response['users'] as List;
        return list.map((item) => User.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Lay thong tin mot nguoi dung theo ID
  Future<User> getUserById(String userId) async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.get('/users/$userId', token: token);
      if (response is Map<String, dynamic> && response['user'] != null) {
        return User.fromJson(response['user'] as Map<String, dynamic>);
      }
      throw ApiException(
        statusCode: 500,
        message: 'Phản hồi thông tin người dùng không hợp lệ.',
      );
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }
}
