// -------------------------
// Khách hàng
// -------------------------
class Customer {
  final int id;
  final String fullName;
  final String phone;
  final String? email;
  final String? gender;
  final String? address;

  Customer({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.gender,
    this.address,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as int,
        fullName: j['fullName'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String?,
        gender: j['gender'] as String?,
        address: j['address'] as String?,
      );
}

// -------------------------
// Nhân viên thu gom (gắn vào từng pickup đã được nhận)
// -------------------------
class CollectorInfo {
  final int id;
  final String fullName;
  final String phone;

  CollectorInfo({
    required this.id,
    required this.fullName,
    required this.phone,
  });

  factory CollectorInfo.fromJson(Map<String, dynamic> j) => CollectorInfo(
        id: j['id'] as int,
        fullName: j['fullName'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
      );
}

// -------------------------
// Trạng thái yêu cầu thu gom
// -------------------------
// Lưu ý: backend trả status là int 0..4,
// mình vẫn giữ enum để dev đọc dễ,
// nhưng trong model PickupRequest mình vẫn lưu số int.
enum PickupStatus {
  pending,      // 0
  accepted,     // 1
  inProgress,   // 2
  completed,    // 3
  cancelled,    // 4
}

// -------------------------
// Yêu cầu thu gom
// (cả khách xem lịch của tôi, cả collector xem công việc của tôi)
// -------------------------
class PickupRequest {
  final int id;

  // người tạo yêu cầu (khách). Backend trả object customer {...} hoặc null
  final Customer? customer;

  // nhân viên đã nhận (collector). Backend trả object collector {...} hoặc null
  final CollectorInfo? collector;

  final String scrapType;
  final double quantityKg;
  final DateTime pickupTime;
  final double lat;
  final double lng;
  final String? note;

  // status dạng int (0..4) đúng như backend gửi ra
  final int status;

  PickupRequest({
    required this.id,
    required this.customer,
    required this.collector,
    required this.scrapType,
    required this.quantityKg,
    required this.pickupTime,
    required this.lat,
    required this.lng,
    this.note,
    required this.status,
  });

  factory PickupRequest.fromJson(Map<String, dynamic> j) => PickupRequest(
        id: j['id'] as int,
        customer: j['customer'] == null
            ? null
            : Customer.fromJson(j['customer'] as Map<String, dynamic>),
        collector: j['collector'] == null
            ? null
            : CollectorInfo.fromJson(j['collector'] as Map<String, dynamic>),
        scrapType: j['scrapType'] as String? ?? '',
        quantityKg: (j['quantityKg'] as num).toDouble(),
        pickupTime: DateTime.parse(j['pickupTime'] as String),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        note: j['note'] as String?,
        status: j['status'] as int,
      );
}

// -------------------------
// Collector "công ty" list đơn giản cho dropdown / danh sách nhân viên
// (từ GET /api/collectors hiện tại bạn trả id + fullName thôi,
// nếu sau này trả thêm phone thì thêm vào đây luôn)
// -------------------------
class Collector {
  final int id;
  final String fullName;
  final String phone;
  final String? email;
  final String? gender;
  final int companyId;

  Collector(this.id, this.fullName, {this.phone = '', this.email, this.gender, this.companyId = 0});

  factory Collector.fromJson(Map<String, dynamic> j) => Collector(
        j['id'] as int,
        j['fullName'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String?,
        gender: j['gender'] as String?,
        companyId: (j['companyId'] as int?) ?? 0,
      );
}

// -------------------------
// Tin rao thu mua phế liệu
// -------------------------
class Listing {
  final int id;
  final String title;
  final String description;
  final double pricePerKg;
  final double? lat;
  final double? lng;
  final String? contactPhone;
  final DateTime createdAt;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.pricePerKg,
    required this.createdAt,
    this.lat,
    this.lng,
    this.contactPhone,
  });

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as int,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        pricePerKg: (j['pricePerKg'] as num).toDouble(),
        lat: j['lat'] == null ? null : (j['lat'] as num).toDouble(),
        lng: j['lng'] == null ? null : (j['lng'] as num).toDouble(),
        contactPhone: j['contactPhone'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'pricePerKg': pricePerKg,
        'lat': lat,
        'lng': lng,
        'contactPhone': contactPhone,
        'createdAt': createdAt.toIso8601String(),
      };
}

// -------------------------
// Vị trí realtime của collector + job pending để màn hình Dispatch / Bản đồ
// -------------------------
class CollectorLive {
  final int id;
  final String fullName;
  final String phone;
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastSeenAt;

  CollectorLive({
    required this.id,
    required this.fullName,
    required this.phone,
    this.currentLat,
    this.currentLng,
    this.lastSeenAt,
  });

  factory CollectorLive.fromJson(Map<String, dynamic> j) => CollectorLive(
        id: j['id'] as int,
        fullName: j['fullName'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        currentLat: j['currentLat'] == null
            ? null
            : (j['currentLat'] as num).toDouble(),
        currentLng: j['currentLng'] == null
            ? null
            : (j['currentLng'] as num).toDouble(),
        lastSeenAt: j['lastSeenAt'] == null
            ? null
            : DateTime.parse(j['lastSeenAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'phone': phone,
        'currentLat': currentLat,
        'currentLng': currentLng,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
      };
}

// -------------------------
// 1 job đang chờ nhận (pending) cho màn Dispatch
// -------------------------
class PendingJob {
  final int id;
  final String scrapType;
  final double quantityKg;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;

  PendingJob({
    required this.id,
    required this.scrapType,
    required this.quantityKg,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
  });

  factory PendingJob.fromJson(Map<String, dynamic> j) => PendingJob(
        id: j['id'] as int,
        scrapType: j['scrapType'] as String? ?? '',
        quantityKg: (j['quantityKg'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        customerName: j['customerName'] as String? ?? '',
        customerPhone: j['customerPhone'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scrapType': scrapType,
        'quantityKg': quantityKg,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt.toIso8601String(),
        'customerName': customerName,
        'customerPhone': customerPhone,
      };
}

// -------------------------
// Gói dữ liệu live cho màn hình điều phối
// -------------------------
class LiveData {
  final List<CollectorLive> collectors;
  final List<PendingJob> pendingJobs;

  LiveData({
    required this.collectors,
    required this.pendingJobs,
  });

  factory LiveData.fromJson(Map<String, dynamic> j) {
    final List cols = j['collectors'] as List? ?? [];
    final List jobs = j['pendingJobs'] as List? ?? [];

    return LiveData(
      collectors: cols
          .map((e) => CollectorLive.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingJobs: jobs
          .map((e) => PendingJob.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'collectors': collectors.map((e) => e.toJson()).toList(),
        'pendingJobs': pendingJobs.map((e) => e.toJson()).toList(),
      };
}
