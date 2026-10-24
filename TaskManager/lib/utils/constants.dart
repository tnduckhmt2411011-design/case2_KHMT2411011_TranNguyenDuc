import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api';
      }
    } catch (_) {
      // Fallback khi chay tren moi truong khong ho tro Platform.isAndroid
    }
    return 'http://localhost:3000/api';
  }

  static const String tokenKey = 'auth_token';
  static const Duration timeoutDuration = Duration(seconds: 10);
}
