import '../models/task.dart';
import '../models/task_activity.dart';
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

  void _handle401(ApiException e) {
    if (e.statusCode == 401) {
      _authService.logout();
      throw ApiException(
        statusCode: 401,
        message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
  }

  // Lay danh sach cong viec theo scope va bo loc
  Future<List<Task>> getTasks({
    String? scope,
    String? q,
    String? status,
    String? priority,
    String? assigneeId,
    String? sortBy,
    String? order,
  }) async {
    final token = await _getValidToken();

    final params = <String, String>{};
    if (scope != null && scope.isNotEmpty) params['scope'] = scope;
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (priority != null && priority.isNotEmpty) params['priority'] = priority;
    if (assigneeId != null && assigneeId.isNotEmpty) {
      params['assigneeId'] = assigneeId;
    }
    if (sortBy != null && sortBy.isNotEmpty) params['sortBy'] = sortBy;
    if (order != null && order.isNotEmpty) params['order'] = order;

    final queryParams = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';

    try {
      final response = await _apiClient.get('/tasks$queryParams', token: token);
      if (response is Map<String, dynamic> && response['tasks'] is List) {
        final list = response['tasks'] as List;
        return list.map((item) => Task.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } on ApiException catch (e) {
      _handle401(e);
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
      _handle401(e);
      rethrow;
    }
  }

  // Tao moi cong viec
  Future<Task> createTask({
    required String title,
    String? description,
    String? priority,
    String? status,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final token = await _getValidToken();

    final body = <String, dynamic>{
      'title': title,
    };
    if (description != null && description.isNotEmpty) body['description'] = description;
    if (priority != null) body['priority'] = priority;
    if (status != null) body['status'] = status;
    if (startDate != null) body['startDate'] = startDate.toIso8601String();
    if (dueDate != null) body['dueDate'] = dueDate.toIso8601String();

    try {
      final response = await _apiClient.post('/tasks', body: body, token: token);
      if (response is Map<String, dynamic> && response['task'] != null) {
        return Task.fromJson(response['task'] as Map<String, dynamic>);
      }
      throw ApiException(statusCode: 500, message: 'Phản hồi tạo công việc không hợp lệ.');
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Cap nhat cong viec
  Future<Task> updateTask({
    required String taskId,
    required String title,
    String? description,
    String? priority,
    String? status,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final token = await _getValidToken();

    final body = <String, dynamic>{
      'title': title,
      'description': description ?? '',
      'priority': priority ?? 'medium',
      'status': status ?? 'todo',
    };
    if (startDate != null) {
      body['startDate'] = startDate.toIso8601String();
    }
    if (dueDate != null) {
      body['dueDate'] = dueDate.toIso8601String();
    }

    try {
      final response = await _apiClient.put('/tasks/$taskId', body: body, token: token);
      if (response is Map<String, dynamic> && response['task'] != null) {
        return Task.fromJson(response['task'] as Map<String, dynamic>);
      }
      throw ApiException(statusCode: 500, message: 'Phản hồi cập nhật không hợp lệ.');
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Doi trang thai cong viec
  Future<Task> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.patch(
        '/tasks/$taskId/status',
        body: {'status': status},
        token: token,
      );
      if (response is Map<String, dynamic> && response['task'] != null) {
        return Task.fromJson(response['task'] as Map<String, dynamic>);
      }
      throw ApiException(statusCode: 500, message: 'Phản hồi đổi trạng thái không hợp lệ.');
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Xoa cong viec
  Future<void> deleteTask(String taskId) async {
    final token = await _getValidToken();

    try {
      await _apiClient.delete('/tasks/$taskId', token: token);
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Lay lich su hoat dong cua cong viec
  Future<List<TaskActivity>> getTaskActivities(String taskId) async {
    final token = await _getValidToken();

    try {
      final response =
          await _apiClient.get('/tasks/$taskId/activities', token: token);
      if (response is Map<String, dynamic> && response['activities'] is List) {
        final list = response['activities'] as List;
        return list
            .map((item) =>
                TaskActivity.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Lay lich su gui email cua cong viec (chi danh cho creator)
  Future<List<Map<String, dynamic>>> getTaskEmailLogs(String taskId) async {
    final token = await _getValidToken();

    try {
      final response =
          await _apiClient.get('/tasks/$taskId/email-logs', token: token);
      if (response is Map<String, dynamic> && response['emailLogs'] is List) {
        final list = response['emailLogs'] as List;
        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }
}
