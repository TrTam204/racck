import 'dart:convert';
import 'dart:io';

class Env {
  // URL backend đã chọn sau khi init()
  static String? _baseUrlResolved;

  // Lấy baseUrl dùng cho API
  static String get baseUrl {
    final v = _baseUrlResolved;
    if (v == null) {
      throw Exception('Env.init() chưa chạy, chưa biết baseUrl');
    }
    return v;
  }

  // helper log (chỉ in ở debug mode)
  static void _debug(String msg) {
    assert(() {
      // ignore: avoid_print
      print(msg);
      return true;
    }());
  }

  // =========================
  // 1. THỬ NHANH CÁC HOST QUEN THUỘC
  // =========================
  //
  // - Emulator Android -> 10.0.2.2:5245
  // - App chạy trên chính PC (Windows, macOS) -> localhost / 127.0.0.1
  //
  static Future<bool> _tryKnownHosts() async {
    final known = <String>[
      'http://10.0.2.2:5245',   // emulator Android nhìn PC
      'http://localhost:5245',  // app chạy trên PC
      'http://127.0.0.1:5245',
    ];

    for (final cand in known) {
      final ok = await _checkHealth(cand);
      if (ok) {
        _baseUrlResolved = cand;
        _debug('[Env] dùng known host: $cand');
        return true;
      }
    }

    return false;
  }

  // =========================
  // 2. LẤY PREFIX MẠNG LAN TỪ NETWORK INTERFACES
  // =========================
  //
  // Ví dụ: 192.168.100.29 -> prefix "192.168.100"
  //
  static Future<Set<String>> _getLanPrefixes() async {
    final prefixes = <String>{};

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }
        }
      }
    } catch (_) {
      // Nếu không lấy được (ví dụ chạy trên nền tảng không hỗ trợ),
      // ta sẽ fallback bằng các prefix phổ biến bên dưới.
    }

    // Thêm một số prefix phổ biến để dự phòng
    prefixes.addAll([
      '192.168.0',
      '192.168.1',
      '192.168.100', // mạng nhà bạn hiện đang là 192.168.100.x
      '10.0.0',
    ]);

    _debug('[Env] LAN prefixes: $prefixes');
    return prefixes;
  }

  // =========================
  // 3. QUÉT MẠNG LAN
  // =========================
  //
  // Chỉ dùng khi known hosts đều fail:
  // - Trường hợp điện thoại thật: 10.0.2.2/localhost đều không dùng được
  // - Lúc này ta thử lần lượt các IP trong từng prefix
  //
  static Future<bool> _scanLan() async {
    final prefixes = await _getLanPrefixes();

    for (final prefix in prefixes) {
      final ok = await _scanOnePrefix(prefix);
      if (ok) return true;
    }

    return false;
  }

  static Future<bool> _scanOnePrefix(String prefix) async {
    _debug('[Env] scan subnet $prefix.x ...');

    // quét từ .1 tới .254
    for (var i = 1; i < 255; i++) {
      final host = '$prefix.$i';
      final cand = 'http://$host:5245';
      final ok = await _checkHealth(cand);
      if (ok) {
        _baseUrlResolved = cand;
        _debug('[Env] tìm thấy backend tại $cand');
        return true;
      }
    }

    return false;
  }

  // =========================
  // 4. /health checker
  // =========================
  //
  // Gọi GET {base}/health
  // backend trả {"status":"OK"}
  //
  static Future<bool> _checkHealth(String base) async {
    try {
      final uri = Uri.parse('$base/health');

      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 800);

      final req = await client.getUrl(uri);
      final resp = await req.close();

      if (resp.statusCode != 200) return false;

      final body = await resp.transform(const Utf8Decoder()).join();
      return body.contains('OK');
    } catch (_) {
      return false;
    }
  }

  // =========================
  // 5. HÀM KHỞI TẠO - GỌI 1 LẦN Ở main()
  // =========================
  //
  // Logic:
  // - B1: thử known hosts (emulator, localhost)
  // - B2: nếu fail thì quét LAN (cho điện thoại thật)
  // - Nếu vẫn fail -> throw, bạn sẽ thấy lỗi đỏ để biết backend chưa chạy
  //
  static Future<void> init() async {
    if (_baseUrlResolved != null) return;

    // B1: known hosts
    final okKnown = await _tryKnownHosts();
    if (okKnown) return;

    // B2: scan LAN (cho phone thật)
    final okLan = await _scanLan();
    if (okLan) return;

    // B3: bó tay
    throw Exception(
      'Không tìm được backend.\n'
      '• Backend đã chạy chưa (dotnet run)?\n'
      '• Điện thoại/emulator và PC có cùng Wi-Fi không?\n'
      '• Port 5245 đã được mở firewall chưa?\n',
    );
  }
}
