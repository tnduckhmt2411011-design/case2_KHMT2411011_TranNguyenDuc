import '../models/statistics.dart';
import 'api_client.dart';
import 'auth_service.dart';

class StatisticsService {
  final ApiClient _apiClient;
  final AuthService _authService;

  StatisticsService({ApiClient? apiClient, AuthService? authService})
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

  Future<TaskStatistics> getTaskStatistics() async {
    final token = await _getValidToken();
    try {
      final response = await _apiClient.get('/statistics/tasks', token: token);
      if (response is Map<String, dynamic>) {
        return TaskStatistics.fromJson(response);
      }
      throw ApiException(
        statusCode: 500,
        message: 'Phản hồi thống kê công việc không hợp lệ.',
      );
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  Future<AssignmentStatistics> getAssignmentStatistics() async {
    final token = await _getValidToken();
    try {
      final response =
          await _apiClient.get('/statistics/assignments', token: token);
      if (response is Map<String, dynamic>) {
        return AssignmentStatistics.fromJson(response);
      }
      throw ApiException(
        statusCode: 500,
        message: 'Phản hồi thống kê giao việc không hợp lệ.',
      );
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  Future<DeadlineStatistics> getDeadlineStatistics() async {
    final token = await _getValidToken();
    try {
      final response =
          await _apiClient.get('/statistics/deadlines', token: token);
      if (response is Map<String, dynamic>) {
        return DeadlineStatistics.fromJson(response);
      }
      throw ApiException(
        statusCode: 500,
        message: 'Phản hồi thống kê hạn hoàn thành không hợp lệ.',
      );
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }
}
