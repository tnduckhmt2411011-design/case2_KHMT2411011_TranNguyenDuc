import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/task_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/task_card.dart';
import '../../widgets/user_selector.dart';
import '../auth/login_screen.dart';
import '../notifications/notification_screen.dart';
import 'task_create_screen.dart';
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

  int _unreadCount = 0;

  // Bo loc va sap xep danh sach
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _filterStatus = 'all';
  String _filterPriority = 'all';
  User? _filterAssignee;
  String _sortValue = 'createdAt_desc';

  String get _sortBy => _sortValue.split('_').first;
  String get _sortOrder => _sortValue.split('_').last;

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _filterStatus != 'all' ||
      _filterPriority != 'all' ||
      _filterAssignee != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllTabs();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Task>> _fetchTasks(String scope) {
    return _taskService.getTasks(
      scope: scope,
      q: _searchController.text,
      status: _filterStatus == 'all' ? null : _filterStatus,
      priority: _filterPriority == 'all' ? null : _filterPriority,
      assigneeId: _filterAssignee?.id,
      sortBy: _sortBy,
      order: _sortOrder,
    );
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
      final tasks = await _fetchTasks('created');
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
      final tasks = await _fetchTasks('assigned');
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
      final tasks = await _fetchTasks('shared');
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

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationService().getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _redirectToLogin();
      }
    } catch (_) {
      // Khong lam phien nguoi dung neu chi loi dem thong bao
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
    if (mounted) {
      _loadUnreadCount();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadAllTabs();
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _filterStatus = 'all';
      _filterPriority = 'all';
      _filterAssignee = null;
      _sortValue = 'createdAt_desc';
    });
    _loadAllTabs();
  }

  Future<void> _pickAssigneeFilter() async {
    User? selected = _filterAssignee;

    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Lọc theo người phụ trách'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: UserSelector(
                    title: 'Tìm người phụ trách',
                    singleSelect: true,
                    initialSelected: selected == null ? const [] : [selected!],
                    onSelectedChanged: (users) {
                      setDialogState(() {
                        selected = users.isEmpty ? null : users.first;
                      });
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Bỏ lọc'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Áp dụng'),
                ),
              ],
            );
          },
        );
      },
    );

    if (apply == null || !mounted) return;

    setState(() {
      _filterAssignee = apply ? selected : null;
    });
    _loadAllTabs();
  }

  Widget _buildFilterDropdown({
    required String value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          iconSize: 18,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: options.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên công việc...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Xóa từ khóa',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _loadAllTabs();
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdown(
                  value: _filterStatus,
                  options: const {
                    'all': 'Mọi trạng thái',
                    'todo': 'Chưa thực hiện',
                    'in_progress': 'Đang thực hiện',
                    'completed': 'Đã hoàn thành',
                  },
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _filterStatus = value);
                    _loadAllTabs();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  value: _filterPriority,
                  options: const {
                    'all': 'Mọi ưu tiên',
                    'low': 'Ưu tiên thấp',
                    'medium': 'Ưu tiên trung bình',
                    'high': 'Ưu tiên cao',
                  },
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _filterPriority = value);
                    _loadAllTabs();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  value: _sortValue,
                  options: const {
                    'createdAt_desc': 'Mới nhất',
                    'createdAt_asc': 'Cũ nhất',
                    'dueDate_asc': 'Hạn gần nhất',
                    'dueDate_desc': 'Hạn xa nhất',
                    'priority_desc': 'Ưu tiên cao trước',
                    'priority_asc': 'Ưu tiên thấp trước',
                  },
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortValue = value);
                    _loadAllTabs();
                  },
                ),
                const SizedBox(width: 8),
                if (_filterAssignee == null)
                  ActionChip(
                    avatar: const Icon(Icons.person_search, size: 18),
                    label: const Text('Người phụ trách'),
                    onPressed: _pickAssigneeFilter,
                  )
                else
                  InputChip(
                    avatar: const Icon(Icons.person, size: 18),
                    label: Text(_filterAssignee!.fullName),
                    onPressed: _pickAssigneeFilter,
                    onDeleted: () {
                      setState(() => _filterAssignee = null);
                      _loadAllTabs();
                    },
                  ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Xóa lọc'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

  Future<void> _handleCreateTask() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaskCreateScreen()),
    );
    if (result == true && mounted) {
      _loadAllTabs();
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
            onTap: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: task.id),
                ),
              );
              if (result == true && mounted) {
                _loadAllTabs();
              }
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
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Thông báo',
            onPressed: _openNotifications,
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _handleCreateTask,
        tooltip: 'Tạo công việc mới',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildFiltersBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(
                  isLoading: _isLoadingCreated,
                  error: _errorCreated,
                  tasks: _createdTasks,
                  onRefresh: _loadCreatedTasks,
                  emptyMessage: _hasActiveFilters
                      ? 'Không có công việc phù hợp với bộ lọc.'
                      : 'Bạn chưa tạo công việc nào.',
                ),
                _buildTabContent(
                  isLoading: _isLoadingAssigned,
                  error: _errorAssigned,
                  tasks: _assignedTasks,
                  onRefresh: _loadAssignedTasks,
                  emptyMessage: _hasActiveFilters
                      ? 'Không có công việc phù hợp với bộ lọc.'
                      : 'Chưa có công việc nào được giao cho bạn.',
                ),
                _buildTabContent(
                  isLoading: _isLoadingShared,
                  error: _errorShared,
                  tasks: _sharedTasks,
                  onRefresh: _loadSharedTasks,
                  emptyMessage: _hasActiveFilters
                      ? 'Không có công việc phù hợp với bộ lọc.'
                      : 'Chưa có công việc nào được chia sẻ với bạn.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
