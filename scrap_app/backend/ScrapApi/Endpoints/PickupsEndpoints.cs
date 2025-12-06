using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class PickupsEndpoints
    {
        public static void MapPickupsEndpoints(this IEndpointRouteBuilder app)
        {
            // ============================================================
            // GET /api/pickups
            // Dành cho admin / dispatcher xem tất cả pickups
            // Có thể filter theo status, collectorId, customerId
            // -> Trả DTO camelCase, tránh vòng lặp navigation EF
            // ============================================================
            app.MapGet("/api/pickups", async (
                AppDb db,
                int? status,
                int? collectorId,
                int? customerId
            ) =>
            {
                var q = db.PickupRequests
                    .Include(p => p.Customer)
                    .Include(p => p.AcceptedByCollector)
                    .AsQueryable();

                if (status is not null)
                    q = q.Where(p => (int)p.Status == status);

                if (collectorId is not null)
                    q = q.Where(p => p.AcceptedByCollectorId == collectorId);

                if (customerId is not null)
                    q = q.Where(p => p.CustomerId == customerId);

                var data = await q
                    .OrderByDescending(p => p.CreatedAt)
                    .Select(p => new
                    {
                        id = p.Id,
                        scrapType = p.ScrapType,
                        quantityKg = p.QuantityKg,
                        pickupTime = p.PickupTime,
                        lat = p.Lat,
                        lng = p.Lng,
                        note = p.Note,
                        status = (int)p.Status,
                        createdAt = p.CreatedAt,

                        customer = p.Customer == null
                            ? null
                            : new
                            {
                                id = p.Customer.Id,
                                fullName = p.Customer.FullName,
                                phone = p.Customer.Phone,
                                address = p.Customer.Address
                            },

                        collector = p.AcceptedByCollector == null
                            ? null
                            : new
                            {
                                id = p.AcceptedByCollector.Id,
                                fullName = p.AcceptedByCollector.FullName,
                                phone = p.AcceptedByCollector.Phone,
                                companyId = p.AcceptedByCollector.CompanyId
                            }
                    })
                    .ToListAsync();

                return Results.Ok(data);
            });

            // ============================================================
            // GET /api/collectors/{id}/pickups?status=...
            //
            // Màn hình "Công việc của tôi" cho NHÂN VIÊN THU GOM
            //
            // Logic:
            //   - Trả về:
            //       A) job đang Pending (chưa ai nhận)
            //       B) job đã gán cho collector hiện tại (Accepted/InProgress/...)
            //   - Nếu truyền ?status=... thì lọc thêm
            //
            // Response:
            //   assignedCollector:
            //        null  -> chưa ai nhận
            //        {...} -> ai đang giữ job (có thể chính bạn, có thể người khác)
            //
            // Tất cả key camelCase để Flutter parse được.
            // ============================================================
            app.MapGet("/api/collectors/{id:int}/pickups",
                async (AppDb db, int id, int? status) =>
                {
                    var q = db.PickupRequests
                        .Include(p => p.Customer)
                        .Include(p => p.AcceptedByCollector)
                        .Where(p =>
                            // A: job còn Pending và chưa có người nhận
                            (p.Status == PickupStatus.Pending && p.AcceptedByCollectorId == null)
                            ||
                            // B: job đã assign cho chính collector này
                            (p.AcceptedByCollectorId == id)
                        );

                    if (status is not null)
                    {
                        q = q.Where(p => (int)p.Status == status);
                    }

                    var data = await q
                        .OrderByDescending(p => p.CreatedAt)
                        .Select(p => new
                        {
                            id = p.Id,
                            scrapType = p.ScrapType,
                            quantityKg = p.QuantityKg,
                            pickupTime = p.PickupTime, // ISO 8601 -> Dart DateTime.parse ok
                            lat = p.Lat,
                            lng = p.Lng,
                            note = p.Note,
                            status = (int)p.Status,

                            customer = p.Customer == null
                                ? null
                                : new
                                {
                                    id = p.Customer.Id,
                                    fullName = p.Customer.FullName,
                                    phone = p.Customer.Phone,
                                    address = p.Customer.Address
                                },

                            assignedCollector = p.AcceptedByCollector == null
                                ? null
                                : new
                                {
                                    id = p.AcceptedByCollector.Id,
                                    fullName = p.AcceptedByCollector.FullName,
                                    phone = p.AcceptedByCollector.Phone
                                }
                        })
                        .ToListAsync();

                    return Results.Ok(data);
                });

            // ============================================================
            // GET /api/customers/{id}/pickups?status=...
            //
            // Tab "Lịch đã đặt" của KHÁCH HÀNG
            //  - chỉ lấy các yêu cầu do customer này tạo
            //  - trả thêm collector (nếu đã có người nhận)
            //
            // Flutter màn hình MyBookingsScreen gọi cái này qua
            // _api.getMyCustomerPickups(customerId)
            //
            // Quan trọng: field "collector" (camelCase) sẽ map vào
            // PickupRequest.collector trong Flutter.
            // ============================================================
            app.MapGet("/api/customers/{id:int}/pickups",
                async (AppDb db, int id, int? status) =>
                {
                    var q = db.PickupRequests
                        .Include(p => p.Customer)
                        .Include(p => p.AcceptedByCollector)
                        .Where(p => p.CustomerId == id);

                    if (status is not null)
                    {
                        q = q.Where(p => (int)p.Status == status);
                    }

                    var data = await q
                        .OrderByDescending(p => p.CreatedAt)
                        .Select(p => new
                        {
                            id = p.Id,
                            scrapType = p.ScrapType,
                            quantityKg = p.QuantityKg,
                            pickupTime = p.PickupTime,
                            lat = p.Lat,
                            lng = p.Lng,
                            note = p.Note,
                            status = (int)p.Status,

                            customer = p.Customer == null
                                ? null
                                : new
                                {
                                    id = p.Customer.Id,
                                    fullName = p.Customer.FullName,
                                    phone = p.Customer.Phone,
                                    address = p.Customer.Address
                                },

                            collector = p.AcceptedByCollector == null
                                ? null
                                : new
                                {
                                    id = p.AcceptedByCollector.Id,
                                    fullName = p.AcceptedByCollector.FullName,
                                    phone = p.AcceptedByCollector.Phone
                                }
                        })
                        .ToListAsync();

                    return Results.Ok(data);
                });

            // ============================================================
            // POST /api/pickups
            //
            // Khách tạo yêu cầu thu gom mới.
            // Body client gửi (Flutter):
            // {
            //   "customerId": 12,
            //   "scrapType": "Nhôm",
            //   "quantityKg": 10,
            //   "pickupTime": "2025-11-03T10:30:00Z",
            //   "lat": 10.7,
            //   "lng": 106.6,
            //   "note": "Gọi em trước 5 phút"
            // }
            //
            // Server sẽ ép:
            //   Status = Pending (0)
            //   AcceptedByCollectorId = null
            //   CreatedAt = UtcNow
            //
            // Và trả về DTO camelCase (giống khi load lịch).
            // ============================================================
            app.MapPost("/api/pickups", async (AppDb db, PickupRequest req) =>
            {
                if (req.QuantityKg <= 0)
                    return Results.BadRequest("QuantityKg must be > 0");
                if (string.IsNullOrWhiteSpace(req.ScrapType))
                    return Results.BadRequest("ScrapType is required");

                req.Status = PickupStatus.Pending;
                req.AcceptedByCollectorId = null;
                req.CreatedAt = DateTime.UtcNow;

                db.PickupRequests.Add(req);
                await db.SaveChangesAsync();

                var saved = await db.PickupRequests
                    .Include(p => p.Customer)
                    .Include(p => p.AcceptedByCollector)
                    .Where(p => p.Id == req.Id)
                    .Select(p => new
                    {
                        id = p.Id,
                        scrapType = p.ScrapType,
                        quantityKg = p.QuantityKg,
                        pickupTime = p.PickupTime,
                        lat = p.Lat,
                        lng = p.Lng,
                        note = p.Note,
                        status = (int)p.Status,
                        createdAt = p.CreatedAt,

                        customer = p.Customer == null
                            ? null
                            : new
                            {
                                id = p.Customer.Id,
                                fullName = p.Customer.FullName,
                                phone = p.Customer.Phone,
                                address = p.Customer.Address
                            },

                        collector = p.AcceptedByCollector == null
                            ? null
                            : new
                            {
                                id = p.AcceptedByCollector.Id,
                                fullName = p.AcceptedByCollector.FullName,
                                phone = p.AcceptedByCollector.Phone
                            }
                    })
                    .FirstAsync();

                return Results.Created($"/api/pickups/{req.Id}", saved);
            });

            // ============================================================
            // POST /api/pickups/{id}/accept?collectorId=...
            //
            // Collector bấm "Nhận job".
            // Yêu cầu:
            //   - job phải còn Pending
            //   - collectorId phải tồn tại
            //
            // Sau khi nhận:
            //   Status = Accepted (1)
            //   AcceptedByCollectorId = collectorId
            //
            // Trả lại DTO camelCase để app refresh màn hình.
            // ============================================================
            app.MapPost("/api/pickups/{id:int}/accept",
                async (AppDb db, int id, int collectorId) =>
                {
                    var req = await db.PickupRequests.FindAsync(id);
                    if (req is null)
                        return Results.NotFound();

                    var col = await db.Collectors.FindAsync(collectorId);
                    if (col is null)
                        return Results.BadRequest("Collector not found");

                    if (req.Status != PickupStatus.Pending)
                        return Results.BadRequest("Only pending requests can be accepted");

                    req.Status = PickupStatus.Accepted;      // 1
                    req.AcceptedByCollectorId = collectorId; // gán collector
                    await db.SaveChangesAsync();

                    var updated = await db.PickupRequests
                        .Include(p => p.Customer)
                        .Include(p => p.AcceptedByCollector)
                        .Where(p => p.Id == req.Id)
                        .Select(p => new
                        {
                            id = p.Id,
                            scrapType = p.ScrapType,
                            quantityKg = p.QuantityKg,
                            pickupTime = p.PickupTime,
                            lat = p.Lat,
                            lng = p.Lng,
                            note = p.Note,
                            status = (int)p.Status,
                            createdAt = p.CreatedAt,

                            customer = p.Customer == null
                                ? null
                                : new
                                {
                                    id = p.Customer.Id,
                                    fullName = p.Customer.FullName,
                                    phone = p.Customer.Phone,
                                    address = p.Customer.Address
                                },

                            collector = p.AcceptedByCollector == null
                                ? null
                                : new
                                {
                                    id = p.AcceptedByCollector.Id,
                                    fullName = p.AcceptedByCollector.FullName,
                                    phone = p.AcceptedByCollector.Phone
                                }
                        })
                        .FirstAsync();

                    return Results.Ok(updated);
                });

            // ============================================================
            // POST /api/pickups/{id}/status?status=...
            //
            // Collector cập nhật tiến độ:
            //   Pending(0) -> Accepted(1) -> InProgress(2) -> Completed(3)
            //   hoặc Cancelled(4)
            //
            // App sẽ gọi cái này khi bấm "Bắt đầu", "Hoàn tất", "Huỷ".
            //
            // Trả lại DTO camelCase giống như load danh sách để màn hình
            // có thể update ngay không cần gọi lại GET.
            // ============================================================
            app.MapPost("/api/pickups/{id:int}/status",
                async (AppDb db, int id, PickupStatus status) =>
                {
                    var req = await db.PickupRequests.FindAsync(id);
                    if (req is null)
                        return Results.NotFound();

                    req.Status = status;
                    await db.SaveChangesAsync();

                    var updated = await db.PickupRequests
                        .Include(p => p.Customer)
                        .Include(p => p.AcceptedByCollector)
                        .Where(p => p.Id == req.Id)
                        .Select(p => new
                        {
                            id = p.Id,
                            scrapType = p.ScrapType,
                            quantityKg = p.QuantityKg,
                            pickupTime = p.PickupTime,
                            lat = p.Lat,
                            lng = p.Lng,
                            note = p.Note,
                            status = (int)p.Status,
                            createdAt = p.CreatedAt,

                            customer = p.Customer == null
                                ? null
                                : new
                                {
                                    id = p.Customer.Id,
                                    fullName = p.Customer.FullName,
                                    phone = p.Customer.Phone,
                                    address = p.Customer.Address
                                },

                            collector = p.AcceptedByCollector == null
                                ? null
                                : new
                                {
                                    id = p.AcceptedByCollector.Id,
                                    fullName = p.AcceptedByCollector.FullName,
                                    phone = p.AcceptedByCollector.Phone
                                }
                        })
                        .FirstAsync();

                    return Results.Ok(updated);
                });

            // ============================================================
            // DEBUG 1: POST /api/debug/createTestPickup
            // Tạo 1 job mẫu Accepted cho collectorId=1
            //
            // Dùng nội bộ dev để seed nhanh.
            // ============================================================
            app.MapPost("/api/debug/createTestPickup",
                async (AppDb db) =>
                {
                    // collector giả định id=1
                    var coll = await db.Collectors
                        .FirstOrDefaultAsync(c => c.Id == 1);

                    // lấy customer đầu tiên
                    var cust = await db.Customers
                        .OrderBy(c => c.Id)
                        .FirstOrDefaultAsync();

                    if (coll == null || cust == null)
                    {
                        return Results.BadRequest(
                            "Thiếu collectorId=1 hoặc thiếu customer để tạo job test"
                        );
                    }

                    var req = new PickupRequest
                    {
                        CustomerId = cust.Id,
                        ScrapType = "Giấy carton",
                        QuantityKg = 15,
                        PickupTime = DateTime.UtcNow.AddMinutes(45),
                        Lat = 10.79,
                        Lng = 106.70,
                        Note = "Gọi bảo vệ chung cư",
                        Status = PickupStatus.Accepted,     // 1
                        AcceptedByCollectorId = 1,          // gán cho collectorId=1
                        CreatedAt = DateTime.UtcNow
                    };

                    db.PickupRequests.Add(req);
                    await db.SaveChangesAsync();

                    return Results.Ok(new
                    {
                        message    = "Đã tạo job test cho collectorId=1",
                        pickupId   = req.Id,
                        collectorId= req.AcceptedByCollectorId,
                        status     = (int)req.Status
                    });
                });

            // ============================================================
            // DEBUG 2: GET /api/debug/dumpPickups
            // Trả toàn bộ pickup thô (dành cho dev check DB nhanh).
            // ============================================================
            app.MapGet("/api/debug/dumpPickups",
                async (AppDb db) =>
                {
                    var list = await db.PickupRequests
                        .Include(p => p.Customer)
                        .Include(p => p.AcceptedByCollector)
                        .OrderByDescending(p => p.CreatedAt)
                        .Select(p => new
                        {
                            id = p.Id,
                            scrapType = p.ScrapType,
                            quantityKg = p.QuantityKg,
                            status = (int)p.Status,
                            acceptedByCollectorId = p.AcceptedByCollectorId,
                            acceptedByCollectorName = p.AcceptedByCollector != null
                                ? p.AcceptedByCollector.FullName
                                : null,
                            customerId = p.CustomerId,
                            customerName = p.Customer != null
                                ? p.Customer.FullName
                                : null,
                            createdAt = p.CreatedAt,
                            pickupTime = p.PickupTime,
                            lat = p.Lat,
                            lng = p.Lng,
                            note = p.Note
                        })
                        .ToListAsync();

                    return Results.Ok(list);
                });
        }
    }
}
