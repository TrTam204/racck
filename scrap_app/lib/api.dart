import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';
import 'models.dart';

class Api {
  final _client = http.Client();
  String? _token; // JWT sau khi login

  Api() {
    // không load token async ở constructor (constructor không được async)
  }

  // đảm bảo _token đã được nạp từ SharedPreferences trước khi call API
  Future<void> _ensureToken() async {
    if (_token != null) return;

    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('jwt');
  }

  Future<void> _saveToken(String t) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('jwt', t);
    _token = t;
  }

  Map<String, String> _headersJson() {
    final h = {'Content-Type': 'application/json'};
    if (_token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Env.baseUrl}$path').replace(queryParameters: q);

  // =========================
  // AUTH
  // =========================

  // Đăng nhập -> gọi /api/auth/login
  Future<({String role, int? customerId, int? collectorId})> login(
    String username,
    String password,
  ) async {
    final r = await _client.post(
      _u('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (r.statusCode != 200) {
      throw Exception('Login failed: ${r.statusCode} ${r.body}');
    }

    final j = jsonDecode(r.body);
    final token = j['token'] as String;
    await _saveToken(token); // lưu token vào SharedPreferences + _token

    final role = j['role'] as String;
    final customerId = j['customerId'];
    final collectorId = j['collectorId'];

    // lưu info session để RootApp đọc (ai đang login, role gì...)
    final sp = await SharedPreferences.getInstance();
    await sp.setString('role', role);
    if (customerId != null) {
      await sp.setInt('customerId', customerId);
    }
    if (collectorId != null) {
      await sp.setInt('collectorId', collectorId);
    }

    return (
      role: role,
      customerId: (customerId is int) ? customerId : null,
      collectorId: (collectorId is int) ? collectorId : null,
    );
  }


  Future<Map<String, dynamic>> getMe() async {
    await _ensureToken();
    final r = await _client.get(
      _u('/api/auth/me'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('getMe failed: ${r.statusCode} ${r.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _ensureToken();
    final r = await _client.post(
      _u('/api/auth/changePassword'),
      headers: _headersJson(),
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('changePassword failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<String> forgotPassword(String username) async {
    final r = await _client.post(
      _u('/api/auth/forgot'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    if (r.statusCode != 200) {
      throw Exception('forgotPassword failed: ${r.statusCode} ${r.body}');
    }
    final j = jsonDecode(r.body);
    return j['code']?.toString() ?? '';
  }

  Future<void> resetPassword(String username, String code, String newPassword) async {
    final r = await _client.post(
      _u('/api/auth/reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'code': code,
        'newPassword': newPassword,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('resetPassword failed: ${r.statusCode} ${r.body}');
    }
  }

  // Upload avatar (multipart) -> returns public GET url
  Future<String> uploadAvatar(String filePath) async {
    await _ensureToken();
    final req = http.MultipartRequest('POST', _u('/api/auth/avatar'));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode != 200) {
      throw Exception('uploadAvatar failed: ${resp.statusCode} $body');
    }
    final j = jsonDecode(body);
    return j['url']?.toString() ?? '';
  }

  // Đăng ký tài khoản mới role customer
  Future<Map<String, dynamic>> registerCustomerRole({
    required String username,
    required String password,
  }) async {
    final r = await _client.post(
      _u('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'role': 'customer',
      }),
    );

    debugPrint('REGISTER status=${r.statusCode} body=${r.body}');

    if (r.statusCode != 201) {
      throw Exception('Register failed: ${r.statusCode} ${r.body}');
    }

    final data = jsonDecode(r.body);
    return Map<String, dynamic>.from(data as Map);
  }

  // Đăng ký tài khoản mới role collector
  Future<Map<String, dynamic>> registerCollectorRole({
    required String username,
    required String password,
  }) async {
    final r = await _client.post(
      _u('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'role': 'collector',
      }),
    );

    debugPrint('REGISTER COLLECTOR status=${r.statusCode} body=${r.body}');

    if (r.statusCode != 201) {
      throw Exception('Register failed: ${r.statusCode} ${r.body}');
    }

    final data = jsonDecode(r.body);
    return Map<String, dynamic>.from(data as Map);
  }

  // LẤY DANH SÁCH TẤT CẢ USER (admin-only)
  Future<List<Map<String, dynamic>>> getAllUsersAdmin() async {
    await _ensureToken();

    final r = await _client.get(
      _u('/api/auth/users'),
      headers: _headersJson(),
    );

    if (r.statusCode != 200) {
      throw Exception('getAllUsersAdmin failed: ${r.statusCode} ${r.body}');
    }

    final List data = jsonDecode(r.body);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // =========================
  // CUSTOMERS
  // =========================

  Future<List<Customer>> getCustomers() async {
    await _ensureToken();
    try {
      final r = await _client.get(
        _u('/api/customers'),
        headers: _headersJson(),
      );
      if (r.statusCode != 200) {
        throw Exception('getCustomers failed: ${r.statusCode} ${r.body}');
      }
      final List a = jsonDecode(r.body);
      final sp = await SharedPreferences.getInstance();
      await sp.setString('cache_customers', r.body);
      return a.map((e) => Customer.fromJson(e)).toList();
    } catch (e) {
      final sp = await SharedPreferences.getInstance();
      final s = sp.getString('cache_customers');
      if (s != null && s.isNotEmpty) {
        final List a = jsonDecode(s);
        return a.map((e) => Customer.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  Future<Customer> createCustomer(
    String name,
    String phone,
    String? addr,
  ) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/customers'),
      headers: _headersJson(),
      body: jsonEncode({
        'fullName': name,
        'phone': phone,
        'address': addr,
      }),
    );
    if (r.statusCode != 201) {
      throw Exception('createCustomer failed: ${r.statusCode} ${r.body}');
    }

    return Customer.fromJson(jsonDecode(r.body));
  }

  Future<Customer> getCustomer(int id) async {
    await _ensureToken();

    final r = await _client.get(
      _u('/api/customers/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('getCustomer failed: ${r.statusCode} ${r.body}');
    }

    return Customer.fromJson(jsonDecode(r.body));
  }

  Future<Customer> updateCustomer(int id, Map<String, dynamic> body) async {
    await _ensureToken();

    final r = await _client.put(
      _u('/api/customers/$id'),
      headers: _headersJson(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) {
      throw Exception('updateCustomer failed: ${r.statusCode} ${r.body}');
    }

    return Customer.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteCustomer(int id) async {
    await _ensureToken();

    final r = await _client.delete(
      _u('/api/customers/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 204) {
      throw Exception('deleteCustomer failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> updateCustomerLocation(int id, double lat, double lng) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/customers/$id/location', {
        'lat': '$lat',
        'lng': '$lng'
      }),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception(
        'updateCustomerLocation failed: ${r.statusCode} ${r.body}',
      );
    }
  }

  // =========================
  // PICKUPS
  // =========================

  Future<PickupRequest> createPickup({
    required int customerId,
    required String scrapType,
    required double quantityKg,
    required DateTime pickupTime,
    required double lat,
    required double lng,
    String? note,
  }) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/pickups'),
      headers: _headersJson(),
      body: jsonEncode({
        'customerId': customerId,
        'scrapType': scrapType,
        'quantityKg': quantityKg,
        'pickupTime': pickupTime.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'note': note
      }),
    );
    if (r.statusCode != 201) {
      throw Exception('createPickup failed: ${r.statusCode} ${r.body}');
    }

    return PickupRequest.fromJson(jsonDecode(r.body));
  }

  Future<void> deletePickup(int id) async {
    await _ensureToken();

    final r = await _client.delete(
      _u('/api/pickups/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 204) {
      throw Exception('deletePickup failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<PickupRequest> updatePickupStatus(int id, int status) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/pickups/$id/status', {'status': '$status'}),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('updatePickupStatus failed: ${r.statusCode} ${r.body}');
    }
    final Map<String, dynamic> j = jsonDecode(r.body);
    return PickupRequest.fromJson(j);
  }

  Future<List<PickupRequest>> getPickups({
    int? status,
    int? collectorId,
    int? customerId,
  }) async {
    await _ensureToken();

    final q = <String, String>{};
    if (status != null) q['status'] = '$status';
    if (collectorId != null) q['collectorId'] = '$collectorId';
    if (customerId != null) q['customerId'] = '$customerId';

    final r = await _client.get(
      _u('/api/pickups', q.isEmpty ? null : q),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('getPickups failed: ${r.statusCode} ${r.body}');
    }

    final List a = jsonDecode(r.body);
    return a.map((e) => PickupRequest.fromJson(e)).toList();
  }

  Future<void> acceptPickup(int id, int collectorId) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/pickups/$id/accept', {'collectorId': '$collectorId'}),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('acceptPickup failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> setStatus(int id, int status) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/pickups/$id/status', {'status': '$status'}),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('setStatus failed: ${r.statusCode} ${r.body}');
    }
  }

  // =========================
  // COMPANIES + COLLECTORS
  // =========================

  Future<List<Collector>> getCollectors() async {
    await _ensureToken();

    final r = await _client.get(
      _u('/api/collectors'),
      headers: _headersJson(),
    );

    if (r.statusCode != 200) {
      throw Exception('getCollectors failed: ${r.statusCode} ${r.body}');
    }

    final List data = jsonDecode(r.body);
    return data.map((e) => Collector.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getCompanies() async {
    await _ensureToken();

    final r = await _client.get(
      _u('/api/companies'),
      headers: _headersJson(),
    );

    if (r.statusCode != 200) {
      throw Exception('getCompanies failed: ${r.statusCode} ${r.body}');
    }

    final List data = jsonDecode(r.body);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createCompany(
    String name,
    String phone,
    String? addr,
  ) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/companies'),
      headers: _headersJson(),
      body: jsonEncode({
        'name': name,
        'contactPhone': phone,
        'address': addr
      }),
    );
    if (r.statusCode != 201) {
      throw Exception('createCompany failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> updateCompany(
    int id,
    String name,
    String phone,
    String? addr,
  ) async {
    await _ensureToken();

    final r = await _client.put(
      _u('/api/companies/$id'),
      headers: _headersJson(),
      body: jsonEncode({
        'id': id,
        'name': name,
        'contactPhone': phone,
        'address': addr
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('updateCompany failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> deleteCompany(int id) async {
    await _ensureToken();

    final r = await _client.delete(
      _u('/api/companies/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 204) {
      throw Exception('deleteCompany failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> createCollector(
    int companyId,
    String fullName,
    String phone,
    {String? email, String? gender}
  ) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/collectors'),
      headers: _headersJson(),
      body: jsonEncode({
        'companyId': companyId,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'gender': gender,
      }),
    );
    if (r.statusCode != 201) {
      throw Exception('createCollector failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> updateCollector(
    int id,
    int companyId,
    String fullName,
    String phone,
    {String? email, String? gender}
  ) async {
    await _ensureToken();

    final r = await _client.put(
      _u('/api/collectors/$id'),
      headers: _headersJson(),
      body: jsonEncode({
        'id': id,
        'companyId': companyId,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'gender': gender,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('updateCollector failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> deleteCollector(int id) async {
    await _ensureToken();

    final r = await _client.delete(
      _u('/api/collectors/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 204) {
      throw Exception('deleteCollector failed: ${r.statusCode} ${r.body}');
    }
  }

  // =========================
  // COLLECTOR helpers
  // =========================

  Future<void> updateCollectorLocation(int id, double lat, double lng) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/collectors/$id/location', {
        'lat': '$lat',
        'lng': '$lng',
      }),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception(
        'updateCollectorLocation failed: ${r.statusCode} ${r.body}',
      );
    }
  }

  // Admin tạo tài khoản đăng nhập cho collector có sẵn
  // (role admin phải đang login)
  Future<void> createCollectorUser({
    required int collectorId,
    required String username,
    required String password,
  }) async {
    await _ensureToken();

    final body = {
      'collectorId': collectorId,
      'username': username,
      'password': password,
    };

    final r = await _client.post(
      _u('/api/admin/createCollectorUser'),
      headers: _headersJson(),
      body: jsonEncode(body),
    );

    if (r.statusCode != 201) {
      throw Exception(
        'createCollectorUser failed: ${r.statusCode} ${r.body}',
      );
    }
  }

  // danh sách công việc cho collector đang login
  Future<List<PickupRequest>> getMyPickups(
    int collectorId, {
    int? status,
  }) async {
    await _ensureToken();

    final q = <String, String>{};
    if (status != null) q['status'] = '$status';

    final r = await _client.get(
      _u('/api/collectors/$collectorId/pickups', q.isEmpty ? null : q),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('getMyPickups failed: ${r.statusCode} ${r.body}');
    }

    final List a = jsonDecode(r.body);
    return a.map((e) => PickupRequest.fromJson(e)).toList();
  }

  // =========================
  // CUSTOMER helpers
  // =========================

  // lịch đã đặt của customer đang login
  Future<List<PickupRequest>> getMyCustomerPickups(
    int customerId, {
    int? status,
  }) async {
    await _ensureToken();

    final q = <String, String>{};
    if (status != null) q['status'] = '$status';

    final r = await _client.get(
      _u('/api/customers/$customerId/pickups', q.isEmpty ? null : q),
      headers: _headersJson(),
    );

    if (r.statusCode != 200) {
      throw Exception(
        'getMyCustomerPickups failed: ${r.statusCode} ${r.body}',
      );
    }

    final List a = jsonDecode(r.body);
    return a.map((e) => PickupRequest.fromJson(e)).toList();
  }

  // =========================
  // LISTINGS
  // =========================

  Future<void> createListing(
    String title,
    String desc,
    double pricePerKg, {
    double? lat,
    double? lng,
    String? contactPhone,
  }) async {
    await _ensureToken();

    final r = await _client.post(
      _u('/api/listings'),
      headers: _headersJson(),
      body: jsonEncode({
        'title': title,
        'description': desc,
        'pricePerKg': pricePerKg,
        'lat': lat,
        'lng': lng,
        'contactPhone': contactPhone,
      }),
    );
    if (r.statusCode != 201) {
      throw Exception('createListing failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<List<Listing>> searchListings({
    String? q,
    double? lat,
    double? lng,
    double? radiusKm,
    int? top,
  }) async {
    await _ensureToken();
    final qp = <String, String>{};
    if (q != null && q.isNotEmpty) qp['q'] = q;
    if (lat != null && lng != null && radiusKm != null) {
      qp['lat'] = '$lat';
      qp['lng'] = '$lng';
      qp['radiusKm'] = '$radiusKm';
    }
    if (top != null) qp['top'] = '$top';

    try {
      final r = await _client.get(
        _u('/api/listings/search', qp.isEmpty ? null : qp),
        headers: _headersJson(),
      );
      if (r.statusCode != 200) {
        throw Exception('searchListings failed: ${r.statusCode} ${r.body}');
      }
      final List a = jsonDecode(r.body);
      final sp = await SharedPreferences.getInstance();
      await sp.setString('cache_listings_last', r.body);
      return a.map((e) => Listing.fromJson(e)).toList();
    } catch (e) {
      final sp = await SharedPreferences.getInstance();
      final s = sp.getString('cache_listings_last');
      if (s != null && s.isNotEmpty) {
        final List a = jsonDecode(s);
        return a.map((e) => Listing.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  // =========================
  // Dispatch / Map
  // =========================

  Future<void> dispatchNearest(
    int pickupId, {
    required double jobLat,
    required double jobLng,
    double radiusKm = 10,
    int? companyId,
  }) async {
    await _ensureToken();

    final q = {
      'jobLat': '$jobLat',
      'jobLng': '$jobLng',
      'radiusKm': '$radiusKm',
      if (companyId != null) 'companyId': '$companyId'
    };

    final r = await _client.post(
      _u('/api/pickups/$pickupId/dispatch-nearest', q),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('dispatchNearest failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<LiveData> getLiveData() async {
    await _ensureToken();

    final r = await _client.get(
      _u('/api/dispatch/live'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('getLiveData failed: ${r.statusCode} ${r.body}');
    }

    final j = jsonDecode(r.body);
    return LiveData.fromJson(j);
  }

  Future<Map<String, dynamic>> getWeather({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast').replace(
      queryParameters: {
        'latitude': '$lat',
        'longitude': '$lng',
        'current_weather': 'true',
      },
    );
    final r = await _client.get(uri);
    if (r.statusCode != 200) {
      throw Exception('getWeather failed: ${r.statusCode} ${r.body}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final cw = j['current_weather'] as Map<String, dynamic>?;
    return cw ?? <String, dynamic>{};
  }
}
