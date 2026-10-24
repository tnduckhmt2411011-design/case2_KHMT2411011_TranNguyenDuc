import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/task_card.dart';
import '../auth/login_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _taskService = TaskService();
  final _authService = AuthService();

  // Danh sach tasks theo tab
  List<Task> _createdTasks = [];
  List<Task> _assignedTasks = [];
  List<Task> _sharedTasks = [];

  // Trang thai loading theo tab
  bool _isLoadingCreated = true;
  bool _isLoadingAssigned = true;
  bool _isLoadingShared = true;

  // Trang thai loi theo tab
  String? _errorCreated;
  String? _errorAssigned;
  String? _errorShared;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllTabs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTabs() async {
    await Future.wait([
      _loadCreatedTasks(),
      _loadAssignedTasks(),
      _loadSharedTasks(),
    ]);
  }

  Future<void> _loadCreatedTasks() async {
    setState(() {
      _isLoadingCreated = true;
      _errorCreated = null;
    });
    try {
      final tasks = await _taskService.getTasks(scope: 'created');
      if (!mounted) return;
      setState(() {
        _createdTasks = tasks;
        _isLoadingCreated = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      setState(() {
        _errorCreated = e.message;
        _isLoadingCreated = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCreated = 'Lỗi kết nối: ${e.toString()}';
        _isLoadingCreated = false;
      });
    }
  }

  Future<void> _loadAssignedTasks() async {
    setState(() {
      _isLoadingAssigned = true;
      _errorAssigned = null;
    });
    try {
      final tasks = await _taskService.getTasks(scope: 'assigned');
      if (!mounted) return;
      setState(() {
        _assignedTasks = tasks;
        _isLoadingAssigned = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      setState(() {
        _errorAssigned = e.message;
        _isLoadingAssigned = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAssigned = 'Lỗi kết nối: ${e.toString()}';
        _isLoadingAssigned = false;
      });
    }
  }

  Future<void> _loadSharedTasks() async {
    setState(() {
      _isLoadingShared = true;
      _errorShared = null;
    });
    try {
      final tasks = await _taskService.getTasks(scope: 'shared');
      if (!mounted) return;
      setState(() {
        _sharedTasks = tasks;
        _isLoadingShared = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      setState(() {
        _errorShared = e.message;
        _isLoadingShared = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorShared = 'Lỗi kết nối: ${e.toString()}';
        _isLoadingShared = false;
      });
    }
  }

  void _redirectToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
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
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authService.logout();
      if (!mounted) return;
      _redirectToLogin();
    }
  }

  Widget _buildTabContent({
    required bool isLoading,
    required String? error,
    required List<Task> tasks,
    required Future<void> Function() onRefresh,
    required String emptyMessage,
  }) {
    if (isLoading) {
      return const LoadingView(message: 'Đang tải danh sách công việc...');
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      emptyMessage,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskCard(
            task: task,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: task.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _loadAllTabs,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Của tôi', icon: Icon(Icons.person)),
            Tab(text: 'Được giao', icon: Icon(Icons.assignment_ind)),
            Tab(text: 'Được chia sẻ', icon: Icon(Icons.share)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(
            isLoading: _isLoadingCreated,
            error: _errorCreated,
            tasks: _createdTasks,
            onRefresh: _loadCreatedTasks,
            emptyMessage: 'Bạn chưa tạo công việc nào.',
          ),
          _buildTabContent(
            isLoading: _isLoadingAssigned,
            error: _errorAssigned,
            tasks: _assignedTasks,
            onRefresh: _loadAssignedTasks,
            emptyMessage: 'Chưa có công việc nào được giao cho bạn.',
          ),
          _buildTabContent(
            isLoading: _isLoadingShared,
            error: _errorShared,
            tasks: _sharedTasks,
            onRefresh: _loadSharedTasks,
            emptyMessage: 'Chưa có công việc nào được chia sẻ với bạn.',
          ),
        ],
      ),
    );
  }
}
