using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class ManagementEndpoints
    {
        public static void MapManagementEndpoints(this IEndpointRouteBuilder app)
        {
            // Tạo 1 nhóm route dành riêng cho admin
            // Tất cả endpoint bên trong sẽ có prefix /api/admin
            // và yêu cầu role = admin
            var adminGroup = app.MapGroup("/api/admin")
                .RequireAuthorization(policy => policy.RequireRole("admin"));

            // ============================
            // 1) COMPANY MANAGEMENT
            // ============================

            // GET /api/admin/companies
            adminGroup.MapGet("/companies", async (AppDb db) =>
            {
                var data = await db.CollectorCompanies
                    .Include(c => c.Collectors)
                    .Select(c => new {
                        c.Id,
                        c.Name,
                        c.ContactPhone,
                        c.Address,
                        collectors = c.Collectors.Select(co => new {
                            co.Id,
                            co.FullName,
                            co.Phone,
                            co.CompanyId
                        }).ToList()
                    })
                    .ToListAsync();

                return Results.Ok(data);
            });

            // POST /api/admin/companies
            adminGroup.MapPost("/companies", async (AppDb db, CollectorCompany co) =>
            {
                db.CollectorCompanies.Add(co);
                await db.SaveChangesAsync();
                return Results.Created($"/api/admin/companies/{co.Id}", co);
            });

            // PUT /api/admin/companies/{id}
            adminGroup.MapPut("/companies/{id:int}", async (AppDb db, int id, CollectorCompany input) =>
            {
                var co = await db.CollectorCompanies.FindAsync(id);
                if (co == null) return Results.NotFound();

                co.Name         = input.Name;
                co.ContactPhone = input.ContactPhone;
                co.Address      = input.Address;

                await db.SaveChangesAsync();
                return Results.Ok(co);
            });

            // DELETE /api/admin/companies/{id}
            adminGroup.MapDelete("/companies/{id:int}", async (AppDb db, int id) =>
            {
                var co = await db.CollectorCompanies
                    .Include(c => c.Collectors)
                    .FirstOrDefaultAsync(c => c.Id == id);

                if (co == null) return Results.NotFound();

                // tuỳ chính sách: xoá luôn collectors con
                db.Collectors.RemoveRange(co.Collectors);
                db.CollectorCompanies.Remove(co);

                await db.SaveChangesAsync();
                return Results.NoContent();
            });

            // ============================
            // 2) COLLECTOR MANAGEMENT
            // ============================

            // POST /api/admin/collectors
            adminGroup.MapPost("/collectors", async (AppDb db, Collector c) =>
            {
                db.Collectors.Add(c);
                await db.SaveChangesAsync();
                return Results.Created($"/api/admin/collectors/{c.Id}", c);
            });

            // PUT /api/admin/collectors/{id}
            adminGroup.MapPut("/collectors/{id:int}", async (AppDb db, int id, Collector input) =>
            {
                var c = await db.Collectors.FindAsync(id);
                if (c == null) return Results.NotFound();

                c.FullName  = input.FullName;
                c.Phone     = input.Phone;
                c.CompanyId = input.CompanyId;

                await db.SaveChangesAsync();
                return Results.Ok(c);
            });

            // DELETE /api/admin/collectors/{id}
            adminGroup.MapDelete("/collectors/{id:int}", async (AppDb db, int id) =>
            {
                var c = await db.Collectors.FindAsync(id);
                if (c == null) return Results.NotFound();

                db.Collectors.Remove(c);
                await db.SaveChangesAsync();
                return Results.NoContent();
            });
        }
    }
}
