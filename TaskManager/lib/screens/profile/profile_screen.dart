import 'package:flutter/material.dart';
import '../../models/statistics.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/statistics_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _statisticsService = StatisticsService();

  bool _isLoading = true;
  String? _errorMessage;
  User? _user;
  TaskStatistics? _taskStatistics;
  AssignmentStatistics? _assignmentStatistics;
  DeadlineStatistics? _deadlineStatistics;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _authService.getMe(),
        _statisticsService.getTaskStatistics(),
        _statisticsService.getAssignmentStatistics(),
        _statisticsService.getDeadlineStatistics(),
      ]);

      if (!mounted) return;
      setState(() {
        _user = results[0] as User;
        _taskStatistics = results[1] as TaskStatistics;
        _assignmentStatistics = results[2] as AssignmentStatistics;
        _deadlineStatistics = results[3] as DeadlineStatistics;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _redirectToLogin();
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

  void _redirectToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handleEditProfile() async {
    final user = _user;
    if (user == null) return;

    final fullNameController = TextEditingController(text: user.fullName);
    final avatarController = TextEditingController(text: user.avatarUrl ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cập nhật hồ sơ'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Họ và tên không được để trống';
                    }
                    if (value.trim().length > 100) {
                      return 'Họ và tên không được vượt quá 100 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: avatarController,
                  decoration: const InputDecoration(
                    labelText: 'Đường dẫn ảnh đại diện (tùy chọn)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().length > 500) {
                      return 'Đường dẫn ảnh không được vượt quá 500 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Email đăng nhập: ${user.email} (không thể thay đổi)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    try {
      final updated = await _authService.updateProfile(
        fullName: fullNameController.text.trim(),
        avatarUrl: avatarController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _user = updated);
      _showMessage('Cập nhật hồ sơ thành công');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      _showMessage(e.message, isError: true);
    }
  }

  Future<void> _handleChangePassword() async {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Vui lòng nhập mật khẩu hiện tại'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu mới';
                    }
                    if (value.length < 6) {
                      return 'Mật khẩu mới phải có ít nhất 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu mới',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value != newController.text
                      ? 'Mật khẩu nhập lại không khớp'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );

    if (submitted != true) return;

    try {
      await _authService.changePassword(
        currentPassword: currentController.text,
        newPassword: newController.text,
      );
      _showMessage('Đổi mật khẩu thành công');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      _showMessage(e.message, isError: true);
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    _redirectToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản & thống kê'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _fetchAll,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView(message: 'Đang tải thông tin tài khoản...');
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
                onPressed: _fetchAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user;
    if (user == null) {
      return const Center(child: Text('Không tìm thấy thông tin tài khoản.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildUserCard(user),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleEditProfile,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Sửa hồ sơ'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleChangePassword,
                icon: const Icon(Icons.lock_reset, size: 18),
                label: const Text('Đổi mật khẩu'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTaskStatistics(),
        const SizedBox(height: 16),
        _buildAssignmentStatistics(),
        const SizedBox(height: 16),
        _buildDeadlineStatistics(),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.blue.shade900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (user.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tham gia: ${DateFormatter.formatDate(user.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, int value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatistics() {
    final stats = _taskStatistics;
    if (stats == null) return const SizedBox.shrink();

    return _sectionCard(
      title: 'Thống kê công việc của tôi',
      child: Column(
        children: [
          _statRow('Tổng số công việc', stats.total),
          const Divider(),
          _statRow('Chưa thực hiện', stats.byStatus.todo),
          _statRow(
            'Đang thực hiện',
            stats.byStatus.inProgress,
            color: Colors.orange.shade800,
          ),
          _statRow(
            'Đã hoàn thành',
            stats.byStatus.completed,
            color: Colors.green.shade700,
          ),
          const Divider(),
          _statRow('Ưu tiên thấp', stats.byPriority.low),
          _statRow('Ưu tiên trung bình', stats.byPriority.medium),
          _statRow(
            'Ưu tiên cao',
            stats.byPriority.high,
            color: Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentStatistics() {
    final stats = _assignmentStatistics;
    if (stats == null) return const SizedBox.shrink();

    return _sectionCard(
      title: 'Thống kê công việc được giao',
      child: Column(
        children: [
          _statRow('Tổng số được giao', stats.totalAssigned),
          _statRow(
            'Là người phụ trách chính',
            stats.totalPrimary,
            color: Colors.indigo,
          ),
          const Divider(),
          _statRow('Chưa thực hiện', stats.assignedByStatus.todo),
          _statRow('Đang thực hiện', stats.assignedByStatus.inProgress),
          _statRow(
            'Đã hoàn thành',
            stats.assignedByStatus.completed,
            color: Colors.green.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineStatistics() {
    final stats = _deadlineStatistics;
    if (stats == null) return const SizedBox.shrink();

    return _sectionCard(
      title: 'Thống kê hạn hoàn thành',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statRow(
            'Quá hạn',
            stats.overdueCount,
            color: Colors.red.shade700,
          ),
          _statRow(
            'Sắp đến hạn (${stats.windowHours} giờ)',
            stats.upcomingCount,
            color: Colors.orange.shade800,
          ),
          if (stats.overdue.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Công việc quá hạn',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            ...stats.overdue.take(5).map(
                  (task) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: Text(task.title),
                    subtitle: Text('Hạn: ${DateFormatter.formatDate(task.dueDate)}'),
                  ),
                ),
          ],
          if (stats.upcoming.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Công việc sắp đến hạn',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            ...stats.upcoming.take(5).map(
                  (task) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(
                      Icons.schedule,
                      color: Colors.orange,
                    ),
                    title: Text(task.title),
                    subtitle: Text('Hạn: ${DateFormatter.formatDate(task.dueDate)}'),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
