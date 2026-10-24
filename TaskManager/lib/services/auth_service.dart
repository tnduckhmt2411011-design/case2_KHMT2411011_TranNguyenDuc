import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/constants.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // Lay token da luu
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  // Luu token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  // Xoa token khi dang xuat
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  // Dang ky tai khoan
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
      },
    );

    if (response is Map<String, dynamic> && response['user'] != null) {
      return User.fromJson(response['user'] as Map<String, dynamic>);
    }
    throw ApiException(
      statusCode: 500,
      message: 'Phản hồi không hợp lệ từ máy chủ.',
    );
  }

  // Dang nhap
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response is Map<String, dynamic> && response['token'] != null) {
      final token = response['token'].toString();
      await saveToken(token);
      final user = response['user'] != null
          ? User.fromJson(response['user'] as Map<String, dynamic>)
          : null;
      return {'token': token, 'user': user};
    }

    throw ApiException(
      statusCode: 500,
      message: 'Đăng nhập thất bại: Phản hồi không hợp lệ.',
    );
  }

  // Lay thong tin nguoi dung hien tai
  Future<User> getMe() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw ApiException(statusCode: 401, message: 'Chưa đăng nhập');
    }

    final response = await _apiClient.get('/auth/me', token: token);
    if (response is Map<String, dynamic> && response['user'] != null) {
      return User.fromJson(response['user'] as Map<String, dynamic>);
    }
    throw ApiException(
      statusCode: 500,
      message: 'Phản hồi thông tin người dùng không hợp lệ.',
    );
  }
}
