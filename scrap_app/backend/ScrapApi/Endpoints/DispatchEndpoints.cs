using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;
using ScrapApi.Utils;

namespace ScrapApi.Endpoints
{
    public static class DispatchEndpoints
    {
        public static void MapDispatchEndpoints(this IEndpointRouteBuilder app)
        {
            // ============================================================
            // GET /api/dispatch/live
            //
            // Dữ liệu "live map" cho màn hình điều phối:
            //  - collectors: tất cả nhân viên thu gom + vị trí GPS hiện tại
            //  - pendingJobs: các job đang chờ (Pending)
            //
            // Trả về camelCase DTO để Flutter đọc dễ.
            // ============================================================
            app.MapGet("/api/dispatch/live", async (AppDb db) =>
            {
                var collectors = await db.Collectors
                    .OrderBy(c => c.Id)
                    .Select(c => new
                    {
                        id = c.Id,
                        fullName = c.FullName,
                        phone = c.Phone,
                        currentLat = c.CurrentLat,
                        currentLng = c.CurrentLng,
                        lastSeenAt = c.LastSeenAt,
                        companyId = c.CompanyId
                    })
                    .ToListAsync();

                var pendingJobs = await db.PickupRequests
                    .Include(p => p.Customer)
                    .Where(p => p.Status == PickupStatus.Pending)
                    .OrderByDescending(p => p.CreatedAt)
                    .Select(p => new
                    {
                        id = p.Id,
                        scrapType = p.ScrapType,
                        quantityKg = p.QuantityKg,
                        lat = p.Lat,
                        lng = p.Lng,
                        createdAt = p.CreatedAt,
                        status = (int)p.Status, // 0 = Pending
                        customerName = p.Customer != null ? p.Customer.FullName : null,
                        customerPhone = p.Customer != null ? p.Customer.Phone : null
                    })
                    .ToListAsync();

                return Results.Ok(new
                {
                    collectors,
                    pendingJobs
                });
            });

            // ============================================================
            // POST /api/pickups/{id}/dispatch-nearest
            //
            // Điều phối nhanh:
            //   - Tìm collector gần nhất trong bán kính cho 1 pickup Pending
            //   - Gán pickup đó cho collector đó (status -> Accepted, set AcceptedByCollectorId)
            //
            // Query params:
            //   jobLat, jobLng  : toạ độ job
            //   radiusKm        : bán kính tối đa (mặc định 10km)
            //   companyId       : (optional) lọc collector thuộc 1 công ty cụ thể
            //
            // Trả về:
            //   - job sau khi gán (camelCase, có collector)
            //   - distanceKm giữa job và collector được chọn
            //
            // Lưu ý: nếu không ai có toạ độ (CurrentLat/CurrentLng null),
            // fallback sẽ gán đại collector đầu tiên.
            // ============================================================
            app.MapPost("/api/pickups/{id:int}/dispatch-nearest", async (
                AppDb db,
                int id,
                double jobLat,
                double jobLng,
                double? radiusKm,
                int? companyId) =>
            {
                // 1. Tìm pickup
                var req = await db.PickupRequests
                    .Include(p => p.Customer)
                    .Include(p => p.AcceptedByCollector)
                    .FirstOrDefaultAsync(p => p.Id == id);

                if (req is null)
                    return Results.NotFound("Pickup not found");

                if (req.Status != PickupStatus.Pending)
                    return Results.BadRequest("Only Pending can be dispatched");

                // 2. Lọc danh sách collector còn hoạt động
                var baseQuery = db.Collectors.AsNoTracking();

                if (companyId is not null)
                {
                    baseQuery = baseQuery.Where(c => c.CompanyId == companyId.Value);
                }

                var allCollectors = await baseQuery.ToListAsync();
                if (allCollectors.Count == 0)
                {
                    return Results.BadRequest("No collectors available");
                }

                // 3. Tính khoảng cách nếu collector có GPS
                var candidates = allCollectors
                    .Where(c => c.CurrentLat != null && c.CurrentLng != null)
                    .Select(c => new
                    {
                        Collector = c,
                        DistKm = GeoUtils.Haversine(
                            jobLat,
                            jobLng,
                            c.CurrentLat!.Value,
                            c.CurrentLng!.Value
                        )
                    })
                    .OrderBy(x => x.DistKm)
                    .ToList();

                var chosen = candidates.FirstOrDefault();

                // 4. Nếu không ai có toạ độ -> fallback: chọn collector đầu tiên bất kỳ
                if (chosen is null)
                {
                    var any = allCollectors.First();

                    req.Status = PickupStatus.Accepted;          // 1
                    req.AcceptedByCollectorId = any.Id;
                    await db.SaveChangesAsync();

                    // load lại đầy đủ để trả DTO camelCase
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
                                    phone = p.AcceptedByCollector.Phone,
                                    companyId = p.AcceptedByCollector.CompanyId
                                }
                        })
                        .FirstAsync();

                    return Results.Ok(new
                    {
                        assignedCollectorId = any.Id,
                        distanceKm = (double?)null,
                        note = "No collector position known; assigned first collector.",
                        pickup = updated
                    });
                }

                // 5. Có collector gần nhất có GPS
                var nearest = chosen.Collector;
                var distKm = chosen.DistKm;
                var radius = radiusKm ?? 10.0;

                if (distKm > radius)
                {
                    return Results.BadRequest(
                        $"Nearest collector is {distKm:0.00} km away (> {radius:0.##} km)"
                    );
                }

                // Gán job
                req.Status = PickupStatus.Accepted;          // 1
                req.AcceptedByCollectorId = nearest.Id;
                await db.SaveChangesAsync();

                // Load lại job sau update để trả DTO camelCase đầy đủ
                var updatedJob = await db.PickupRequests
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
                                phone = p.AcceptedByCollector.Phone,
                                companyId = p.AcceptedByCollector.CompanyId
                            }
                    })
                    .FirstAsync();

                return Results.Ok(new
                {
                    assignedCollectorId = nearest.Id,
                    distanceKm = distKm,
                    pickup = updatedJob
                });
            });
        }
    }
}
