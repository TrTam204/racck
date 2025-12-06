import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../api.dart';
import '../models.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _api = Api();

  bool _loading = false;
  String? _error;

  LiveData? _live;

  // Map controller để zoom/pan
  final MapController _mapController = MapController();

  // tâm mặc định (HCM tạm thời)
  LatLng _center = const LatLng(10.77653, 106.70098);
  double _zoom = 13;
  Timer? _pollTimer;
  LatLng? _myPos;
  Map<String, dynamic>? _weather;

  @override
  void initState() {
    super.initState();
    _loadLive();
    _refreshMyLocation();
    _loadWeather();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (t) {
      if (!mounted) return;
      if (!_loading) {
        _loadLive();
        _loadWeather();
      }
    });
  }
  Future<void> _loadWeather() async {
    try {
      final p = _myPos ?? _center;
      final j = await _api.getWeather(lat: p.latitude, lng: p.longitude);
      if (!mounted) return;
      setState(() {
        _weather = j;
      });
    } catch (_) {}
  }
  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLive() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getLiveData();

      // sau khi có data, thử canh bản đồ
      final bounds = _calcBoundsFromLive(data);
      if (bounds != null) {
        // lấy trung tâm đơn giản = midpoint của bounds
        final midLat = (bounds.sw.latitude + bounds.ne.latitude) / 2;
        final midLng = (bounds.sw.longitude + bounds.ne.longitude) / 2;
        _center = LatLng(midLat, midLng);
        _zoom = 13; // bạn muốn có thể tự tính zoom theo bounds sau
        // (flutter_map có fitBounds nhưng cần builder async một chút,
        // ở bản cơ bản mình chỉ set state để camera start ở đó)
      }

      if (!mounted) return;
      setState(() {
        _live = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được dữ liệu bản đồ: $e';
        _loading = false;
      });
    }
  }

  

  Future<void> _updateMyLocation() async {
    final sp = await SharedPreferences.getInstance();
    final cid = sp.getInt('collectorId');
    if (cid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không phải tài khoản nhân viên')));
      return;
    }

    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chưa có quyền vị trí')));
      return;
    }

    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    try {
      await _api.updateCollectorLocation(cid, p.latitude, p.longitude);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã cập nhật vị trí')));
      await _loadLive();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi cập nhật vị trí: $e')));
    }
  }

  // Gom tất cả vị trí collector + pickup để tính bounding box
  _LatLngBounds? _calcBoundsFromLive(LiveData data) {
    final allPoints = <LatLng>[];

    for (final c in data.collectors) {
      if (c.currentLat != null && c.currentLng != null) {
        allPoints.add(LatLng(c.currentLat!, c.currentLng!));
      }
    }

    for (final j in data.pendingJobs) {
        allPoints.add(LatLng(j.lat, j.lng));
    }

    if (allPoints.isEmpty) return null;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return _LatLngBounds(
      sw: LatLng(minLat, minLng),
      ne: LatLng(maxLat, maxLng),
    );
  }

  // Marker list cho flutter_map
  List<Marker> _buildMarkers() {
    final list = <Marker>[];
    if (_live == null) return list;

    // 1. collector markers (xanh lá)
    for (final c in _live!.collectors) {
      if (c.currentLat == null || c.currentLng == null) continue;

      list.add(
        Marker(
          point: LatLng(c.currentLat!, c.currentLng!),
          width: 120,
          height: 64,
          child: _CollectorMarkerWidget(
            name: c.fullName.isNotEmpty ? c.fullName : 'NV #${c.id}',
            phone: c.phone,
          ),
        ),
      );
    }

    // 2. job markers (cam)
    for (final job in _live!.pendingJobs) {
      list.add(
        Marker(
          point: LatLng(job.lat, job.lng),
          width: 140,
          height: 64,
          child: _JobMarkerWidget(
            jobId: job.id,
            scrapType: job.scrapType,
            kg: job.quantityKg,
            customerName: job.customerName,
            customerPhone: job.customerPhone,
          ),
        ),
      );
    }

    // 3. vị trí hiện tại của tôi (xanh dương)
    if (_myPos != null) {
      list.add(
        Marker(
          point: _myPos!,
          width: 100,
          height: 60,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Tôi',
                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 2),
              Icon(Icons.my_location, color: Colors.blue.shade700, size: 26),
            ],
          ),
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();

    Widget mapLayer;
    if (_live == null && _loading) {
      mapLayer = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _live == null) {
      mapLayer = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      mapLayer = FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _zoom,
          // you can allow user gesture, tap, etc.
        ),
        children: [
          // Tile layer sử dụng OpenStreetMap free
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.scrap_app',
          ),

          // markers
          MarkerLayer(
            markers: markers,
          ),
        ],
      );
    }

    // cái panel nhỏ dưới cùng giống "dashboard"
    final bottomPanel = Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Điều phối hiện tại",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Nhân viên đang online: ${_live?.collectors.length ?? 0}",
                ),
                Text(
                  "Yêu cầu chưa xong: ${_live?.pendingJobs.length ?? 0}",
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Cảnh báo: $_error",
                    style: const TextStyle(
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        _loadLive();
                        _loadWeather();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Làm mới"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bản đồ điều phối"),
        actions: [
          IconButton(
            onPressed: _updateMyLocation,
            icon: const Icon(Icons.share_location),
            tooltip: 'Gửi vị trí của tôi',
          ),
          IconButton(
            onPressed: _refreshMyLocation,
            icon: const Icon(Icons.my_location),
            tooltip: 'Đến vị trí của tôi',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: mapLayer),

          bottomPanel,

          if (_weather != null)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${(_weather!['temperature'] ?? _weather!['temp'] ?? _weather!['temperature_2m'] ?? '?')}°C',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          if (_loading && _live != null)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshMyLocation() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() {
        _myPos = LatLng(p.latitude, p.longitude);
        _center = _myPos!;
        _zoom = 15;
      });
      _mapController.move(_myPos!, _zoom);
      await _loadWeather();
    } catch (_) {}
  }
}

// Widget marker cho Collector
class _CollectorMarkerWidget extends StatelessWidget {
  final String name;
  final String phone;

  const _CollectorMarkerWidget({
    required this.name,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // bubble info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Icon(
          Icons.man_2_rounded,
          color: Colors.green.shade700,
          size: 28,
        ),
      ],
    );
  }
}

// Widget marker cho Job/Pickup
class _JobMarkerWidget extends StatelessWidget {
  final int jobId;
  final String scrapType;
  final double kg;
  final String customerName;
  final String customerPhone;

  const _JobMarkerWidget({
    required this.jobId,
    required this.scrapType,
    required this.kg,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  Widget build(BuildContext context) {
    final detail = "$scrapType / ${kg.toStringAsFixed(1)}kg";

    return Column(
      children: [
        // bubble info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "#$jobId $detail",
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Icon(
          Icons.location_on,
          color: Colors.orange.shade700,
          size: 28,
        ),
      ],
    );
  }
}

// helper class để giữ bounds
class _LatLngBounds {
  final LatLng sw;
  final LatLng ne;
  const _LatLngBounds({required this.sw, required this.ne});
}
