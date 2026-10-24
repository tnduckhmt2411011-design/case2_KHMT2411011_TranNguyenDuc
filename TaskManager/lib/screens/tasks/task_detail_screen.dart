import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../auth/login_screen.dart';

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
      if (!mounted) return;
      setState(() {
        _task = task;
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
