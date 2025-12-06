import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// import main.dart để lấy ScrapShell
import 'package:scrap_app/main.dart';

void main() {
  testWidgets('Admin UI shows đúng các tab và lời chào', (WidgetTester tester) async {
    // -- pump widget giả lập 1 admin đã đăng nhập --
    await tester.pumpWidget(
      const MaterialApp(
        home: ScrapShell(
          role: 'admin',
          customerId: null,
          collectorId: null,
          onLogout: _fakeLogout,
        ),
      ),
    );

    // Cho Flutter build xong khung
    await tester.pumpAndSettle();

    // 1. AppBar có "Xin chào (admin)"
    expect(find.textContaining('Xin chào (admin)'), findsOneWidget);

    // 2. Trang Home có title chào mừng
    expect(
      find.text('Chào mừng đến với ứng dụng thu gom phế liệu'),
      findsOneWidget,
    );

    // 3. BottomNavigationBar dành cho admin có các label:
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Điều phối'), findsOneWidget);
    expect(find.text('Quản lý'), findsOneWidget);
    expect(find.text('Listings'), findsOneWidget);
  });

  testWidgets('Customer UI có tab Đặt lịch và Lịch của tôi', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScrapShell(
          role: 'customer',
          customerId: 123, // giả có customerId để hiện "Lịch của tôi"
          collectorId: null,
          onLogout: _fakeLogout,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // AppBar chào customer
    expect(find.textContaining('Xin chào (customer)'), findsOneWidget);

    // Bottom nav của customer
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(find.text('Lịch của tôi'), findsOneWidget);
    expect(find.text('Listings'), findsOneWidget);
  });

  testWidgets('Collector UI có tab Công việc và Bản đồ', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScrapShell(
          role: 'collector',
          customerId: null,
          collectorId: 99,
          onLogout: _fakeLogout,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // AppBar chào collector
    expect(find.textContaining('Xin chào (collector)'), findsOneWidget);

    // Bottom nav của collector
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Công việc'), findsOneWidget);
    expect(find.text('Bản đồ'), findsOneWidget);
  });
}

// Hàm logout fake để pass vào ScrapShell.
// Phải là Future<void> Function()
Future<void> _fakeLogout() async {
  // không làm gì hết, chỉ để test compile
}
