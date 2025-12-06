using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class CompaniesEndpoints
    {
        public static void MapCompaniesEndpoints(this IEndpointRouteBuilder app)
        {
            // Tất cả route về công ty / collector cho màn hình quản lý
            // YÊU CẦU role = admin
            var companiesGroup = app.MapGroup("/api/companies")
                .RequireAuthorization(policy => policy.RequireRole("admin"));

            // ============================================================
            // GET /api/companies
            // -> trả danh sách công ty + danh sách collector thuộc mỗi công ty
            // dạng camelCase, tránh trả thẳng entity EF
            // ============================================================
            companiesGroup.MapGet("/", async (AppDb db) =>
            {
                var data = await db.CollectorCompanies
                    .Include(c => c.Collectors)
                    .OrderBy(c => c.Id)
                    .Select(c => new
                    {
                        id = c.Id,
                        name = c.Name,
                        contactPhone = c.ContactPhone,
                        address = c.Address,
                        collectors = c.Collectors
                            .OrderBy(col => col.Id)
                            .Select(col => new
                            {
                                id = col.Id,
                                fullName = col.FullName,
                                phone = col.Phone,
                                companyId = col.CompanyId,
                                currentLat = col.CurrentLat,
                                currentLng = col.CurrentLng,
                                lastSeenAt = col.LastSeenAt
                            })
                            .ToList()
                    })
                    .ToListAsync();

                return Results.Ok(data);
            });

            // ============================================================
            // POST /api/companies
            // body JSON:
            // {
            //   "name": "Công ty Thu Gom A",
            //   "contactPhone": "0901-111-222",
            //   "address": "123/5 Lê Lợi, Q1"
            // }
            // -> tạo công ty mới
            // ============================================================
            companiesGroup.MapPost("/", async (AppDb db, CollectorCompany input) =>
            {
                if (string.IsNullOrWhiteSpace(input.Name))
                    return Results.BadRequest("Company name is required");

                var co = new CollectorCompany
                {
                    Name         = input.Name,
                    ContactPhone = input.ContactPhone,
                    Address      = input.Address
                };

                db.CollectorCompanies.Add(co);
                await db.SaveChangesAsync();

                // trả DTO gọn
                return Results.Created($"/api/companies/{co.Id}", new
                {
                    id = co.Id,
                    name = co.Name,
                    contactPhone = co.ContactPhone,
                    address = co.Address
                });
            });

            // ============================================================
            // PUT /api/companies/{id}
            // body JSON giống POST
            // -> chỉnh sửa thông tin công ty
            // ============================================================
            companiesGroup.MapPut("/{id:int}", async (AppDb db, int id, CollectorCompany input) =>
            {
                var co = await db.CollectorCompanies.FindAsync(id);
                if (co is null)
                    return Results.NotFound();

                if (!string.IsNullOrWhiteSpace(input.Name))
                    co.Name = input.Name;

                co.ContactPhone = input.ContactPhone;
                co.Address      = input.Address;

                await db.SaveChangesAsync();

                return Results.Ok(new
                {
                    id = co.Id,
                    name = co.Name,
                    contactPhone = co.ContactPhone,
                    address = co.Address
                });
            });

            // ============================================================
            // DELETE /api/companies/{id}
            //
            // LƯU Ý:
            // - Nếu công ty còn collectors, tuỳ policy.
            //   Ở đây mình KHÔNG xoá collector con để tránh mất dữ liệu ngoài ý muốn.
            //   Nếu còn nhân viên -> báo lỗi.
            //
            // Nếu bạn muốn "xóa cascade luôn", bạn có thể bỏ đoạn check và gọi
            // db.Collectors.RemoveRange(co.Collectors); trước khi Remove(company).
            // ============================================================
            companiesGroup.MapDelete("/{id:int}", async (AppDb db, int id) =>
            {
                var co = await db.CollectorCompanies
                    .Include(c => c.Collectors)
                    .FirstOrDefaultAsync(c => c.Id == id);

                if (co is null)
                    return Results.NotFound();

                if (co.Collectors.Any())
                {
                    return Results.BadRequest("Company still has collectors. Remove / transfer them first.");
                }

                db.CollectorCompanies.Remove(co);
                await db.SaveChangesAsync();

                return Results.NoContent();
            });

            // ============================================================
            // POST /api/companies/collectors
            //
            // body JSON:
            // {
            //   "fullName": "Nguyen Van A",
            //   "phone": "0901-222-333",
            //   "companyId": 3
            // }
            //
            // -> tạo collector (nhân viên thu gom) mới thuộc 1 công ty
            // trả DTO camelCase
            // ============================================================
            companiesGroup.MapPost("/collectors", async (AppDb db, Collector input) =>
            {
                if (string.IsNullOrWhiteSpace(input.FullName))
                    return Results.BadRequest("FullName is required");
                if (string.IsNullOrWhiteSpace(input.Phone))
                    return Results.BadRequest("Phone is required");

                // đảm bảo company tồn tại
                var comp = await db.CollectorCompanies.FindAsync(input.CompanyId);
                if (comp is null)
                    return Results.BadRequest("Company not found");

                var col = new Collector
                {
                    FullName  = input.FullName,
                    Phone     = input.Phone,
                    CompanyId = input.CompanyId,
                    CurrentLat = null,
                    CurrentLng = null,
                    LastSeenAt = null
                };

                db.Collectors.Add(col);
                await db.SaveChangesAsync();

                return Results.Created($"/api/collectors/{col.Id}", new
                {
                    id = col.Id,
                    fullName = col.FullName,
                    phone = col.Phone,
                    companyId = col.CompanyId
                });
            });

            // ============================================================
            // PUT /api/companies/collectors/{id}
            //
            // body JSON:
            // {
            //   "fullName": "Tên mới",
            //   "phone": "SĐT mới",
            //   "companyId": 2
            // }
            //
            // -> chỉnh sửa thông tin collector
            // ============================================================
            companiesGroup.MapPut("/collectors/{id:int}", async (AppDb db, int id, Collector input) =>
            {
                var col = await db.Collectors.FindAsync(id);
                if (col is null)
                    return Results.NotFound();

                if (!string.IsNullOrWhiteSpace(input.FullName))
                    col.FullName = input.FullName;

                if (!string.IsNullOrWhiteSpace(input.Phone))
                    col.Phone = input.Phone;

                if (input.CompanyId != 0 && input.CompanyId != col.CompanyId)
                {
                    // kiểm tra companyId mới có tồn tại không
                    var comp = await db.CollectorCompanies.FindAsync(input.CompanyId);
                    if (comp is null)
                        return Results.BadRequest("New companyId not found");

                    col.CompanyId = input.CompanyId;
                }

                await db.SaveChangesAsync();

                return Results.Ok(new
                {
                    id = col.Id,
                    fullName = col.FullName,
                    phone = col.Phone,
                    companyId = col.CompanyId
                });
            });

            // ============================================================
            // DELETE /api/companies/collectors/{id}
            //
            // -> xoá collector
            // ============================================================
            companiesGroup.MapDelete("/collectors/{id:int}", async (AppDb db, int id) =>
            {
                var col = await db.Collectors.FindAsync(id);
                if (col is null)
                    return Results.NotFound();

                db.Collectors.Remove(col);
                await db.SaveChangesAsync();

                return Results.NoContent();
            });
        }
    }
}
