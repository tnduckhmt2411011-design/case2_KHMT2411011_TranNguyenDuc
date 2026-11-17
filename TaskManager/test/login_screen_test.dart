import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/screens/auth/login_screen.dart';
import 'package:task_manager/screens/auth/register_screen.dart';
import 'package:task_manager/widgets/task_manager_logo.dart';

void main() {
  test('asset logo.png duoc dong goi hop le', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load('assets/images/logo.png');
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('LoginScreen hien thi logo 96x96 phia tren tieu de khong tran layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    final logoFinder = find.byType(TaskManagerLogo);
    expect(logoFinder, findsOneWidget);
    expect(find.byIcon(Icons.task_alt), findsNothing);
    expect(find.bySemanticsLabel('Logo Task Manager'), findsOneWidget);

    final logoSize = tester.getSize(logoFinder);
    expect(logoSize.width, 96.0);
    expect(logoSize.height, 96.0);

    final titleFinder = find.text('Đăng nhập Task Manager');
    expect(titleFinder, findsOneWidget);
    expect(
      tester.getCenter(logoFinder).dy,
      lessThan(tester.getCenter(titleFinder).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TaskManagerLogo hien thi icon du phong khi thieu anh asset', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: TaskManagerLogo(assetPath: 'assets/images/khong_ton_tai.png'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.task_alt), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RegisterScreen hien thi icon 72x72 phia tren tieu de khong tran layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pumpAndSettle();

    final iconBadgeFinder = find.byKey(const ValueKey('register_header_icon'));
    expect(iconBadgeFinder, findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);

    final badgeSize = tester.getSize(iconBadgeFinder);
    expect(badgeSize.width, 72.0);
    expect(badgeSize.height, 72.0);

    final titleFinder = find.text('Tạo tài khoản mới');
    expect(titleFinder, findsOneWidget);
    expect(
      tester.getCenter(iconBadgeFinder).dy,
      lessThan(tester.getCenter(titleFinder).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
