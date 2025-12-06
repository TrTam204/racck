import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';

class MyBookingsScreen extends StatefulWidget {
  final int customerId;

  const MyBookingsScreen({
    super.key,
    required this.customerId,
  });

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _api = Api();

  bool _loading = false;
  String? _error;
  List<PickupRequest> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // gọi API lịch theo customer
      final list = await _api.getMyCustomerPickups(
        widget.customerId,
        // muốn lọc chỉ "Chờ xác nhận": status: 0,
      );

      if (!mounted) return;
      setState(() {
        _items = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được danh sách lịch: $e';
      });
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Widget _buildItem(PickupRequest p) {
    // thời gian hẹn (pickupTime) -> string dd/MM/yyyy HH:mm
    final pickupTimeStr = _formatPickupTime(p.pickupTime.toLocal());

    // ví dụ: "Nhôm - 12.5 kg"
    final scrapLine =
        "${p.scrapType} - ${p.quantityKg.toStringAsFixed(1)} kg";

    // toạ độ
    final latStr = p.lat.toStringAsFixed(5);
    final lngStr = p.lng.toStringAsFixed(5);
    final coordLine = "($latStr, $lngStr)";

    final hasNote = (p.note != null && p.note!.trim().isNotEmpty);

    // thông tin nhân viên thu gom (nếu đã có người nhận)
    final hasCollector = p.collector != null;
    final collectorName = hasCollector ? p.collector!.fullName : null;
    final collectorPhone = hasCollector ? p.collector!.phone : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Hàng đầu: thời gian hẹn + trạng thái =====
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pickupTimeStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusText(p.status),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: _statusColor(p.status),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ===== Loại phế liệu + kg =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.recycling, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scrapLine,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ===== Ghi chú (nếu có) =====
              if (hasNote) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note_alt_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.note!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              // ===== Toạ độ =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      coordLine,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Divider(height: 16),

              // ===== Nhân viên thu gom (đã gán hoặc chưa) =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person_pin_circle_outlined,
                    size: 18,
                    color: hasCollector ? Colors.black87 : Colors.black26,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: hasCollector
                        ? Text(
                            "$collectorName - $collectorPhone",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : const Text(
                            "Chưa phân công nhân viên",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black45,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          "Bạn chưa có lịch thu gom nào.",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final p = _items[index];
          return _buildItem(p);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lịch đã đặt"),
        actions: [
          IconButton(
            onPressed: _fetchBookings,
            icon: const Icon(Icons.refresh),
            tooltip: "Làm mới",
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------

  // map status code backend -> text cho khách đọc
  String _statusText(int st) {
    switch (st) {
      case 0:
        return "Chờ xác nhận";
      case 1:
        return "Đã giao cho nhân viên";
      case 2:
        return "Đang thu gom";
      case 3:
        return "Hoàn thành";
      case 4:
        return "Đã huỷ";
      default:
        return "Không rõ";
    }
  }

  // màu text nhẹ cho trạng thái
  Color _statusColor(int st) {
    switch (st) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.amber;
      case 3:
        return Colors.green;
      case 4:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // format thời gian kiểu dd/MM/yyyy HH:mm
  String _formatPickupTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$d/$m/$y $hh:$mm";
  }

}
