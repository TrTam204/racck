using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;
using ScrapApi.Auth;
using System.Collections.Concurrent;

namespace ScrapApi.Endpoints
{
    public static class AuthEndpoints
    {
        static readonly ConcurrentDictionary<string, (string code, DateTime expire)> _resetCodes = new();
        public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
        {
            // ============================================================
            // 1) Đăng ký tài khoản (cho user tự đăng ký)
            //    body ví dụ:
            //    {
            //      "username": "khach1",
            //      "password": "123456",
            //      "role": "customer"
            //    }
            //
            //    hoặc
            //    {
            //      "username": "nhanvien1",
            //      "password": "123456",
            //      "role": "collector"
            //    }
            //
            //  Luồng:
            //    - customer  => tạo Customer mới, gán vào User.CustomerId
            //    - collector => tạo Collector mới (tự động thuộc 1 company mặc định),
            //                   gán vào User.CollectorId
            //    - admin     => từ chối (admin chỉ seed tay)
            //
            //  => Trả về 201 Created với info user
            // ============================================================
            app.MapPost("/api/auth/register", async (AppDb db, RegisterDto dto) =>
            {
                if (string.IsNullOrWhiteSpace(dto.Username) ||
                    string.IsNullOrWhiteSpace(dto.Password))
                {
                    return Results.BadRequest("Thiếu username/password");
                }

                if (await db.Users.AnyAsync(u => u.Username == dto.Username))
                {
                    return Results.BadRequest("Username tồn tại");
                }

                var desiredRole = (dto.Role ?? "customer").Trim().ToLowerInvariant();

                if (desiredRole == "admin")
                {
                    return Results.BadRequest("Không thể tự tạo tài khoản admin");
                }

                int? newCustomerId = null;
                int? newCollectorId = null;

                if (desiredRole == "customer")
                {
                    var cust = new Customer
                    {
                        FullName = dto.Username,
                        Phone    = dto.Username,
                        Address  = "N/A"
                    };
                    db.Customers.Add(cust);
                    await db.SaveChangesAsync();
                    newCustomerId = cust.Id;
                }
                else if (desiredRole == "collector")
                {
                    // đảm bảo có 1 CollectorCompany để gán
                    var company = await db.CollectorCompanies
                        .FirstOrDefaultAsync();

                    if (company == null)
                    {
                        company = new CollectorCompany
                        {
                            Name         = "Default Company",
                            ContactPhone = "000-000-0000",
                            Address      = "N/A"
                        };
                        db.CollectorCompanies.Add(company);
                        await db.SaveChangesAsync();
                    }

                    var coll = new Collector
                    {
                        FullName  = dto.Username,
                        Phone     = dto.Username,
                        CompanyId = company.Id
                    };
                    db.Collectors.Add(coll);
                    await db.SaveChangesAsync();
                    newCollectorId = coll.Id;
                }
                else
                {
                    return Results.BadRequest("Role không hợp lệ. Chỉ cho phép 'customer' hoặc 'collector'.");
                }

                var user = new User
                {
                    Username     = dto.Username,
                    PasswordHash = AuthUtils.HashPassword(dto.Password),
                    Role         = desiredRole,      // "customer" hoặc "collector"
                    CustomerId   = newCustomerId,
                    CollectorId  = newCollectorId
                };

                db.Users.Add(user);
                await db.SaveChangesAsync();

                return Results.Created(
                    $"/api/users/{user.Id}",
                    new {
                        user.Id,
                        user.Username,
                        user.Role,
                        user.CustomerId,
                        user.CollectorId
                    }
                );
            });


            // ============================================================
            // 1B) Admin tạo tài khoản đăng nhập cho nhân viên thu gom
            //
            // body ví dụ:
            // {
            //    "collectorId": 7,
            //    "username": "nhanvien7",
            //    "password": "123456"
            // }
            //
            // Yêu cầu:
            //    - Chỉ admin mới gọi được
            //    - collectorId phải tồn tại
            //    - username không trùng
            //
            // Kết quả:
            //    - Tạo 1 row User mới:
            //        Role = "collector"
            //        CollectorId = collectorId
            // ============================================================
            app.MapPost("/api/admin/createCollectorUser",
                [Authorize(Roles = "admin")]
                async (AppDb db, CreateCollectorUserDto dto) =>
                {
                    // Kiểm tra collector tồn tại
                    var collector = await db.Collectors
                        .FirstOrDefaultAsync(c => c.Id == dto.CollectorId);

                    if (collector == null)
                    {
                        return Results.BadRequest("CollectorId không tồn tại");
                    }

                    // Check trùng username
                    var exists = await db.Users
                        .AnyAsync(u => u.Username == dto.Username);

                    if (exists)
                    {
                        return Results.BadRequest("Username đã tồn tại");
                    }

                    // Tạo tài khoản user cho collector này
                    var user = new User
                    {
                        Username     = dto.Username,
                        PasswordHash = AuthUtils.HashPassword(dto.Password),
                        Role         = "collector",
                        CollectorId  = dto.CollectorId,
                        CustomerId   = null
                    };

                    db.Users.Add(user);
                    await db.SaveChangesAsync();

                    return Results.Created(
                        $"/api/users/{user.Id}",
                        new {
                            user.Id,
                            user.Username,
                            user.Role,
                            user.CollectorId
                        }
                    );
                }
            );


            // ============================================================
            // 2) Đăng nhập
            //
            // body:
            // {
            //   "username": "admin1",
            //   "password": "admin123"
            // }
            //
            // -> trả về token JWT + role + customerId + collectorId
            // ============================================================
            app.MapPost("/api/auth/login",
                async (AppDb db, LoginDto dto, IConfiguration config) =>
                {
                    var hash = AuthUtils.HashPassword(dto.Password);

                    var user = await db.Users.FirstOrDefaultAsync(u =>
                        u.Username == dto.Username &&
                        u.PasswordHash == hash
                    );

                    // fallback: support tài khoản seed cũ (hash = plain text)
                    if (user is null)
                    {
                        user = await db.Users.FirstOrDefaultAsync(u =>
                            u.Username == dto.Username &&
                            u.PasswordHash == dto.Password
                        );
                    }

                    if (user is null)
                    {
                        return Results.Unauthorized();
                    }

                    var jwtKey    = config["Jwt:Key"]
                                    ?? "THIS_IS_A_DEMO_SUPER_LONG_SECRET_KEY_1234567890_ABCD!!";
                    var jwtIssuer = config["Jwt:Issuer"] ?? "ScrapApi";

                    var token = AuthUtils.CreateJwtToken(
                        username:    user.Username,
                        role:        user.Role,
                        issuer:      jwtIssuer,
                        key:         jwtKey,
                        customerId:  user.CustomerId,
                        collectorId: user.CollectorId
                    );

                    return Results.Ok(new
                    {
                        token,
                        role        = user.Role,
                        customerId  = user.CustomerId,
                        collectorId = user.CollectorId
                    });
                }
            );


            // ============================================================
            // 3) /api/auth/me
            //    Lấy thông tin user hiện tại từ JWT
            //    header: Authorization: Bearer <token>
            // ============================================================
            app.MapGet("/api/auth/me",
                [Authorize]
                async (HttpContext http, AppDb db) =>
                {
                    var username = http.User?.Identity?.Name;
                    if (string.IsNullOrEmpty(username))
                    {
                        return Results.Unauthorized();
                    }

                    var user = await db.Users
                        .Select(u => new {
                            u.Username,
                            u.Role,
                            u.CustomerId,
                            u.CollectorId
                        })
                        .FirstOrDefaultAsync(u => u.Username == username);

                    if (user is null)
                        return Results.NotFound();

                    return Results.Ok(user);
                }
            );


            // ============================================================
            // 4) /api/auth/users
            //    Danh sách tất cả user -> chỉ admin xem
            // ============================================================
            app.MapGet("/api/auth/users",
                [Authorize(Roles = "admin")]
                async (AppDb db) =>
                {
                    var list = await db.Users
                        .OrderBy(u => u.Id)
                        .Select(u => new {
                            u.Id,
                            u.Username,
                            u.Role,
                            u.CustomerId,
                            u.CollectorId
                        })
                        .ToListAsync();

                    return Results.Ok(list);
                }
            );

            app.MapPost("/api/auth/changePassword",
                [Authorize]
                async (HttpContext http, AppDb db, ChangePasswordDto dto) =>
                {
                    var username = http.User?.Identity?.Name;
                    if (string.IsNullOrEmpty(username)) return Results.Unauthorized();

                    var user = await db.Users.FirstOrDefaultAsync(u => u.Username == username);
                    if (user is null) return Results.NotFound();

                    var oldHash = AuthUtils.HashPassword(dto.OldPassword);
                    var ok = user.PasswordHash == oldHash || user.PasswordHash == dto.OldPassword;
                    if (!ok) return Results.BadRequest("Mật khẩu cũ không đúng");

                    user.PasswordHash = AuthUtils.HashPassword(dto.NewPassword);
                    await db.SaveChangesAsync();
                    return Results.Ok(new { message = "Đã đổi mật khẩu" });
                }
            );

            app.MapPost("/api/auth/forgot",
                async (AppDb db, ForgotPasswordDto dto) =>
                {
                    var u = await db.Users.FirstOrDefaultAsync(x => x.Username == dto.Username);
                    if (u is null) return Results.NotFound();

                    var code = Random.Shared.Next(100000, 999999).ToString();
                    var expire = DateTime.UtcNow.AddMinutes(10);
                    _resetCodes[dto.Username] = (code, expire);
                    return Results.Ok(new { code, expiresAt = expire });
                }
            );

            app.MapPost("/api/auth/reset",
                async (AppDb db, ResetPasswordDto dto) =>
                {
                    if (!_resetCodes.TryGetValue(dto.Username, out var info))
                        return Results.BadRequest("Chưa yêu cầu mã đặt lại");
                    if (info.expire < DateTime.UtcNow) return Results.BadRequest("Mã đã hết hạn");
                    if (info.code != dto.Code) return Results.BadRequest("Mã không đúng");

                    var u = await db.Users.FirstOrDefaultAsync(x => x.Username == dto.Username);
                    if (u is null) return Results.NotFound();

                    u.PasswordHash = AuthUtils.HashPassword(dto.NewPassword);
                    await db.SaveChangesAsync();
                    _resetCodes.TryRemove(dto.Username, out _);
                    return Results.Ok(new { message = "Đã đặt lại mật khẩu" });
                }
            );

            // ============================================================
            // 5) Avatar upload/get
            //    POST /api/auth/avatar  (multipart/form-data, field name: file)
            //    GET  /api/auth/avatar  (trả ảnh hiện tại nếu có)
            //    Lưu file theo username: uploads/avatars/<username>.jpg|.png
            // ============================================================
            app.MapPost("/api/auth/avatar",
                [Authorize]
                async (HttpContext http, IHostEnvironment env) =>
                {
                    var username = http.User?.Identity?.Name;
                    if (string.IsNullOrEmpty(username)) return Results.Unauthorized();

                    if (!http.Request.HasFormContentType) return Results.BadRequest("Thiếu form data");
                    var form = await http.Request.ReadFormAsync();
                    var file = form.Files.GetFile("file");
                    if (file == null || file.Length == 0) return Results.BadRequest("Thiếu file ảnh");

                    var uploads = Path.Combine(env.ContentRootPath, "uploads", "avatars");
                    Directory.CreateDirectory(uploads);
                    var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                    if (ext != ".jpg" && ext != ".jpeg" && ext != ".png")
                        return Results.BadRequest("Chỉ chấp nhận jpg/png");

                    var savePath = Path.Combine(uploads, username + ext);
                    await using (var stream = new FileStream(savePath, FileMode.Create))
                    {
                        await file.CopyToAsync(stream);
                    }

                    var url = $"/api/auth/avatar?u={Uri.EscapeDataString(username)}";
                    return Results.Ok(new { url });
                }
            );

            app.MapGet("/api/auth/avatar",
                async (HttpContext http, IHostEnvironment env, string? u) =>
                {
                    var username = u ?? http.User?.Identity?.Name;
                    if (string.IsNullOrEmpty(username)) return Results.NotFound();

                    var uploads = Path.Combine(env.ContentRootPath, "uploads", "avatars");
                    var jpg = Path.Combine(uploads, username + ".jpg");
                    var jpeg = Path.Combine(uploads, username + ".jpeg");
                    var png = Path.Combine(uploads, username + ".png");

                    string? path = null;
                    if (File.Exists(jpg)) path = jpg;
                    else if (File.Exists(jpeg)) path = jpeg;
                    else if (File.Exists(png)) path = png;

                    if (path == null) return Results.NotFound();

                    var contentType = Path.GetExtension(path).ToLowerInvariant() == ".png"
                        ? "image/png"
                        : "image/jpeg";

                    return Results.File(path, contentType);
                }
            );
        }
    }
}
