import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../auth/login_screen.dart';
import '../tasks/task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _notificationService = NotificationService();

  bool _isLoading = true;
  bool _isMarkingAll = false;
  String? _errorMessage;
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _notificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
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
        _errorMessage = 'Lỗi kết nối: ${e.toString()}';
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

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    try {
      final updated = await _notificationService.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleOpenNotification(AppNotification notification) async {
    await _markAsRead(notification);

    if (!mounted || notification.taskId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(taskId: notification.taskId!),
      ),
    );

    if (mounted) {
      _fetchNotifications();
    }
  }

  Future<void> _handleMarkAllAsRead() async {
    if (_isMarkingAll || _unreadCount == 0) return;

    setState(() => _isMarkingAll = true);

    try {
      final modified = await _notificationService.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => item.copyWith(isRead: true))
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đánh dấu $modified thông báo là đã đọc'),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.person_add_alt_1;
      case 'task_shared':
        return Icons.share;
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'task_due_changed':
        return Icons.event_busy;
      case 'task_status_changed':
      default:
        return Icons.swap_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _fetchNotifications,
          ),
          TextButton.icon(
            onPressed: (_isMarkingAll || _unreadCount == 0)
                ? null
                : _handleMarkAllAsRead,
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Đọc tất cả'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView(message: 'Đang tải thông báo...');
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchNotifications,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bạn chưa có thông báo nào.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_unreadCount > 0)
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Bạn có $_unreadCount thông báo chưa đọc',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchNotifications,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return ListTile(
                  onTap: () => _handleOpenNotification(notification),
                  tileColor: notification.isRead ? null : Colors.blue.shade50,
                  leading: CircleAvatar(
                    backgroundColor: notification.isRead
                        ? Colors.grey.shade200
                        : Colors.blue.shade100,
                    child: Icon(
                      _iconForType(notification.type),
                      color: notification.isRead
                          ? Colors.grey.shade700
                          : Colors.blue.shade800,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notification.message),
                      const SizedBox(height: 4),
                      Text(
                        '${notification.typeLabel} • ${DateFormatter.formatDateTime(notification.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
