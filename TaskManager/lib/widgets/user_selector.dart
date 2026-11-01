import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class UserSelector extends StatefulWidget {
  final List<User> initialSelected;
  final ValueChanged<List<User>> onSelectedChanged;
  final List<String> excludedUserIds;
  final String title;
  final bool singleSelect;

  const UserSelector({
    super.key,
    this.initialSelected = const [],
    required this.onSelectedChanged,
    this.excludedUserIds = const [],
    this.title = 'Tìm và chọn người dùng',
    this.singleSelect = false,
  });

  @override
  State<UserSelector> createState() => _UserSelectorState();
}

class _UserSelectorState extends State<UserSelector> {
  final _searchController = TextEditingController();
  final _userService = UserService();
  Timer? _debounceTimer;

  List<User> _selectedUsers = [];
  List<User> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _selectedUsers = List.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _isSearching = true;
        _searchError = null;
      });

      try {
        final results = await _userService.searchUsers(trimmed);
        if (!mounted) return;
        setState(() {
          _searchResults = results
              .where((u) => !widget.excludedUserIds.contains(u.id))
              .toList();
          _isSearching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchError = 'Lỗi tìm kiếm: ${e.toString()}';
          _isSearching = false;
        });
      }
    });
  }

  void _toggleUser(User user) {
    setState(() {
      final exists = _selectedUsers.any((u) => u.id == user.id);

      if (widget.singleSelect) {
        _selectedUsers = exists ? [] : [user];
      } else if (exists) {
        _selectedUsers.removeWhere((u) => u.id == user.id);
      } else {
        _selectedUsers.add(user);
      }
    });
    widget.onSelectedChanged(_selectedUsers);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Danh sach nhung nguoi da chon (Chips)
        if (_selectedUsers.isNotEmpty) ...[
          const Text(
            'Đã chọn:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _selectedUsers.map((user) {
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
                label: Text(user.fullName),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _toggleUser(user),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // O tim kiem
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: widget.title,
            hintText: 'Nhập ít nhất 2 ký tự (tên hoặc email)...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 8),

        // Trang thai loading
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        // Bao loi
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _searchError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),

        // Ket qua tim kiem
        if (!_isSearching && _searchResults.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final isSelected = _selectedUsers.any((u) => u.id == user.id);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (_) => _toggleUser(user),
                  title: Text(user.fullName),
                  subtitle: Text(user.email),
                  secondary: CircleAvatar(
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    ),
                  ),
                );
              },
            ),
          ),
        ] else if (!_isSearching &&
            _searchController.text.trim().length >= 2 &&
            _searchResults.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'Không tìm thấy người dùng phù hợp',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
