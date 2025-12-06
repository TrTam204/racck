Chuẩn 👌. Mình bổ sung luôn phần cài `.NET SDK`, EF Core CLI, và các package NuGet mà backend đang dùng, rồi chỉnh lại README.md để bạn chỉ việc copy dán.

Dưới đây là phiên bản README.md **đã thêm đầy đủ phần cài đặt package .NET và `dotnet ef`** (Entity Framework Core CLI). Bạn có thể thay thế file cũ bằng file này luôn.

---

````markdown
# Scrap App ♻️  
Ứng dụng thu gom phế liệu / đặt lịch thu gom giữa khách hàng và đơn vị thu gom

---

## 1. Kiến trúc tổng quát

- **Frontend mobile**: Flutter (`/scrap_app/lib/...`)
  - Đăng nhập, đặt lịch thu gom, xem lịch cá nhân
  - Collector xem danh sách pickup và cập nhật trạng thái
  - Admin xem quản lý công ty thu gom, collector, bản đồ điều phối

- **Backend API**: ASP.NET Core Minimal API (`/backend/ScrapApi`)
  - Xác thực JWT
  - Quản lý khách hàng, công ty thu gom, collector, lịch hẹn, listings phế liệu
  - Kết nối SQL Server và tự động migrate + seed dữ liệu ban đầu

- **Database**: SQL Server (LocalDB mặc định)
  - Entity Framework Core Code First
  - Tự động tạo bảng và seed tài khoản admin

---

## 2. Yêu cầu môi trường

### 2.1. Yêu cầu để build/run backend (API .NET)
- **.NET SDK 8.0** (hoặc version đúng với project)
- **SQL Server LocalDB** (có sẵn nếu bạn cài Visual Studio Community với workload ".NET + Data")
  - hoặc SQL Server Express / SQL Server Developer Edition đều được
- **dotnet-ef CLI** để quản lý migrations (tùy chọn nhưng rất nên cài để dev)

### 2.2. Yêu cầu để build/run Flutter app
- Flutter SDK (ví dụ `3.35.x`)
- Dart SDK (đi kèm Flutter)
- Android SDK + Android Studio (để chạy emulator)
- Thiết bị Android thật (USB debugging) hoặc Android emulator

---

## 3. CÀI ĐẶT BACKEND

### 3.1. Clone / mở thư mục backend
```powershell
cd backend/ScrapApi
````

### 3.2. Khôi phục dependency NuGet

```powershell
dotnet restore
```

### 3.3. Các package NuGet quan trọng trong dự án (tham khảo)

Trong `ScrapApi.csproj` dự án đang dùng các gói kiểu như sau (tên & vai trò):

* `Microsoft.EntityFrameworkCore`

  * ORM chính
* `Microsoft.EntityFrameworkCore.SqlServer`

  * Provider để EF Core nói chuyện với SQL Server
* `Microsoft.EntityFrameworkCore.Tools`

  * Hỗ trợ lệnh `dotnet ef`
* `Microsoft.AspNetCore.Authentication.JwtBearer`

  * Giải mã & xác thực JWT trong request
* `Swashbuckle.AspNetCore`

  * Swagger UI + OpenAPI để test API
* `Microsoft.IdentityModel.Tokens`

  * Dùng để ký và validate token JWT
* `System.IdentityModel.Tokens.Jwt`

  * Tạo JWT và đọc JWT
* `Microsoft.AspNetCore.Cors`

  * Bật CORS cho Flutter gọi API

Nếu môi trường của bạn bị thiếu gói nào, bạn có thể cài bằng tay. Ví dụ (chạy trong thư mục `ScrapApi`):

```powershell
dotnet add package Microsoft.EntityFrameworkCore --version 8.*
dotnet add package Microsoft.EntityFrameworkCore.SqlServer --version 8.*
dotnet add package Microsoft.EntityFrameworkCore.Tools --version 8.*
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer --version 8.*
dotnet add package Microsoft.IdentityModel.Tokens --version 8.*
dotnet add package System.IdentityModel.Tokens.Jwt --version 8.*
dotnet add package Swashbuckle.AspNetCore --version 6.*
```

> Gợi ý: Dùng `8.*` để khớp .NET 8, `6.*` cho Swashbuckle. Nếu project của bạn tạo bằng .NET 7 thì sửa `8.*` => `7.*` cho khớp runtime.

### 3.4. CÀI `dotnet ef` CLI (chỉ cần trên máy dev)

`dotnet ef` giúp bạn chạy migration thủ công như `dotnet ef migrations add`, `dotnet ef database update`.

Cài tool global:

```powershell
dotnet tool install --global dotnet-ef
```

Nếu nó báo "đã có sẵn", bạn có thể update:

```powershell
dotnet tool update --global dotnet-ef
```

Kiểm tra:

```powershell
dotnet ef --help
```

> Lưu ý: bạn chỉ cần `dotnet ef` nếu muốn tạo migration mới.
> Khi chạy app bình thường, code của bạn đã gọi `db.Database.MigrateAsync()` rồi, nên DB sẽ tự tạo bảng nếu chưa có.

---

## 4. CẤU HÌNH BACKEND

### 4.1. Kết nối SQL Server

Trong `Program.cs` có phần:

```csharp
builder.Services.AddDbContext<AppDb>(opt =>
    opt.UseSqlServer(
        builder.Configuration.GetConnectionString("SqlServer")
        ?? @"Data Source=(localdb)\MSSQLLocalDB;Initial Catalog=ScrapApiDb;
             Integrated Security=True;TrustServerCertificate=True;Connect Timeout=30"
    )
);
```

Bạn có thể:

* Dùng mặc định (LocalDB) như trên
* Hoặc chỉnh `appsettings.json` -> `ConnectionStrings.SqlServer` để trỏ tới SQL Server riêng

Ví dụ `appsettings.json` (tự tạo hoặc sửa):

```json
{
  "ConnectionStrings": {
    "SqlServer": "Server=YOUR_SQL_SERVER;Database=ScrapApiDb;Trusted_Connection=True;TrustServerCertificate=True"
  }
}
```

### 4.2. JWT config

Trong `launchSettings.json` đã set biến môi trường:

```json
"environmentVariables": {
  "ASPNETCORE_ENVIRONMENT": "Development",
  "Jwt__Key": "dev_temp_secret_123456_dev_temp_secret_123456",
  "Jwt__Issuer": "ScrapApi"
}
```

* `Jwt__Key` phải đủ dài (>=32 bytes) để tạo token HS256.
* Đừng dùng key này cho production.

### 4.3. Cho phép truy cập từ điện thoại và emulator

Cũng trong `launchSettings.json`:

```json
"applicationUrl": "http://0.0.0.0:5245"
```

Nghĩa là API lắng nghe ở mọi network interface trên port `5245`, không chỉ `localhost`.

---

## 5. CHẠY BACKEND

Từ `backend/ScrapApi` chạy:

```powershell
dotnet run
```

Nếu build lần đầu:

```powershell
dotnet build
dotnet run
```

Bạn sẽ thấy log:

```text
Now listening on: http://0.0.0.0:5245
Application started. Press Ctrl+C to shut down.
Hosting environment: Development
Content root path: ...\ScrapApi
```

Backend khi start sẽ:

1. Gọi `db.Database.MigrateAsync()` → Tự tạo / cập nhật database schema theo các migration đã có.
2. Gọi `SeedData.InitAsync(db)` → Tạo dữ liệu mẫu nếu DB trống.

   * Bao gồm tài khoản admin (ví dụ `admin` / `123456`).

### Kiểm tra backend sống:

Trong trình duyệt (trên PC chạy API):

```text
http://localhost:5245/health
```

Phải trả JSON:

```json
{"status":"OK"}
```

Swagger UI (để test API thủ công):

```text
http://localhost:5245/swagger
```

---

## 6. TEST ĐĂNG NHẬP API

Gửi POST `http://localhost:5245/api/auth/login`
Body (JSON):

```json
{
  "username": "admin",
  "password": "123456"
}
```

Nếu đúng, server trả:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9....",
  "role": "admin",
  "customerId": null,
  "collectorId": null
}
```

Token này là JWT, client Flutter sẽ lưu trong `SharedPreferences`.

---

## 7. CHUẨN BỊ FLUTTER APP

### 7.1. Cài dependency Flutter

Trong thư mục Flutter (chứa `pubspec.yaml`):

```powershell
flutter pub get
```

### 7.2. File `lib/env.dart`

App cần biết backend URL. Logic hiện tại:

* Nếu chạy trên **Android emulator** → thử `http://10.0.2.2:5245/health`
* Nếu chạy trên **PC (Flutter Windows/Web)** → thử `http://localhost:5245/health`
* Nếu chạy trên **điện thoại thật** → quét các IP LAN phổ biến như `192.168.x.y` hoặc `10.0.0.y` để xem backend nằm ở đâu
* URL nào trả về `{"status":"OK"}` thì chọn cái đó làm `Env.baseUrl`

`Env.init()` làm chuyện đó; vì vậy main.dart phải chờ nó xong.

### 7.3. File `lib/main.dart`

Điểm chính:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // bắt buộc: dò backend trước
  await Env.init();

  runApp(const RootApp());
}
```

`RootApp`:

* Đọc session từ `SharedPreferences`
* Nếu chưa có token → hiện `LoginScreen`
* Nếu đã có token → hiện `ScrapApp`
* Có hỗ trợ đăng xuất (xoá SharedPreferences)

### 7.4. Chạy Flutter trên emulator

1. Đảm bảo backend (`dotnet run`) đang chạy.
2. Chạy:

   ```powershell
   flutter devices
   flutter run
   ```
3. Đăng nhập bằng `admin` / `123456`.

### 7.5. Chạy Flutter trên ĐIỆN THOẠI THẬT

Điện thoại và laptop phải cùng Wi-Fi.

1. Backend phải nghe `0.0.0.0:5245` (đã cấu hình).
2. Windows Firewall phải allow inbound port `5245` (TCP).
3. Điện thoại kết nối USB, bật Developer Mode + USB debugging.
4. Chạy:

   ```powershell
   flutter devices
   flutter run -d <id_thiet_bi>
   ```

Khi app start, `Env.init()` sẽ thử scan LAN để tìm IP máy tính bằng cách gọi `/health`. Nếu tìm thấy → app dùng IP đó để gọi API.

---

## 8. LỖI HAY GẶP

| Lỗi                                                            | Nguyên nhân                                                                       | Cách xử lý                                                                                                         |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `Lost connection to device` khi `flutter run`                  | Kết nối debug service bị rớt, emulator lâu/quá tải                                | Đóng emulator mở lại, `flutter clean`, rồi `flutter run` lại. Đảm bảo máy không quá nặng.                          |
| `LOGIN ERROR = Exception: Login failed:`                       | Sai tài khoản/mật khẩu hoặc seed chưa chạy                                        | Kiểm tra bảng `Users` trong DB. Test lại bằng Swagger `/api/auth/login`.                                           |
| 401 Unauthorized khi gọi các endpoint admin (`/api/companies`) | Thiếu header Bearer token                                                         | Lấy token từ `/api/auth/login`, gửi `Authorization: Bearer <token>`                                                |
| `Env.init() chưa chạy, chưa biết baseUrl`                      | Bạn gọi API trước khi `await Env.init()`                                          | Kiểm tra `main()` có `await Env.init()` trước `runApp(...)` chưa                                                   |
| Điện thoại thật không kết nối API PC                           | Không chung Wi-Fi, firewall chặn port 5245, hoặc backend chưa mở 0.0.0.0          | Kiểm tra IP PC bằng `ipconfig`, ping từ phone (qua app ping/wifi), mở firewall cho cổng 5245.                      |
| `AmbiguousMatchException` ở backend                            | Bạn map trùng route hai lần (ví dụ `/api/companies` ở 2 file endpoints khác nhau) | Gộp route hoặc đổi route prefix. Ví dụ: `ManagementEndpoints` -> `/api/manage/companies` thay vì `/api/companies`. |

---

## 9. QUY TRÌNH FULL TỪ A→Z

1. Cài môi trường:

   ```powershell
   # .NET SDK 8
   # SQL Server / LocalDB
   dotnet tool install --global dotnet-ef
   ```

2. Backend:

   ```powershell
   cd backend/ScrapApi
   dotnet restore
   dotnet build
   dotnet run
   ```

   → Kiểm tra `http://localhost:5245/health` => `{"status":"OK"}`
   → Kiểm tra Swagger tại `http://localhost:5245/swagger`

3. Flutter:

   ```powershell
   cd scrap_app
   flutter pub get
   flutter run
   ```

4. Đăng nhập trong app:

   * Username: `admin`
   * Password: `123456`

5. Sử dụng app:

   * Customer: đặt lịch thu gom, xem lịch
   * Collector: xem công việc thu gom
   * Admin: quản lý công ty, collector, bản đồ điều phối
   * Nút Đăng xuất ở góc phải AppBar
