import '../models/task.dart';
import 'api_client.dart';
import 'auth_service.dart';

class TaskService {
  final ApiClient _apiClient;
  final AuthService _authService;

  TaskService({ApiClient? apiClient, AuthService? authService})
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

  // Lay danh sach cong viec theo scope (created | assigned | shared | null = all)
  Future<List<Task>> getTasks({String? scope}) async {
    final token = await _getValidToken();

    final queryParams = scope != null && scope.isNotEmpty ? '?scope=$scope' : '';
    try {
      final response = await _apiClient.get('/tasks$queryParams', token: token);
      if (response is Map<String, dynamic> && response['tasks'] is List) {
        final list = response['tasks'] as List;
        return list.map((item) => Task.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _authService.logout();
        throw ApiException(
          statusCode: 401,
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
      rethrow;
    }
  }

  // Lay chi tiet mot cong viec
  Future<Task> getTaskById(String taskId) async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.get('/tasks/$taskId', token: token);
      if (response is Map<String, dynamic> && response['task'] != null) {
        return Task.fromJson(response['task'] as Map<String, dynamic>);
      }
      throw ApiException(
        statusCode: 500,
        message: 'Phản hồi chi tiết công việc không hợp lệ.',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _authService.logout();
        throw ApiException(
          statusCode: 401,
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
      rethrow;
    }
  }
}
