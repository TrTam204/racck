using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class CollectorsEndpoints
    {
        public static void MapCollectorsEndpoints(this IEndpointRouteBuilder app)
        {
            // =========================
            // GET /api/collectors
            // Dùng để load danh sách collector (tab Quản lý, dropdown ...)
            // =========================
            app.MapGet("/api/collectors",
                async (AppDb db) =>
                {
                    var list = await db.Collectors
                        .OrderBy(c => c.Id)
                        .Select(c => new
                        {
                            id = c.Id,
                            fullName = c.FullName,
                            phone = c.Phone,
                            email = c.Email,
                            gender = c.Gender,
                            companyId = c.CompanyId,
                            currentLat = c.CurrentLat,
                            currentLng = c.CurrentLng,
                            lastSeenAt = c.LastSeenAt
                        })
                        .ToListAsync();

                    return Results.Ok(list);
                });

            app.MapGet("/api/collectors/{id:int}",
                async (AppDb db, int id) =>
                {
                    var c = await db.Collectors.FindAsync(id);
                    if (c == null) return Results.NotFound();
                    return Results.Ok(new
                    {
                        id = c.Id,
                        fullName = c.FullName,
                        phone = c.Phone,
                        email = c.Email,
                        gender = c.Gender,
                        companyId = c.CompanyId,
                        currentLat = c.CurrentLat,
                        currentLng = c.CurrentLng,
                        lastSeenAt = c.LastSeenAt
                    });
                });

            // =========================
            // POST /api/collectors
            // Flutter gọi khi bạn bấm "Thêm collector"
            // body JSON ví dụ:
            // {
            //   "companyId": 1,
            //   "fullName": "Nguyen Van A",
            //   "phone": "0901-111-222"
            // }
            // =========================
            app.MapPost("/api/collectors",
                async (AppDb db, CollectorCreateDto dto) =>
                {
                    // kiểm tra input tối thiểu
                    if (string.IsNullOrWhiteSpace(dto.FullName))
                        return Results.BadRequest("FullName is required");
                    if (string.IsNullOrWhiteSpace(dto.Phone))
                        return Results.BadRequest("Phone is required");

                    // kiểm tra DN có tồn tại không
                    var comp = await db.CollectorCompanies
                        .FirstOrDefaultAsync(x => x.Id == dto.CompanyId);
                    if (comp == null)
                        return Results.BadRequest("Company not found");

                    var col = new Collector
                    {
                        FullName   = dto.FullName,
                        Phone      = dto.Phone,
                        Email      = dto.Email,
                        Gender     = dto.Gender,
                        CompanyId  = dto.CompanyId,
                        CurrentLat = null,
                        CurrentLng = null,
                        LastSeenAt = null,
                    };

                    db.Collectors.Add(col);
                    await db.SaveChangesAsync();

                    return Results.Created(
                        $"/api/collectors/{col.Id}",
                        new
                        {
                            id = col.Id,
                            fullName = col.FullName,
                            phone = col.Phone,
                            email = col.Email,
                            gender = col.Gender,
                            companyId = col.CompanyId
                        }
                    );
                });

            // =========================
            // PUT /api/collectors/{id}
            // Sửa collector (tên, sđt, chuyển công ty ...)
            // body JSON ví dụ:
            // {
            //   "companyId": 2,
            //   "fullName": "Tran Thi B",
            //   "phone": "0902-333-444"
            // }
            // =========================
            app.MapPut("/api/collectors/{id:int}",
                async (AppDb db, int id, CollectorUpdateDto dto) =>
                {
                    var col = await db.Collectors.FindAsync(id);
                    if (col == null) return Results.NotFound();

                    // nếu có đổi công ty
                    if (dto.CompanyId != null)
                    {
                        var comp = await db.CollectorCompanies
                            .FirstOrDefaultAsync(x => x.Id == dto.CompanyId.Value);
                        if (comp == null)
                            return Results.BadRequest("Company not found");
                        col.CompanyId = dto.CompanyId.Value;
                    }

                    if (!string.IsNullOrWhiteSpace(dto.FullName))
                        col.FullName = dto.FullName!;
                    if (!string.IsNullOrWhiteSpace(dto.Phone))
                        col.Phone = dto.Phone!;
                    if (!string.IsNullOrWhiteSpace(dto.Email))
                        col.Email = dto.Email!;
                    if (!string.IsNullOrWhiteSpace(dto.Gender))
                        col.Gender = dto.Gender!;

                    await db.SaveChangesAsync();

                    return Results.Ok(new
                    {
                        id = col.Id,
                        fullName = col.FullName,
                        phone = col.Phone,
                        email = col.Email,
                        gender = col.Gender,
                        companyId = col.CompanyId
                    });
                });

            // =========================
            // DELETE /api/collectors/{id}
            // Xoá collector (nút "Xoá" bên cạnh từng nhân viên)
            // =========================
            app.MapDelete("/api/collectors/{id:int}",
                async (AppDb db, int id) =>
                {
                    var col = await db.Collectors.FindAsync(id);
                    if (col == null) return Results.NotFound();

                    db.Collectors.Remove(col);
                    await db.SaveChangesAsync();

                    return Results.NoContent();
                });

            // =========================
            // POST /api/collectors/{id}/location?lat=..&lng=..
            // Collector cập nhật GPS
            // =========================
            app.MapPost("/api/collectors/{id:int}/location",
                async (AppDb db, int id, double lat, double lng) =>
                {
                    var c = await db.Collectors.FindAsync(id);
                    if (c is null) return Results.NotFound();

                    c.CurrentLat = lat;
                    c.CurrentLng = lng;
                    c.LastSeenAt = DateTime.UtcNow;

                    await db.SaveChangesAsync();

                    return Results.Ok(new
                    {
                        c.Id,
                        c.CurrentLat,
                        c.CurrentLng,
                        c.LastSeenAt
                    });
                });

            // =========================
            // GET /api/collectors/{id}/pickups
            // Lấy danh sách job cho collector
            //
            // !!! Quan trọng:
            // đừng map trùng route ở PickupsEndpoints nữa.
            // Chỉ giữ 1 bản duy nhất trong code backend.
            // Nếu bạn đã chuyển sang PickupsEndpoints như mình hướng dẫn lúc nãy,
            // thì có thể bỏ khối dưới này để tránh double-route.
            // =========================
            // app.MapGet("/api/collectors/{id:int}/pickups", ... );
        }
    }

    // Các DTO để bind JSON từ Flutter
    public class CollectorCreateDto
    {
        public int CompanyId { get; set; }
        public string FullName { get; set; } = "";
        public string Phone { get; set; } = "";
        public string? Email { get; set; }
        public string? Gender { get; set; }
    }

    public class CollectorUpdateDto
    {
        public int? CompanyId { get; set; }
        public string? FullName { get; set; }
        public string? Phone { get; set; }
        public string? Email { get; set; }
        public string? Gender { get; set; }
    }
}
