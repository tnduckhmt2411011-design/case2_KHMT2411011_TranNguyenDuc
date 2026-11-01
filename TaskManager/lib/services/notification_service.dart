import '../models/notification.dart';
import 'api_client.dart';
import 'auth_service.dart';

class NotificationService {
  final ApiClient _apiClient;
  final AuthService _authService;

  NotificationService({ApiClient? apiClient, AuthService? authService})
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

  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async {
    final token = await _getValidToken();

    try {
      final path = unreadOnly ? '/notifications?unread=true' : '/notifications';
      final response = await _apiClient.get(path, token: token);
      if (response is Map<String, dynamic> && response['notifications'] is List) {
        final list = response['notifications'] as List;
        return list
            .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  Future<int> getUnreadCount() async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.get('/notifications/unread-count', token: token);
      if (response is Map<String, dynamic> && response['count'] != null) {
        return (response['count'] as num).toInt();
      }
      return 0;
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  Future<AppNotification> markAsRead(String notificationId) async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.patch(
        '/notifications/$notificationId/read',
        token: token,
      );
      if (response is Map<String, dynamic> && response['notification'] != null) {
        return AppNotification.fromJson(
          response['notification'] as Map<String, dynamic>,
        );
      }
      throw ApiException(
        statusCode: 500,
        message: 'Phản hồi đánh dấu đã đọc không hợp lệ.',
      );
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  Future<int> markAllAsRead() async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.patch('/notifications/read-all', token: token);
      if (response is Map<String, dynamic> && response['modifiedCount'] != null) {
        return (response['modifiedCount'] as num).toInt();
      }
      return 0;
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }
}
