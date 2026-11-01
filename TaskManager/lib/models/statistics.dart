class StatusCount {
  final int todo;
  final int inProgress;
  final int completed;

  StatusCount({
    required this.todo,
    required this.inProgress,
    required this.completed,
  });

  factory StatusCount.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    return StatusCount(
      todo: (data['todo'] as num?)?.toInt() ?? 0,
      inProgress: (data['in_progress'] as num?)?.toInt() ?? 0,
      completed: (data['completed'] as num?)?.toInt() ?? 0,
    );
  }
}

class PriorityCount {
  final int low;
  final int medium;
  final int high;

  PriorityCount({
    required this.low,
    required this.medium,
    required this.high,
  });

  factory PriorityCount.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    return PriorityCount(
      low: (data['low'] as num?)?.toInt() ?? 0,
      medium: (data['medium'] as num?)?.toInt() ?? 0,
      high: (data['high'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeadlineTask {
  final String id;
  final String title;
  final String status;
  final String priority;
  final DateTime? dueDate;

  DeadlineTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.dueDate,
  });

  factory DeadlineTask.fromJson(Map<String, dynamic> json) {
    return DeadlineTask(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      status: json['status'] ?? '',
      priority: json['priority'] ?? '',
      dueDate:
          json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
    );
  }
}

class TaskStatistics {
  final int total;
  final StatusCount byStatus;
  final PriorityCount byPriority;

  TaskStatistics({
    required this.total,
    required this.byStatus,
    required this.byPriority,
  });

  factory TaskStatistics.fromJson(Map<String, dynamic> json) {
    return TaskStatistics(
      total: (json['total'] as num?)?.toInt() ?? 0,
      byStatus: StatusCount.fromJson(json['byStatus'] as Map<String, dynamic>?),
      byPriority:
          PriorityCount.fromJson(json['byPriority'] as Map<String, dynamic>?),
    );
  }
}

class AssignmentStatistics {
  final int totalAssigned;
  final int totalPrimary;
  final StatusCount assignedByStatus;
  final StatusCount primaryByStatus;

  AssignmentStatistics({
    required this.totalAssigned,
    required this.totalPrimary,
    required this.assignedByStatus,
    required this.primaryByStatus,
  });

  factory AssignmentStatistics.fromJson(Map<String, dynamic> json) {
    return AssignmentStatistics(
      totalAssigned: (json['totalAssigned'] as num?)?.toInt() ?? 0,
      totalPrimary: (json['totalPrimary'] as num?)?.toInt() ?? 0,
      assignedByStatus: StatusCount.fromJson(
        json['assignedByStatus'] as Map<String, dynamic>?,
      ),
      primaryByStatus: StatusCount.fromJson(
        json['primaryByStatus'] as Map<String, dynamic>?,
      ),
    );
  }
}

class DeadlineStatistics {
  final int windowHours;
  final int overdueCount;
  final int upcomingCount;
  final List<DeadlineTask> overdue;
  final List<DeadlineTask> upcoming;

  DeadlineStatistics({
    required this.windowHours,
    required this.overdueCount,
    required this.upcomingCount,
    required this.overdue,
    required this.upcoming,
  });

  factory DeadlineStatistics.fromJson(Map<String, dynamic> json) {
    final overdue = (json['overdue'] as List? ?? const [])
        .map((item) => DeadlineTask.fromJson(item as Map<String, dynamic>))
        .toList();
    final upcoming = (json['upcoming'] as List? ?? const [])
        .map((item) => DeadlineTask.fromJson(item as Map<String, dynamic>))
        .toList();

    return DeadlineStatistics(
      windowHours: (json['windowHours'] as num?)?.toInt() ?? 24,
      overdueCount: (json['overdueCount'] as num?)?.toInt() ?? overdue.length,
      upcomingCount:
          (json['upcomingCount'] as num?)?.toInt() ?? upcoming.length,
      overdue: overdue,
      upcoming: upcoming,
    );
  }
}
