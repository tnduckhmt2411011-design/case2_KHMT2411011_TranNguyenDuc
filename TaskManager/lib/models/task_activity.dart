import 'user.dart';

class TaskActivity {
  final String id;
  final String taskId;
  final User? user;
  final String action;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  TaskActivity({
    required this.id,
    required this.taskId,
    this.user,
    required this.action,
    this.details = const {},
    this.createdAt,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final detailsJson = json['details'];

    return TaskActivity(
      id: json['id'] ?? json['_id'] ?? '',
      taskId: json['taskId']?.toString() ?? '',
      user: userJson is Map<String, dynamic> ? User.fromJson(userJson) : null,
      action: json['action'] ?? '',
      details: detailsJson is Map<String, dynamic> ? detailsJson : const {},
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  String get actionLabel {
    switch (action) {
      case 'created':
        return 'Đã tạo công việc';
      case 'updated':
        return 'Đã cập nhật công việc';
      case 'status_changed':
        return 'Đã đổi trạng thái';
      case 'assigned':
        return 'Đã giao việc';
      case 'unassigned':
        return 'Đã hủy giao việc';
      case 'primary_changed':
        return 'Đã đổi người phụ trách chính';
      case 'shared':
        return 'Đã chia sẻ công việc';
      case 'share_updated':
        return 'Đã đổi quyền chia sẻ';
      case 'share_revoked':
        return 'Đã thu hồi quyền chia sẻ';
      default:
        return 'Hoạt động';
    }
  }

  String get actionDetails {
    switch (action) {
      case 'updated':
        final fields = (details['changedFields'] as List?)
                ?.map((field) => _fieldLabel(field.toString()))
                .toList() ??
            const [];
        return fields.isEmpty ? '' : 'Trường thay đổi: ${fields.join(', ')}';
      case 'status_changed':
        return '${_statusLabel(details['from'])} → ${_statusLabel(details['to'])}';
      case 'assigned':
        final userIds = details['userIds'] as List?;
        final count = userIds?.length ?? 0;
        return count > 0 ? 'Giao cho $count người' : '';
      case 'primary_changed':
        return details['to'] == null ? 'Bỏ người phụ trách chính' : '';
      case 'shared':
        final userIds = details['userIds'] as List?;
        final count = userIds?.length ?? 0;
        final permission = _permissionLabel(details['permission']);
        return count > 0 ? 'Chia sẻ cho $count người ($permission)' : '';
      case 'share_updated':
        return 'Quyền mới: ${_permissionLabel(details['permission'])}';
      case 'share_revoked':
        return 'Quyền bị thu hồi: ${_permissionLabel(details['permission'])}';
      default:
        return '';
    }
  }

  String _fieldLabel(String field) {
    switch (field) {
      case 'title':
        return 'tiêu đề';
      case 'description':
        return 'mô tả';
      case 'priority':
        return 'độ ưu tiên';
      case 'status':
        return 'trạng thái';
      case 'startDate':
        return 'ngày bắt đầu';
      case 'dueDate':
        return 'hạn hoàn thành';
      default:
        return field;
    }
  }

  String _statusLabel(dynamic value) {
    switch (value) {
      case 'todo':
        return 'Chưa thực hiện';
      case 'in_progress':
        return 'Đang thực hiện';
      case 'completed':
        return 'Đã hoàn thành';
      default:
        return value?.toString() ?? '';
    }
  }

  String _permissionLabel(dynamic value) {
    switch (value) {
      case 'viewer':
        return 'Chỉ xem';
      case 'editor':
        return 'Chỉnh sửa';
      default:
        return value?.toString() ?? '';
    }
  }
}
