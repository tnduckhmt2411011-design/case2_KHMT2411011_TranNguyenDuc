import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/task_activity.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../assignment/assign_task_screen.dart';
import '../auth/login_screen.dart';
import '../sharing/task_sharing_screen.dart';
import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _taskService = TaskService();

  bool _isLoading = true;
  String? _errorMessage;
  Task? _task;
  List<TaskActivity> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final task = await _taskService.getTaskById(widget.taskId);

      List<TaskActivity> activities = [];
      try {
        activities = await _taskService.getTaskActivities(widget.taskId);
      } on ApiException catch (e) {
        if (e.statusCode == 401) rethrow;
        activities = [];
      }

      if (!mounted) return;
      setState(() {
        _task = task;
        _activities = activities;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi không xác định: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa công việc này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _taskService.deleteTask(widget.taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa công việc'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleChangeStatus() async {
    final task = _task;
    if (task == null) return;

    final statuses = ['todo', 'in_progress', 'completed'];
    final labels = ['Chưa thực hiện', 'Đang thực hiện', 'Đã hoàn thành'];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Đổi trạng thái'),
        children: List.generate(statuses.length, (i) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(statuses[i]),
            child: Row(
              children: [
                if (task.status == statuses[i])
                  const Icon(Icons.check, color: Colors.green, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Text(labels[i]),
              ],
            ),
          );
        }),
      ),
    );

    if (selected == null || selected == task.status || !mounted) return;

    try {
      await _taskService.updateTaskStatus(taskId: widget.taskId, status: selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đổi trạng thái'), backgroundColor: Colors.green),
      );
      _fetchDetail();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleEdit() async {
    final task = _task;
    if (task == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskEditScreen(task: task)),
    );

    if (result == true && mounted) {
      _fetchDetail();
    }
  }

  Future<void> _handleAssign() async {
    final task = _task;
    if (task == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssignTaskScreen(
          taskId: task.id,
          taskTitle: task.title,
        ),
      ),
    );

    if (mounted) {
      _fetchDetail();
    }
  }

  Future<void> _handleShare() async {
    final task = _task;
    if (task == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskSharingScreen(
          taskId: task.id,
          taskTitle: task.title,
          createdById: task.createdBy?.id,
        ),
      ),
    );

    if (mounted) {
      _fetchDetail();
    }
  }

  Future<void> _handleViewEmailLogs() async {
    final task = _task;
    if (task == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final logs = await _taskService.getTaskEmailLogs(task.id);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      _showEmailLogsDialog(logs);
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (e.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.statusCode == 403
              ? 'Bạn không có quyền xem nhật ký email của công việc này.'
              : e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEmailLogsDialog(List<Map<String, dynamic>> logs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhật ký gửi email'),
        content: SizedBox(
          width: double.maxFinite,
          child: logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Chưa có email nào được gửi cho công việc này.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) {
                    final log = logs[index];
                    final status = log['status']?.toString() ?? 'unknown';
                    final recipient = log['recipientEmail']?.toString() ?? '';
                    final subject = log['subject']?.toString() ?? '';
                    final eventType = log['eventType']?.toString() ?? '';
                    final isSent = status == 'sent';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSent ? Icons.check_circle : Icons.error_outline,
                        color: isSent ? Colors.green : Colors.red,
                      ),
                      title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đến: $recipient', style: const TextStyle(fontSize: 12)),
                          Text('Sự kiện: $eventType | Trạng thái: $status', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline;
      case 'updated':
        return Icons.edit_outlined;
      case 'status_changed':
        return Icons.swap_horiz;
      case 'assigned':
        return Icons.person_add_alt_1;
      case 'unassigned':
        return Icons.person_remove_alt_1;
      case 'primary_changed':
        return Icons.star_outline;
      case 'shared':
        return Icons.share_outlined;
      case 'share_updated':
        return Icons.manage_accounts_outlined;
      case 'share_revoked':
        return Icons.link_off;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _fetchDetail,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView(message: 'Đang tải chi tiết công việc...');
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_task == null) {
      return const Center(child: Text('Không tìm thấy thông tin công việc.'));
    }

    final task = _task!;
    final perms = task.permissions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tieu de
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Badges: Status & Priority & Role
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(status: task.status),
              PriorityBadge(priority: task.priority),
              if (task.userRole != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Vai trò của bạn: ${task.userRoleLabel}',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Nut hanh dong theo quyen
          if (perms != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (perms.canEdit)
                  ElevatedButton.icon(
                    onPressed: _handleEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Sửa'),
                  ),
                if (perms.canChangeStatus)
                  OutlinedButton.icon(
                    onPressed: _handleChangeStatus,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Đổi trạng thái'),
                  ),
                if (perms.canAssign)
                  ElevatedButton.icon(
                    onPressed: _handleAssign,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Giao việc'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (perms.canShare)
                  ElevatedButton.icon(
                    onPressed: _handleShare,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Chia sẻ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (perms.canViewEmailLogs)
                  ElevatedButton.icon(
                    onPressed: _handleViewEmailLogs,
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Lịch sử email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (perms.canDelete)
                  ElevatedButton.icon(
                    onPressed: _handleDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Xóa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          const Divider(),
          const SizedBox(height: 8),

          // Mo ta
          const Text(
            'Mô tả công việc',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              task.description.isNotEmpty ? task.description : 'Không có mô tả chi tiết.',
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),

          // Thoi gian
          const Text(
            'Thời gian thực hiện',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.date_range, color: Colors.blue),
            title: const Text('Ngày bắt đầu'),
            subtitle: Text(DateFormatter.formatDate(task.startDate)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy, color: Colors.red),
            title: const Text('Hạn hoàn thành'),
            subtitle: Text(DateFormatter.formatDate(task.dueDate)),
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Nguoi tao
          const Text(
            'Người tạo công việc',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (task.createdBy != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(task.createdBy!.fullName.isNotEmpty ? task.createdBy!.fullName[0].toUpperCase() : 'U'),
              ),
              title: Text(task.createdBy!.fullName),
              subtitle: Text(task.createdBy!.email),
            )
          else
            const Text('Không có thông tin người tạo'),
          const SizedBox(height: 16),

          // Nguoi phu trach chinh
          const Text(
            'Người phụ trách chính',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (task.primaryAssignee != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.amber.shade100,
                child: Text(
                  task.primaryAssignee!.fullName.isNotEmpty ? task.primaryAssignee!.fullName[0].toUpperCase() : 'A',
                  style: TextStyle(color: Colors.amber.shade900),
                ),
              ),
              title: Text(task.primaryAssignee!.fullName),
              subtitle: Text(task.primaryAssignee!.email),
            )
          else
            const Text('Chưa chỉ định người phụ trách chính'),
          const SizedBox(height: 16),

          // Danh sach nguoi duoc giao
          const Text(
            'Danh sách người được giao',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (task.assignees.isNotEmpty)
            ...task.assignees.map(
              (user) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
                title: Text(user.fullName),
                subtitle: Text(user.email),
              ),
            )
          else
            const Text('Chưa có ai được giao công việc này'),
          const SizedBox(height: 16),

          // Danh sach chia se
          const Text(
            'Danh sách người được chia sẻ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (task.shares.isNotEmpty)
            ...task.shares.map(
              (share) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Text(
                    share.user != null && share.user!.fullName.isNotEmpty
                        ? share.user!.fullName[0].toUpperCase()
                        : 'S',
                    style: TextStyle(color: Colors.purple.shade900),
                  ),
                ),
                title: Text(share.user?.fullName ?? 'Người dùng'),
                subtitle: Text(share.user?.email ?? ''),
                trailing: Chip(
                  label: Text(
                    share.permissionLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: share.permission == 'editor'
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                ),
              ),
            )
          else
            const Text('Công việc chưa được chia sẻ cho ai'),
          const SizedBox(height: 16),

          // Lich su hoat dong
          const Text(
            'Lịch sử hoạt động',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_activities.isEmpty)
            const Text('Chưa có hoạt động nào được ghi lại')
          else
            ..._activities.map(
              (activity) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    _activityIcon(activity.action),
                    size: 20,
                    color: Colors.grey.shade800,
                  ),
                ),
                title: Text(
                  activity.user?.fullName ?? 'Hệ thống',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.actionLabel),
                    if (activity.actionDetails.isNotEmpty)
                      Text(
                        activity.actionDetails,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      DateFormatter.formatDateTime(activity.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
