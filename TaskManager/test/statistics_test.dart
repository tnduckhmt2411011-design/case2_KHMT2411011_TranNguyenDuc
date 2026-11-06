import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/statistics.dart';

void main() {
  group('Statistics Model Tests (E3)', () {
    test('TaskStatistics parses complete json correctly', () {
      final json = {
        'total': 12,
        'byStatus': {'todo': 4, 'in_progress': 3, 'completed': 5},
        'byPriority': {'low': 2, 'medium': 6, 'high': 4},
      };
      final stats = TaskStatistics.fromJson(json);
      expect(stats.total, 12);
      expect(stats.byStatus.todo, 4);
      expect(stats.byStatus.inProgress, 3);
      expect(stats.byStatus.completed, 5);
      expect(stats.byPriority.low, 2);
      expect(stats.byPriority.medium, 6);
      expect(stats.byPriority.high, 4);
    });

    test('TaskStatistics handles empty and null fields with default 0 without throwing', () {
      final stats = TaskStatistics.fromJson({});
      expect(stats.total, 0);
      expect(stats.byStatus.todo, 0);
      expect(stats.byStatus.inProgress, 0);
      expect(stats.byStatus.completed, 0);
      expect(stats.byPriority.low, 0);
      expect(stats.byPriority.medium, 0);
      expect(stats.byPriority.high, 0);

      final statsNullNested = TaskStatistics.fromJson({
        'total': null,
        'byStatus': null,
        'byPriority': null,
      });
      expect(statsNullNested.total, 0);
      expect(statsNullNested.byStatus.todo, 0);
      expect(statsNullNested.byPriority.high, 0);
    });

    test('AssignmentStatistics handles complete and empty fields', () {
      final stats = AssignmentStatistics.fromJson({
        'totalAssigned': 8,
        'totalPrimary': 3,
        'assignedByStatus': {'todo': 2, 'in_progress': 4, 'completed': 2},
        'primaryByStatus': {'todo': 1, 'in_progress': 1, 'completed': 1},
      });
      expect(stats.totalAssigned, 8);
      expect(stats.totalPrimary, 3);
      expect(stats.assignedByStatus.inProgress, 4);
      expect(stats.primaryByStatus.todo, 1);

      final emptyStats = AssignmentStatistics.fromJson({});
      expect(emptyStats.totalAssigned, 0);
      expect(emptyStats.totalPrimary, 0);
      expect(emptyStats.assignedByStatus.todo, 0);
      expect(emptyStats.primaryByStatus.completed, 0);
    });

    test('DeadlineStatistics handles complete and empty fields', () {
      final stats = DeadlineStatistics.fromJson({
        'windowHours': 72,
        'overdueCount': 2,
        'upcomingCount': 1,
        'overdue': [
          {
            'id': 't1',
            'title': 'Quá hạn 1',
            'status': 'in_progress',
            'priority': 'high',
            'dueDate': '2026-11-01T10:00:00.000Z'
          }
        ],
        'upcoming': [
          {
            'id': 't2',
            'title': 'Sắp tới hạn 1',
            'status': 'todo',
            'priority': 'medium',
            'dueDate': '2026-11-08T10:00:00.000Z'
          }
        ]
      });
      expect(stats.windowHours, 72);
      expect(stats.overdueCount, 2);
      expect(stats.upcomingCount, 1);
      expect(stats.overdue.length, 1);
      expect(stats.overdue[0].title, 'Quá hạn 1');
      expect(stats.upcoming.length, 1);
      expect(stats.upcoming[0].dueDate, isNotNull);

      final emptyStats = DeadlineStatistics.fromJson({});
      expect(emptyStats.windowHours, 24);
      expect(emptyStats.overdueCount, 0);
      expect(emptyStats.upcomingCount, 0);
      expect(emptyStats.overdue, isEmpty);
      expect(emptyStats.upcoming, isEmpty);
    });
  });

  group('Statistics Widget Tests (E3)', () {
    testWidgets('Render statistics cards with numbers correctly', (WidgetTester tester) async {
      final stats = TaskStatistics.fromJson({
        'total': 15,
        'byStatus': {'todo': 5, 'in_progress': 4, 'completed': 6},
        'byPriority': {'low': 3, 'medium': 7, 'high': 5},
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Column(
                children: [
                  Text('Tổng số công việc: ${stats.total}'),
                  Text('Chưa thực hiện: ${stats.byStatus.todo}'),
                  Text('Đang thực hiện: ${stats.byStatus.inProgress}'),
                  Text('Đã hoàn thành: ${stats.byStatus.completed}'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tổng số công việc: 15'), findsOneWidget);
      expect(find.text('Chưa thực hiện: 5'), findsOneWidget);
      expect(find.text('Đang thực hiện: 4'), findsOneWidget);
      expect(find.text('Đã hoàn thành: 6'), findsOneWidget);
    });

    testWidgets('Render statistics with empty/zero state without errors', (WidgetTester tester) async {
      final stats = TaskStatistics.fromJson({});
      final deadlines = DeadlineStatistics.fromJson({});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Text('Tổng số công việc: ${stats.total}'),
                  if (stats.total == 0)
                    const Text('Chưa có công việc nào'),
                  if (deadlines.overdue.isEmpty)
                    const Text('Không có công việc nào quá hạn'),
                  if (deadlines.upcoming.isEmpty)
                    const Text('Không có công việc nào sắp tới hạn'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tổng số công việc: 0'), findsOneWidget);
      expect(find.text('Chưa có công việc nào'), findsOneWidget);
      expect(find.text('Không có công việc nào quá hạn'), findsOneWidget);
      expect(find.text('Không có công việc nào sắp tới hạn'), findsOneWidget);
    });
  });
}
