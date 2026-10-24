import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/user.dart';
import 'package:task_manager/models/task.dart';
import 'package:task_manager/utils/validators.dart';
import 'package:task_manager/utils/date_formatter.dart';

void main() {
  group('Validators Test', () {
    test('validateFullName', () {
      expect(Validators.validateFullName(''), isNotNull);
      expect(Validators.validateFullName('   '), isNotNull);
      expect(Validators.validateFullName(null), isNotNull);
      expect(Validators.validateFullName('Tran Nguyen Duc'), isNull);
    });

    test('validateEmail', () {
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('user@domain'), isNotNull);
      expect(Validators.validateEmail('test@example.com'), isNull);
    });

    test('validatePassword', () {
      expect(Validators.validatePassword(''), isNotNull);
      expect(Validators.validatePassword('12345'), isNotNull);
      expect(Validators.validatePassword('123456'), isNull);
      expect(Validators.validatePassword('strongPassword!'), isNull);
    });

    test('validateConfirmPassword', () {
      expect(Validators.validateConfirmPassword('', '123456'), isNotNull);
      expect(Validators.validateConfirmPassword('1234567', '123456'), isNotNull);
      expect(Validators.validateConfirmPassword('123456', '123456'), isNull);
    });
  });

  group('User Model Test', () {
    test('fromJson & toJson', () {
      final json = {
        'id': '6adcd0f34e24dfd3c179d7fe',
        'fullName': 'Tran Nguyen Duc',
        'email': 'duc.tran@taskmanager.com',
        'avatarUrl': 'http://avatar.png',
        'createdAt': '2026-10-24T15:38:20.065Z',
      };
      final user = User.fromJson(json);
      expect(user.id, '6adcd0f34e24dfd3c179d7fe');
      expect(user.fullName, 'Tran Nguyen Duc');
      expect(user.email, 'duc.tran@taskmanager.com');
      expect(user.avatarUrl, 'http://avatar.png');
      expect(user.createdAt, isNotNull);

      final map = user.toJson();
      expect(map['id'], '6adcd0f34e24dfd3c179d7fe');
      expect(map['fullName'], 'Tran Nguyen Duc');
    });
  });

  group('Task Model Test', () {
    test('fromJson and Vietnamese labels', () {
      final json = {
        '_id': 'task_123',
        'title': 'Phat trien JWT',
        'description': 'Mo ta cong viec',
        'status': 'in_progress',
        'priority': 'high',
        'userRole': 'creator',
        'startDate': '2026-10-25T08:00:00.000Z',
        'dueDate': '2026-10-28T17:00:00.000Z',
        'createdBy': {
          '_id': 'user_1',
          'fullName': 'Tran Nguyen Duc',
          'email': 'duc.tran@taskmanager.com'
        },
        'primaryAssigneeId': {
          '_id': 'user_2',
          'fullName': 'Nguyen Van An',
          'email': 'an.nguyen@taskmanager.com'
        },
        'shares': [
          {
            '_id': 'share_1',
            'user': {
              '_id': 'user_3',
              'fullName': 'Le Thi Binh',
              'email': 'binh.le@taskmanager.com'
            },
            'permission': 'viewer'
          }
        ]
      };

      final task = Task.fromJson(json);
      expect(task.id, 'task_123');
      expect(task.title, 'Phat trien JWT');
      expect(task.statusLabel, 'Đang thực hiện');
      expect(task.priorityLabel, 'Cao');
      expect(task.userRoleLabel, 'Người tạo');
      expect(task.createdBy?.fullName, 'Tran Nguyen Duc');
      expect(task.primaryAssignee?.fullName, 'Nguyen Van An');
      expect(task.shares.length, 1);
      expect(task.shares.first.permissionLabel, 'Chỉ xem (Viewer)');
    });
  });

  group('DateFormatter Test', () {
    test('formatDate and formatDateTime', () {
      final dt = DateTime(2026, 10, 25, 8, 30);
      expect(DateFormatter.formatDate(dt), '25/10/2026');
      expect(DateFormatter.formatDate(null), 'Chưa thiết lập');
    });
  });
}
