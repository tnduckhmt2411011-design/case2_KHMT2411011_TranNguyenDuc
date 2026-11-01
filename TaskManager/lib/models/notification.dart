class AppNotification {
  final String id;
  final String? userId;
  final String? taskId;
  final String? taskTitle;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    this.userId,
    this.taskId,
    this.taskTitle,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final task = json['task'];
    final taskMap = task is Map<String, dynamic> ? task : null;

    return AppNotification(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId']?.toString(),
      taskId: json['taskId']?.toString() ?? taskMap?['id']?.toString(),
      taskTitle: taskMap?['title']?.toString(),
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['isRead'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      taskId: taskId,
      taskTitle: taskTitle,
      type: type,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'task_assigned':
        return 'Giao việc';
      case 'task_shared':
        return 'Chia sẻ';
      case 'task_status_changed':
        return 'Đổi trạng thái';
      case 'task_completed':
        return 'Hoàn thành';
      case 'task_due_changed':
        return 'Đổi hạn';
      default:
        return 'Thông báo';
    }
  }
}
