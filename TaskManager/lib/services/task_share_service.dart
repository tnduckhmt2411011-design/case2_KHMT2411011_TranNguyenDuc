import '../models/task_share.dart';
import 'api_client.dart';
import 'auth_service.dart';

class TaskShareService {
  final ApiClient _apiClient;
  final AuthService _authService;

  TaskShareService({ApiClient? apiClient, AuthService? authService})
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

  // ==================== GIAO VIỆC (ASSIGNEES) ====================

  // Lay danh sach nguoi duoc giao
  Future<List<TaskAssignee>> getAssignees(String taskId) async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.get('/tasks/$taskId/assignees', token: token);
      if (response is Map<String, dynamic> && response['assignees'] is List) {
        final list = response['assignees'] as List;
        return list.map((item) => TaskAssignee.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Giao viec cho danh sach nguoi dung
  Future<void> assignUsers(
    String taskId, {
    required List<String> userIds,
    String? primaryAssigneeId,
  }) async {
    final token = await _getValidToken();

    final body = <String, dynamic>{
      'userIds': userIds,
    };
    if (primaryAssigneeId != null) {
      body['primaryAssigneeId'] = primaryAssigneeId;
    }

    try {
      await _apiClient.post('/tasks/$taskId/assignees', body: body, token: token);
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Dat nguoi phu trach chinh
  Future<void> setPrimaryAssignee(String taskId, String userId) async {
    final token = await _getValidToken();

    try {
      await _apiClient.patch(
        '/tasks/$taskId/assignees/$userId',
        body: {'isPrimary': true},
        token: token,
      );
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Huy giao viec cho nguoi dung
  Future<void> removeAssignee(String taskId, String userId) async {
    final token = await _getValidToken();

    try {
      await _apiClient.delete('/tasks/$taskId/assignees/$userId', token: token);
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // ==================== CHIA SẺ (SHARES) ====================

  // Lay danh sach chia se
  Future<List<TaskShare>> getShares(String taskId) async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.get('/tasks/$taskId/shares', token: token);
      if (response is Map<String, dynamic> && response['shares'] is List) {
        final list = response['shares'] as List;
        return list.map((item) => TaskShare.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Chia se cong viec
  Future<Map<String, dynamic>> createShares(
    String taskId, {
    required List<String> userIds,
    required String permission,
  }) async {
    final token = await _getValidToken();

    try {
      final response = await _apiClient.post(
        '/tasks/$taskId/shares',
        body: {
          'userIds': userIds,
          'permission': permission,
        },
        token: token,
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Cap nhat quyen chia se
  Future<void> updateShare(String taskId, String shareId, String permission) async {
    final token = await _getValidToken();

    try {
      await _apiClient.patch(
        '/tasks/$taskId/shares/$shareId',
        body: {'permission': permission},
        token: token,
      );
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }

  // Thu hoi quyen chia se
  Future<void> deleteShare(String taskId, String shareId) async {
    final token = await _getValidToken();

    try {
      await _apiClient.delete('/tasks/$taskId/shares/$shareId', token: token);
    } on ApiException catch (e) {
      _handle401(e);
      rethrow;
    }
  }
}
