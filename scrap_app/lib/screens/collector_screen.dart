import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models.dart';

class CollectorScreen extends StatefulWidget {
  const CollectorScreen({super.key});

  @override
  State<CollectorScreen> createState() => _CollectorScreenState();
}

class _CollectorScreenState extends State<CollectorScreen> {
  final api = Api();

  bool _loading = false;
  String? _error;

  int? _collectorId;
  int? _statusFilter; // null = tất cả
  List<PickupRequest> _items = [];

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sp = await SharedPreferences.getInstance();
      final cid = sp.getInt('collectorId');

      if (cid == null) {
        // Không tìm thấy collectorId trong SharedPreferences
        if (!mounted) return;
        setState(() {
          _collectorId = null;
          _items = [];
          _loading = false;
          _error =
              'Không tìm thấy collectorId. Hãy đăng nhập bằng tài khoản nhân viên thu gom.';
        });
        return;
      }

      _collectorId = cid;

      final list = await api.getMyPickups(
        cid,
        status: _statusFilter,
      );

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lỗi tải công việc: $e';
        _loading = false;
      });
    }
  }

  Future<void> _reloadPickups() async {
    if (_collectorId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await api.getMyPickups(
        _collectorId!,
        status: _statusFilter,
      );

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lỗi tải công việc: $e';
        _loading = false;
      });
    }
  }

  Future<void> _accept(int pickupId) async {
    if (_collectorId == null) return;

    setState(() => _loading = true);

    try {
      await api.acceptPickup(pickupId, _collectorId!);
      await _reloadPickups();
      _toast('Đã nhận việc');
    } catch (e) {
      _toast('Nhận việc lỗi: $e');
      await _reloadPickups();
    }
  }

  Future<void> _updateMyLocation() async {
    final sp = await SharedPreferences.getInstance();
    final cid = sp.getInt('collectorId');
    if (cid == null) {
      _toast('Không tìm thấy collectorId');
      return;
    }

    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _toast('Chưa có quyền vị trí');
      return;
    }

    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    try {
      await api.updateCollectorLocation(cid, p.latitude, p.longitude);
      _toast('Đã cập nhật vị trí');
    } catch (e) {
      _toast('Cập nhật vị trí lỗi: $e');
    }
  }

  Future<void> _setStatus(int pickupId, int status) async {
    setState(() => _loading = true);

    try {
      await api.setStatus(pickupId, status);
      await _reloadPickups();
      _toast('Đã cập nhật trạng thái');
    } catch (e) {
      _toast('Cập nhật lỗi: $e');
      await _reloadPickups();
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(m)));
  }

  String _statusName(int s) {
    switch (s) {
      case 0:
        return 'Pending';
      case 1:
        return 'Accepted';
      case 2:
        return 'InProgress';
      case 3:
        return 'Completed';
      case 4:
        return 'Cancelled';
      default:
        return '?';
    }
  }

  Color _statusColorBg(int s) {
    switch (s) {
      case 0:
        return Colors.orangeAccent.withValues(alpha: 0.15);
      case 1:
        return Colors.blueAccent.withValues(alpha: 0.15);
      case 2:
        return Colors.amber.withValues(alpha: 0.15);
      case 3:
        return Colors.greenAccent.withValues(alpha: 0.15);
      default:
        return Colors.grey.withValues(alpha: 0.15);
    }
  }

  Color _statusColorText(int s) {
    switch (s) {
      case 0:
        return Colors.orangeAccent;
      case 1:
        return Colors.blueAccent;
      case 2:
        return Colors.amber;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildJobCard(PickupRequest p) {
    final customerName = p.customer?.fullName ?? '';
    final customerPhone = p.customer?.phone ?? '';
    final customerAddr = p.customer?.address ?? '';

    // format nhẹ cho giờ hẹn
    final pickupTimeStr =
        p.pickupTime.toLocal().toString().substring(0, 16); // yyyy-MM-dd HH:mm

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // hàng đầu: tiêu đề + chip trạng thái
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Yêu cầu #${p.id} - ${p.scrapType} (${p.quantityKg} kg)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _statusColorBg(p.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    _statusName(p.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _statusColorText(p.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // thông tin khách
            Text(
              'Khách: $customerName ($customerPhone)',
              style: const TextStyle(fontSize: 14),
            ),
            if (customerAddr.isNotEmpty)
              Text(
                'Địa chỉ: $customerAddr',
                style: const TextStyle(fontSize: 14),
              ),

            const SizedBox(height: 4),

            // thời gian hẹn
            Text(
              'Hẹn: $pickupTimeStr',
              style: const TextStyle(fontSize: 14),
            ),

            // note (nếu có)
            if (p.note != null && p.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Ghi chú: ${p.note}',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // hàng nút hành động
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Pending -> Nhận
                if (p.status == 0)
                  OutlinedButton(
                    onPressed: () => _accept(p.id),
                    child: const Text('Nhận'),
                  ),

                // Accepted -> Bắt đầu
                if (p.status == 1)
                  OutlinedButton(
                    onPressed: () => _setStatus(p.id, 2),
                    child: const Text('Bắt đầu'),
                  ),

                // InProgress -> Hoàn tất
                if (p.status == 2)
                  FilledButton(
                    onPressed: () => _setStatus(p.id, 3),
                    child: const Text('Hoàn tất'),
                  ),

                // Pending/Accepted/InProgress -> Huỷ
                if (p.status <= 2)
                  TextButton(
                    onPressed: () => _setStatus(p.id, 4),
                    child: const Text('Huỷ'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterDropdown = DropdownButton<int?>(
      value: _statusFilter,
      items: const [
        DropdownMenuItem(value: null, child: Text('(Tất cả)')),
        DropdownMenuItem(value: 0, child: Text('Pending')),
        DropdownMenuItem(value: 1, child: Text('Accepted')),
        DropdownMenuItem(value: 2, child: Text('InProgress')),
        DropdownMenuItem(value: 3, child: Text('Completed')),
        DropdownMenuItem(value: 4, child: Text('Cancelled')),
      ],
      onChanged: (v) async {
        setState(() => _statusFilter = v);
        await _reloadPickups();
      },
    );

    final headerInfo = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        'collectorId: ${_collectorId ?? "-"} | jobs: ${_items.length}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
        ),
      ),
    );

    // ==== BODYCONTENT ====
    Widget bodyContent;
    if (_error != null) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_items.isEmpty && !_loading) {
      bodyContent = const Center(
        child: Text('Hiện chưa có công việc nào.'),
      );
    } else {
      bodyContent = ListView.builder(
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final p = _items[i];
          return _buildJobCard(p);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc của tôi'),
        actions: [
          IconButton(
            onPressed: _updateMyLocation,
            icon: const Icon(Icons.gps_fixed),
            tooltip: 'Cập nhật vị trí',
          ),
          IconButton(
            onPressed: _reloadPickups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              headerInfo,
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Trạng thái:'),
                    const SizedBox(width: 12),
                    filterDropdown,
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),

              Expanded(child: bodyContent),
            ],
          ),

        if (_loading)
          Container(
            color: Colors.black.withValues(alpha: 0.05),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
