import 'package:flutter/material.dart';
import '../../models/task_share.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/task_share_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/user_selector.dart';
import '../auth/login_screen.dart';

class TaskSharingScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String? createdById;

  const TaskSharingScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.createdById,
  });

  @override
  State<TaskSharingScreen> createState() => _TaskSharingScreenState();
}

class _TaskSharingScreenState extends State<TaskSharingScreen> {
  final _shareService = TaskShareService();

  bool _isLoading = true;
  String? _errorMessage;
  List<TaskShare> _currentShares = [];

  List<User> _selectedUsers = [];
  String _newPermission = 'viewer';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchShares();
  }

  Future<void> _fetchShares() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _shareService.getShares(widget.taskId);
      if (!mounted) return;
      setState(() {
        _currentShares = list;
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
        _errorMessage = 'Lỗi tải danh sách chia sẻ: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitShare() async {
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một người để chia sẻ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await _shareService.createShares(
        widget.taskId,
        userIds: _selectedUsers.map((u) => u.id).toList(),
        permission: _newPermission,
      );

      if (!mounted) return;

      final createdCount = (res['created'] as List?)?.length ?? 0;
      final skippedCount = (res['skipped'] as List?)?.length ?? 0;

      String message = 'Đã chia sẻ thành công cho $createdCount người';
      if (skippedCount > 0) {
        message += ' (Bỏ qua $skippedCount người đã được chia sẻ trước đó)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );

      setState(() {
        _selectedUsers = [];
      });
      await _fetchShares();
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

  Future<void> _handleChangePermission(TaskShare share) async {
    final nextPermission = share.permission == 'editor' ? 'viewer' : 'editor';
    final actionText = nextPermission == 'editor' ? 'Chỉnh sửa (Editor)' : 'Chỉ xem (Viewer)';

    try {
      await _shareService.updateShare(widget.taskId, share.id, nextPermission);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đổi quyền thành $actionText'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetchShares();
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

  Future<void> _handleRevokeShare(TaskShare share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi quyền chia sẻ'),
        content: Text(
          'Bạn có chắc chắn muốn thu hồi quyền truy cập của "${share.user?.fullName ?? 'người này'}"?',
        ),
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
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _shareService.deleteShare(widget.taskId, share.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thu hồi quyền chia sẻ thành công'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetchShares();
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
    // Danh sach cac id can loai bo khoi tim kiem: nguoi tao + nhung nguoi da duoc chia se
    final excludedIds = <String>[];
    if (widget.createdById != null) {
      excludedIds.add(widget.createdById!);
    }
    for (final s in _currentShares) {
      if (s.user != null) {
        excludedIds.add(s.user!.id);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ công việc'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Đang tải danh sách chia sẻ...')
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
                          onPressed: _fetchShares,
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
                        'Người đang được chia sẻ:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_currentShares.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Chưa có ai được chia sẻ công việc này.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ..._currentShares.map((share) {
                          final isEditor = share.permission == 'editor';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isEditor
                                    ? Colors.orange.shade100
                                    : Colors.blue.shade100,
                                child: Text(
                                  share.user != null && share.user!.fullName.isNotEmpty
                                      ? share.user!.fullName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: isEditor
                                        ? Colors.orange.shade900
                                        : Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(share.user?.fullName ?? 'Người dùng'),
                              subtitle: Text(share.user?.email ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Nut chuyen doi quyen viewer <-> editor
                                  ActionChip(
                                    label: Text(
                                      share.permissionLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isEditor
                                            ? Colors.orange.shade900
                                            : Colors.blue.shade900,
                                      ),
                                    ),
                                    backgroundColor: isEditor
                                        ? Colors.orange.shade50
                                        : Colors.blue.shade50,
                                    onPressed: () => _handleChangePermission(share),
                                    tooltip: 'Nhấn để đổi quyền',
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Thu hồi quyền',
                                    onPressed: () => _handleRevokeShare(share),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Them nguoi chia se moi
                      const Text(
                        'Chia sẻ cho người mới:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      UserSelector(
                        title: 'Tìm người để chia sẻ',
                        excludedUserIds: excludedIds,
                        onSelectedChanged: (users) {
                          setState(() {
                            _selectedUsers = users;
                          });
                        },
                      ),

                      if (_selectedUsers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Chọn quyền truy cập:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'viewer',
                              label: Text('Chỉ xem (Viewer)'),
                              icon: Icon(Icons.visibility),
                            ),
                            ButtonSegment(
                              value: 'editor',
                              label: Text('Chỉnh sửa (Editor)'),
                              icon: Icon(Icons.edit),
                            ),
                          ],
                          selected: {_newPermission},
                          onSelectionChanged: (set) {
                            setState(() => _newPermission = set.first);
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitShare,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.share),
                          label: const Text('Xác nhận chia sẻ'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
