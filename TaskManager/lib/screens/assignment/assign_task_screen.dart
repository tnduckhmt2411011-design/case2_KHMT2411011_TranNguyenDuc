import 'package:flutter/material.dart';
import '../../models/task_share.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/task_share_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/user_selector.dart';
import '../auth/login_screen.dart';

class AssignTaskScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const AssignTaskScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _shareService = TaskShareService();

  bool _isLoading = true;
  String? _errorMessage;
  List<TaskAssignee> _currentAssignees = [];

  List<User> _selectedNewUsers = [];
  String? _selectedPrimaryId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchAssignees();
  }

  Future<void> _fetchAssignees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _shareService.getAssignees(widget.taskId);
      if (!mounted) return;
      setState(() {
        _currentAssignees = list;
        _isLoading = false;
        // Neu da co nguoi phu trach chinh thi mac dinh chon nguoi do
        final currentPrimary = list.where((a) => a.isPrimary).firstOrNull;
        if (currentPrimary != null) {
          _selectedPrimaryId = currentPrimary.user.id;
        }
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
        _errorMessage = 'Lỗi tải danh sách người được giao: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAssign() async {
    if (_selectedNewUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một người dùng để giao việc'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _shareService.assignUsers(
        widget.taskId,
        userIds: _selectedNewUsers.map((u) => u.id).toList(),
        primaryAssigneeId: _selectedPrimaryId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giao việc thành công'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _selectedNewUsers = [];
      });
      await _fetchAssignees();
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSetPrimary(String userId) async {
    try {
      await _shareService.setPrimaryAssignee(widget.taskId, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật người phụ trách chính'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetchAssignees();
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

  Future<void> _handleRemoveAssignee(TaskAssignee assignee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy giao việc'),
        content: Text('Bạn có chắc chắn muốn hủy giao việc cho "${assignee.user.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hủy giao việc'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _shareService.removeAssignee(widget.taskId, assignee.user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy giao việc thành công'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetchAssignees();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao việc'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Đang tải danh sách người được giao...')
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 56, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchAssignees,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ten cong viec
                      Text(
                        'Công việc: ${widget.taskTitle}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),

                      // Danh sach hien tai
                      const Text(
                        'Người đang được giao việc:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_currentAssignees.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Chưa có ai được giao công việc này.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ..._currentAssignees.map((assignee) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: assignee.isPrimary
                                    ? Colors.amber.shade100
                                    : Colors.blue.shade100,
                                child: Text(
                                  assignee.user.fullName.isNotEmpty
                                      ? assignee.user.fullName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: assignee.isPrimary
                                        ? Colors.amber.shade900
                                        : Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(assignee.user.fullName),
                              subtitle: Text(assignee.user.email),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (assignee.isPrimary)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber.shade300),
                                      ),
                                      child: Text(
                                        'Chính',
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () => _handleSetPrimary(assignee.user.id),
                                      child: const Text('Đặt làm chính'),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Hủy giao việc',
                                    onPressed: () => _handleRemoveAssignee(assignee),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Giao them nguoi moi
                      const Text(
                        'Thêm người nhận việc mới:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      UserSelector(
                        title: 'Tìm người dùng để giao việc',
                        excludedUserIds: _currentAssignees.map((a) => a.user.id).toList(),
                        onSelectedChanged: (users) {
                          setState(() {
                            _selectedNewUsers = users;
                            if (_selectedPrimaryId == null && users.isNotEmpty) {
                              _selectedPrimaryId = users.first.id;
                            }
                          });
                        },
                      ),

                      if (_selectedNewUsers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Chọn người phụ trách chính:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        // Danh sach nguoi co the chon lam chinh: gom ca nguoi hien tai va nguoi moi chon
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPrimaryId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Người phụ trách chính',
                          ),
                          items: [
                            ..._currentAssignees.map(
                              (a) => DropdownMenuItem(
                                value: a.user.id,
                                child: Text('${a.user.fullName} (Đang được giao)'),
                              ),
                            ),
                            ..._selectedNewUsers.map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text('${u.fullName} (Mới thêm)'),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedPrimaryId = val);
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitAssign,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_add),
                          label: const Text('Xác nhận giao việc'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
