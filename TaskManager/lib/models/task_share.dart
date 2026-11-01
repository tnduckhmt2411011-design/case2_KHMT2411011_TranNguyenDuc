import 'user.dart';

class TaskShare {
  final String id;
  final User? user;
  final String permission; // 'viewer' | 'editor'
  final User? sharedBy;
  final DateTime? createdAt;

  TaskShare({
    required this.id,
    this.user,
    required this.permission,
    this.sharedBy,
    this.createdAt,
  });

  factory TaskShare.fromJson(Map<String, dynamic> json) {
    return TaskShare(
      id: json['id'] ?? json['_id'] ?? '',
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'])
          : null,
      permission: json['permission'] ?? 'viewer',
      sharedBy: json['sharedBy'] != null && json['sharedBy'] is Map<String, dynamic>
          ? User.fromJson(json['sharedBy'])
          : null,
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

class TaskAssignee {
  final User user;
  final bool isPrimary;

  TaskAssignee({
    required this.user,
    this.isPrimary = false,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      isPrimary: json['isPrimary'] == true,
    );
  }
}
