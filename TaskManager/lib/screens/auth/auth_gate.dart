import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../tasks/task_list_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  bool _isLoading = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _targetScreen = const LoginScreen();
          _isLoading = false;
        });
      }
      return;
    }

    try {
      await _authService.getMe();
      if (mounted) {
        setState(() {
          _targetScreen = const TaskListScreen();
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      // 401: Token khong hop le hoac da het han -> xoa token ve dang nhap
      if (e.statusCode == 401) {
        await _authService.logout();
        if (mounted) {
          setState(() {
            _targetScreen = const LoginScreen();
            _isLoading = false;
          });
        }
      } else {
        // Loi may chu hoac mang: cho phep thu lai hoac vao man hinh loi
        if (mounted) {
          setState(() {
            _targetScreen = _buildErrorView(e.message);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _targetScreen = _buildErrorView('Lỗi kết nối máy chủ: ${e.toString()}');
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildErrorView(String message) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _checkAuth();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await _authService.logout();
                  if (mounted) {
                    setState(() {
                      _targetScreen = const LoginScreen();
                    });
                  }
                },
                child: const Text('Về màn hình đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _targetScreen ?? const LoginScreen();
  }
}
