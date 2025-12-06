import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';
import 'ui/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/customer_booking_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/collector_screen.dart';
import 'screens/management_screen.dart';
import 'screens/map_screen.dart';
import 'screens/listings_screen.dart';
import 'screens/account_screen.dart';
import 'screens/classification_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.init();
  runApp(const RootApp());
}

/// RootApp chịu trách nhiệm:
/// - kiểm tra trạng thái đăng nhập SharedPreferences
/// - nếu chưa đăng nhập => LoginScreen
/// - nếu đã đăng nhập => ScrapShell (layout chính có bottom nav)
class RootApp extends StatefulWidget {
  const RootApp({super.key});
  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  String? _role;
  int? _customerId;
  int? _collectorId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('jwt');
    final role = sp.getString('role');
    final customerId = sp.getInt('customerId');
    final collectorId = sp.getInt('collectorId');

    setState(() {
      if (token != null && role != null) {
        // đã đăng nhập
        _role = role;
        _customerId = customerId;
        _collectorId = collectorId;
      } else {
        // chưa đăng nhập
        _role = null;
        _customerId = null;
        _collectorId = null;
      }
      _loaded = true;
    });
  }


  /// callback khi user chọn Đăng xuất ở trong app
  Future<void> _handleLoggedOut() async {
    await Session.logout();
    setState(() {
      _role = null;
      _customerId = null;
      _collectorId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrap App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: !_loaded
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : (_role == null
              // chưa login -> màn Login
              ? const LoginScreen()
              // đã login -> vào shell chính có bottom nav
              : ScrapShell(
                  role: _role!,
                  customerId: _customerId,
                  collectorId: _collectorId,
                  onLogout: _handleLoggedOut,
                )),
    );
  }
}

/// ScrapShell = khung chính sau khi đăng nhập
/// chứa AppBar + BottomNavigationBar + các tab theo vai trò
class ScrapShell extends StatefulWidget {
  final String role; // 'admin' | 'customer' | 'collector'
  final int? customerId;
  final int? collectorId;
  final Future<void> Function() onLogout;

  const ScrapShell({
    super.key,
    required this.role,
    required this.customerId,
    required this.collectorId,
    required this.onLogout,
  });

  @override
  State<ScrapShell> createState() => _ScrapShellState();
}

class _ScrapShellState extends State<ScrapShell> {
  int _currentIndex = 0;

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build danh sách tab dựa trên vai trò
    final tabs = _buildTabsForRole(
      role: widget.role,
      customerId: widget.customerId,
      collectorId: widget.collectorId,
    );

    final pages = tabs.pages;
    final navItems = tabs.items;

    // Nếu _currentIndex > pages.length-1 (ví dụ đổi role runtime)
    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text('Xin chào (${widget.role})'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await _confirmLogout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: pages[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          setState(() {
            _currentIndex = i;
          });
        },
        items: navItems,
      ),
    );
  }
}

/// Gói dữ liệu các tab cho 1 role:
/// - pages: danh sách Widget body
/// - items: danh sách icon+label bottom nav
class _RoleTabs {
  final List<Widget> pages;
  final List<BottomNavigationBarItem> items;
  const _RoleTabs({required this.pages, required this.items});
}

/// Tạo danh sách tab/pager theo từng role
_RoleTabs _buildTabsForRole({
  required String role,
  required int? customerId,
  required int? collectorId, // hiện tại collectorId chưa dùng nhưng giữ để sau mở rộng
}) {
  // Trang HOME chung cho mọi role
  final homePage = _HomeWelcomePage(role: role);

  // ---------- CUSTOMER ----------
  if (role == 'customer') {
    return _RoleTabs(
      pages: [
        homePage,
        const CustomerBookingScreen(), // Đặt lịch thu gom
        if (customerId != null)
          MyBookingsScreen(customerId: customerId)
        else
          const _PlaceholderPage('Chưa có ID khách hàng'),
        const ListingsScreen(), // Nguồn cung / Listings
        const ClassificationScreen(),
        const AccountScreen(),
      ],
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_available),
          label: 'Đặt lịch',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Lịch của tôi',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: 'Listings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.recycling),
          label: 'Phân loại',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Tài khoản',
        ),
      ],
    );
  }

  // ---------- COLLECTOR ----------
  if (role == 'collector') {
    return const _RoleTabs(
      pages: [
        _HomeWelcomePage(role: 'collector'),
        CollectorScreen(), // công việc được giao
        MapScreen(), // bản đồ điều phối
        ClassificationScreen(),
        AccountScreen(),
      ],
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.delivery_dining),
          label: 'Công việc',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          label: 'Bản đồ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.recycling),
          label: 'Phân loại',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Tài khoản',
        ),
      ],
    );
  }

  // ---------- ADMIN ----------
  // admin có quyền coi gần như tất cả
  return const _RoleTabs(
    pages: [
      _HomeWelcomePage(role: 'admin'),
      MapScreen(), // điều phối / bản đồ
      ManagementScreen(), // quản lý Công ty / Collector
      ListingsScreen(), // nguồn cung / Listings
      ClassificationScreen(),
      AccountScreen(),
    ],
    items: [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Trang chủ',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.map_outlined),
        label: 'Điều phối',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.business),
        label: 'Quản lý',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.store),
        label: 'Listings',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.recycling),
        label: 'Phân loại',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Tài khoản',
      ),
    ],
  );
}

/// Trang chủ: chỉ chào mừng + mô tả vai trò,
/// hướng dẫn dùng thanh điều hướng bên dưới.
/// (Không còn grid nút như bản cũ.)
class _HomeWelcomePage extends StatelessWidget {
  final String role;
  const _HomeWelcomePage({required this.role});

  String _roleVietnamese(String r) {
    switch (r) {
      case 'admin':
        return 'Quản trị viên';
      case 'collector':
        return 'Nhân viên thu gom';
      case 'customer':
        return 'Khách hàng';
      default:
        return r;
    }
  }

  String _blurb(String r) {
    switch (r) {
      case 'customer':
        return 'Bạn có thể đặt lịch thu gom phế liệu tại nhà và xem lịch hẹn của mình trực tiếp trong ứng dụng.';
      case 'collector':
        return 'Bạn có thể xem lịch thu gom được giao và định vị điểm thu gom trên bản đồ.';
      case 'admin':
        return 'Bạn có thể điều phối lịch thu gom, quản lý công ty thu gom và theo dõi nguồn cung.';
      default:
        return 'Ứng dụng hỗ trợ thu gom phế liệu nhanh gọn và minh bạch.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final niceRole = _roleVietnamese(role);
    final desc = _blurb(role);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.recycling,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Chào mừng đến với ứng dụng thu gom phế liệu',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Vai trò hiện tại: $niceRole',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Dùng thanh điều hướng bên dưới để truy cập các chức năng chính.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trang tạm nếu thiếu dữ liệu (ví dụ customerId null)
class _PlaceholderPage extends StatelessWidget {
  final String message;
  const _PlaceholderPage(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
