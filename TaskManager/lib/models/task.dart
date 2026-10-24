import 'user.dart';

class TaskShareItem {
  final String id;
  final User? user;
  final String permission; // 'viewer' | 'editor'
  final DateTime? createdAt;

  TaskShareItem({
    required this.id,
    this.user,
    required this.permission,
    this.createdAt,
  });

  factory TaskShareItem.fromJson(Map<String, dynamic> json) {
    return TaskShareItem(
      id: json['id'] ?? json['_id'] ?? '',
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'])
          : null,
      permission: json['permission'] ?? 'viewer',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  String get permissionLabel {
    switch (permission) {
      case 'editor':
        return 'Chỉnh sửa (Editor)';
      case 'viewer':
      default:
        return 'Chỉ xem (Viewer)';
    }
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String status; // 'todo', 'in_progress', 'completed'
  final String priority; // 'low', 'medium', 'high'
  final DateTime? startDate;
  final DateTime? dueDate;
  final User? createdBy;
  final User? primaryAssignee;
  final List<User> assignees;
  final List<TaskShareItem> shares;
  final String? userRole; // 'creator', 'assignee', 'editor', 'viewer'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.startDate,
    this.dueDate,
    this.createdBy,
    this.primaryAssignee,
    this.assignees = const [],
    this.shares = const [],
    this.userRole,
    this.createdAt,
    this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // CreatedBy co the la Map hoac String id
    User? createdUser;
    if (json['createdBy'] != null && json['createdBy'] is Map<String, dynamic>) {
      createdUser = User.fromJson(json['createdBy']);
    }

    // PrimaryAssignee co the la primaryAssignee hoac primaryAssigneeId
    User? primaryUser;
    final primaryData = json['primaryAssignee'] ?? json['primaryAssigneeId'];
    if (primaryData != null && primaryData is Map<String, dynamic>) {
      primaryUser = User.fromJson(primaryData);
    }

    // Assignees co the la assignees hoac assigneeIds
    final List<User> parsedAssignees = [];
    final assigneesData = json['assignees'] ?? json['assigneeIds'];
    if (assigneesData != null && assigneesData is List) {
      for (final item in assigneesData) {
        if (item is Map<String, dynamic>) {
          parsedAssignees.add(User.fromJson(item));
        }
      }
    }

    // Shares
    final List<TaskShareItem> parsedShares = [];
    if (json['shares'] != null && json['shares'] is List) {
      for (final item in json['shares']) {
        if (item is Map<String, dynamic>) {
          parsedShares.add(TaskShareItem.fromJson(item));
        }
      }
    }

    return Task(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'todo',
      priority: json['priority'] ?? 'medium',
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate']) : null,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      createdBy: createdUser,
      primaryAssignee: primaryUser,
      assignees: parsedAssignees,
      shares: parsedShares,
      userRole: json['userRole'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'in_progress':
        return 'Đang thực hiện';
      case 'completed':
        return 'Đã hoàn thành';
      case 'todo':
      default:
        return 'Chưa thực hiện';
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      case 'medium':
      default:
        return 'Trung bình';
    }
  }

  String get userRoleLabel {
    switch (userRole) {
      case 'creator':
        return 'Người tạo';
      case 'assignee':
        return 'Người phụ trách';
      case 'editor':
        return 'Được chia sẻ (Chỉnh sửa)';
      case 'viewer':
        return 'Được chia sẻ (Chỉ xem)';
      default:
        return 'Thành viên';
    }
  }
}
