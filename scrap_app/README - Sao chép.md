CHƯƠNG 4: TRIỂN KHAI HỆ THỐNG
4.1. Môi trường cài đặt
- Backend: .NET SDK 8.0+, SQL Server (LocalDB/Server), công cụ `dotnet-ef`, Postman/Swagger để kiểm thử API. Máy chủ dev lắng nghe tại `http://localhost:5245`.
- Mobile: Flutter SDK 3.x, Dart 3.x, Android Studio/Emulator, ADB. Thư viện chính: `http` (REST), `geolocator` (GPS), `hive_flutter` (nháp cục bộ), `image_picker` (ảnh), `flutter_tts` (đọc văn bản).
- Quản trị mã nguồn: Git/VS Code; cấu hình Firewall cho cổng 5245 khi chạy trên LAN.

4.2. Cấu trúc mã nguồn thực tế
- Backend `backend/ScrapApi/`:
  - `Models/Entities.cs`: định nghĩa thực thể (Users, Customers, Collectors, CollectorCompanies, PickupRequests, ScrapListings).
  - `Data/AppDb.cs`: DbContext, cấu hình quan hệ 1–n, OnDelete, seed ràng buộc.
  - `Endpoints/*.cs`: Minimal API theo nhóm (Auth, Customers, Collectors, Companies, Pickups, Listings).
  - `Program.cs`: cấu hình JWT/CORS/Swagger, ánh xạ route, health check.
- Mobile `scrap_app/lib/`:
  - `api.dart`: các hàm REST ghép URL dựa trên `Env.baseUrl`, thêm header JWT.
  - `env.dart`: dò `baseUrl` bằng `/health` trên 10.0.2.2/localhost/IP LAN.
  - `models.dart`: lớp dữ liệu chung (Customer, Collector, PickupRequest, ScrapListing…).
  - `screens/`: mỗi chức năng một màn (login, account, classification, booking, my_bookings, map/jobs, management, listings).
  - `widgets/`: các thành phần tái sử dụng.

4.3. Hiện thực Backend
- Xác thực (`/api/auth`): đăng nhập JWT; đổi/đặt lại mật khẩu; upload/get avatar multipart. Phân quyền `[Authorize]` theo `Role`.
- Khách hàng (`/api/customers`): lưu/sửa hồ sơ, truy vấn lịch của một khách.
- Nhân viên & Doanh nghiệp (`/api/collectors`, `/api/companies`): cập nhật vị trí hiện tại, quản lý danh sách nhân viên và công ty.
- Yêu cầu thu gom (`/api/pickups`):
  - Tạo yêu cầu (ScrapType, QuantityKg, PickupTime, Lat/Lng, Note).
  - Danh sách theo trạng thái (Pending/Accepted/InProgress/Completed/Cancelled).
  - Nhận việc và cập nhật trạng thái; thiết kế OnDelete(SetNull) cho `AcceptedByCollectorId`.
- Listings (`/api/listings`): đăng/tìm theo từ khoá + bán kính; sửa/xoá;
- Quy ước trả về: JSON có trường `ok`/`message` rõ ràng; lỗi dùng mã 4xx/5xx phù hợp.
- Logging & giám sát: bật Swagger; log truy vấn chậm; health check `/health` phục vụ dò IP.

4.4. Hiện thực ứng dụng Flutter
- Điều hướng: `MaterialApp` + `Navigator`; xác định màn hình theo `Role` sau đăng nhập.
- Trạng thái & cập nhật: `FutureBuilder` và `setState`; tránh over‑engineering để đơn giản hoá.
- AccountScreen: xem/sửa thông tin; đổi/đặt lại mật khẩu; upload avatar (ưu tiên hiển thị ảnh từ server, fallback cục bộ). Lưu riêng theo `username` bằng `SharedPreferences`.
- ClassificationScreen: `SliverAppBar` co giãn; TTS đọc kết luận/khuyến nghị.
- CustomerBookingScreen: form tạo yêu cầu (kiểm tra trường bắt buộc, lấy GPS).
- MyBookingsScreen: hiển thị lịch theo thời gian/trạng thái.
- Map/Jobs: OSM, marker công việc, “Đến vị trí của tôi”, nhận/cập nhật trạng thái; poll nhẹ mỗi 20s.
- ListingsScreen: đăng/tìm; CRUD nháp Hive; chọn ảnh + preview cục bộ; hàng nút dùng `Wrap` tránh tràn.

4.5. Kết nối hệ thống & truyền dữ liệu
- Chuẩn giao tiếp: REST/JSON; mọi request sau đăng nhập kèm `Authorization: Bearer <token>`.
- Dò `baseUrl`: `Env.init()` thử tuần tự 10.0.2.2 → localhost → IP LAN; gọi `/health`, địa chỉ nào trả `OK` sẽ dùng cho phiên.
- Timeout/retry: client đặt `timeout` hợp lý; hiển thị thông báo nếu mạng yếu.
- Đồng bộ & cache: poll điều phối theo chu kỳ ngắn; cache danh sách nhẹ bằng `SharedPreferences` để hiển thị ngay khi mở app.
- Media: upload avatar multipart; preview ảnh cục bộ trong listings; về sau có thể mở rộng upload listings kèm CDN/thumbnail.


CHƯƠNG 5: KIỂM THỬ HỆ THỐNG
5.1. Chiến lược kiểm thử
- Kết hợp kiểm thử thủ công theo use case, kiểm thử tích hợp API, và quan sát log/Network.
- Tài khoản mẫu: admin1, khach1, nhanvien1 (SeedData) để mô phỏng vai trò.

5.2. Kiểm thử chức năng (Test case)
- Xác thực & phân quyền: đăng nhập đúng/sai; điều hướng theo role; token hết hạn.
- Đặt lịch: tạo yêu cầu với đủ/thừa/thiếu dữ liệu; tọa độ GPS từ thiết bị thật.
- Quy trình collector: nhận việc, cập nhật trạng thái; gửi vị trí hiện tại.
- Listings: đăng/tìm theo bán kính; preview ảnh cục bộ; thao tác gọi/điều hướng/sao chép.
- Phân loại rác: chọn tiêu chí → kết luận + TTS đọc khuyến nghị.
- Avatar: đổi/xoá theo từng `username`; upload thành công và hiển thị từ server.

5.3. Kiểm thử phi chức năng
- Thời gian phản hồi API trung bình ~150–250ms với các API chính.
- Ổn định giao diện: làm mới định kỳ, điều khiển camera bản đồ mượt.
- Bảo mật cơ bản: JWT, phân quyền endpoint, từ chối truy cập khi token sai/hết hạn.

5.4. Kết quả kiểm thử
- Các luồng nghiệp vụ chính chạy đúng; UI/UX mượt; không phát sinh lỗi nghiêm trọng trong kịch bản thử nghiệm.

5.5. Đánh giá hiệu quả hoạt động
- Hệ thống đáp ứng tốt yêu cầu đề tài; cấu trúc rõ ràng, dữ liệu nhất quán, thao tác nhanh.

CHƯƠNG 6: TRIỂN KHAI (DEPLOYMENT)
6.1. Triển khai Backend
- Chuẩn bị môi trường:
  - Cài `.NET SDK 8.0+`, SQL Server (LocalDB hoặc bản server), công cụ `dotnet-ef`.
  - Tạo biến môi trường cho chuỗi kết nối nếu cần, ví dụ `ConnectionStrings__Default`.
- Khởi tạo và dựng cơ sở dữ liệu:
  - Khôi phục phụ thuộc: `dotnet restore` tại thư mục `backend/ScrapApi`.
  - Áp dụng migration: `dotnet ef database update` (EF Core tự tạo bảng, FK).
  - Khởi động dịch vụ: `dotnet run` (dev) hoặc dựng dịch vụ Windows/PM2/Docker tuỳ hạ tầng.
- Cấu hình ứng dụng:
  - JWT: khoá ký token và thời hạn token cấu hình trong `Program.cs`.
  - CORS: mở cho domain/app di động. Dev mở rộng (`AllowAnyOrigin`) để tiện thử nghiệm.
  - Health & Swagger: bật `/health` để app dò IP; bật Swagger để thử API nhanh.
- Lưu trữ file người dùng:
  - Avatar lưu dưới `uploads/avatars/<username>.jpg|.png`; endpoint `POST /api/auth/avatar` và `GET /api/auth/avatar?u=<username>` phục vụ file.
  - Quy ước quyền thư mục: tiến trình có quyền đọc/ghi; backup thư mục uploads định kỳ.
- Triển khai sản xuất (gợi ý):
  - Reverse proxy (IIS/Nginx) trỏ tới `Kestrel`; cấu hình HTTPS và chứng chỉ.
  - Log & giám sát: bật `Serilog` hoặc `Microsoft.Extensions.Logging` với rolling files; theo dõi CPU/RAM; cảnh báo khi `/health` thất bại.
  - Sao lưu: backup SQL (full + diff) và uploads hàng ngày; lưu off‑site.

6.2. Triển khai ứng dụng di động
- Cài thư viện: `flutter pub get` tại `scrap_app`.
- Cấu hình build:
  - Tạo keystore ký ứng dụng (Android): `keytool -genkey ...`; cấu hình `key.properties` và `build.gradle`.
  - Build bản phát hành: `flutter build apk --release` hoặc `flutter build appbundle`.
  - Kiểm tra quyền: GPS/INTERNET đã khai báo trong `AndroidManifest.xml`.
- Kết nối tới backend:
  - `Env.init()` tự động dò `baseUrl` bằng gọi `/health` trên các địa chỉ phổ biến (10.0.2.2, localhost, IP LAN).
  - Với thiết bị thật: bảo đảm điện thoại và máy chủ cùng mạng; mở Firewall cho cổng `5245`.
- Phân phối nội bộ:
  - Gửi file APK/AAB cho nhóm thử nghiệm; hướng dẫn bật cài đặt từ nguồn không xác định nếu cần.
  - Thu thập phản hồi log qua Flutter DevTools.

6.3. Cách vận hành hệ thống
- Quy trình khởi động:
  - Bước 1: chạy Backend và kiểm tra `/health` (trả `OK`).
  - Bước 2: mở app Flutter; kiểm tra `Env.baseUrl` đã chọn đúng.
  - Bước 3: đăng nhập bằng tài khoản mẫu (admin/khách/nhân viên) để xác nhận phân quyền.
- Theo dõi & bảo trì:
  - Log API: kiểm tra lỗi 4xx/5xx; rà soát truy vấn chậm.
  - Dữ liệu: dọn dẹp các bản ghi thử nghiệm, theo dõi tăng trưởng bảng `PickupRequests`.
  - Ảnh người dùng: kiểm soát dung lượng `uploads/avatars/`; xóa file mồ côi nếu có.
- Quy trình cập nhật:
  - Áp dụng migration mới, kiểm tra Swagger, sau đó phát hành APK mới nếu có thay đổi giao thức.
  - Sử dụng versioning API nếu có thay đổi phá vỡ (breaking changes).

6.4. Các lỗi phát sinh & cách khắc phục
- Không kết nối được backend:
  - Kiểm tra Firewall và IP LAN; xác nhận `Env.baseUrl` qua `/health`; mở CORS cho domain thiết bị.
- Upload ảnh thất bại:
  - Giới hạn kích thước ảnh và nén trên client (`imageQuality`); xác nhận `multipart/form-data` và tên field `file` đúng.
- Tràn giao diện trên màn hình nhỏ:
  - Dùng `Wrap`, `Flexible` cho cụm nút; kiểm tra trên thiết bị phổ biến.
- Sai toạ độ GPS hoặc thiếu quyền:
  - Bật quyền vị trí; thử lại với tín hiệu GPS ngoài trời; kiểm tra `Geolocator` phiên bản.
- Token JWT hết hạn:
  - Bắt sự kiện 401; yêu cầu đăng nhập lại; giảm rủi ro bằng refresh token nếu cần.

CHƯƠNG 7: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN
7.1. Kết luận chung
- Mức độ đáp ứng yêu cầu: đầy đủ các luồng chính (đăng nhập JWT, đặt lịch, điều phối bản đồ, listings, quản trị dữ liệu cơ bản).
- Tính ổn định: thao tác mượt trên thiết bị thật; thời gian phản hồi API phù hợp (trung bình 150–250ms ở môi trường dev).
- Khả năng mở rộng: kiến trúc tách client/server; thêm tính năng mới không làm gián đoạn phần còn lại.

7.2. Các kết quả đạt được
- Nghiệp vụ:
  - Khách hàng: phân loại rác, đặt lịch, xem “Lịch của tôi”, đăng/tìm listings.
  - Nhân viên: xem bản đồ, nhận việc, cập nhật trạng thái, gửi vị trí hiện tại.
  - Quản trị: quản lý công ty, nhân viên, khách hàng, danh sách đơn theo trạng thái.
- Kỹ thuật:
  - REST API theo nhóm chức năng, phân quyền rõ ràng; health check; swagger.
  - CSDL quan hệ chuẩn hoá, ràng buộc FK; seed dữ liệu mẫu.
  - Tính năng Media: Text‑to‑Speech; upload avatar multipart; preview ảnh cục bộ trong listings.
  - Trải nghiệm: SliverAppBar, chống tràn bằng `Wrap`, tự dò `baseUrl`.

7.3. Hạn chế của đề tài
- Thông báo đẩy (FCM) chưa triển khai; chưa có chat realtime.
- Chưa áp dụng Clean Architecture đầy đủ (chia Domain/Data/Presentation). `api.dart` còn tập trung nhiều gọi API.
- Bảo mật nâng cao (rate limit, audit log, 2FA) chưa có; chưa có cơ chế backup/restore tự động hoá.
- Khả năng offline‑first mới ở mức cache cơ bản; chưa có đồng bộ hàng đợi khi mất mạng.
- Chưa có quy trình CI/CD tự động (build + deploy) cho cả server và app.

7.4. Hướng phát triển trong tương lai
- Nâng cấp kiến trúc:
  - Chia lớp Domain/Data/Presentation; tách repository/service; giảm phụ thuộc chặt.
  - Thêm `Result`/`Either` cho xử lý lỗi thống nhất; logging/telemetry tập trung.
- Tính năng mới:
  - FCM push cho thay đổi trạng thái đơn; chat nội bộ; rating/feedback sau thu gom.
  - Upload ảnh kèm listings lên server với CDN và thumbnail.
  - Bộ lọc nâng cao (theo thời gian, khu vực, loại phế liệu); export báo cáo.
- Trải nghiệm & hiệu năng:
  - Virtualization list dài; preload bản đồ; tối ưu truy vấn API.
  - Đa ngôn ngữ; dark mode; accessibility.
- Vận hành:
  - CI/CD (GitHub Actions/Azure DevOps) build Docker + publish; auto versioning; rollback nhanh.
  - Backup định kỳ DB/file; giám sát health, cảnh báo sự cố; quy trình on‑call.
 
