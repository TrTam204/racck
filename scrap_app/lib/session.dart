import 'package:shared_preferences/shared_preferences.dart';

class Session {
  /// Xoá thông tin đăng nhập hiện tại
  static Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('jwt');
    await sp.remove('role');
    await sp.remove('customerId');
    await sp.remove('collectorId');
  }
}