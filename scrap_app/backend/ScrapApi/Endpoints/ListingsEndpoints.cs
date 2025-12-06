using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;
using ScrapApi.Utils;

namespace ScrapApi.Endpoints
{
    public static class ListingsEndpoints
    {
        public static void MapListingsEndpoints(this IEndpointRouteBuilder app)
        {
            // danh sách các bài đăng bán phế liệu
            app.MapGet("/api/listings", async (AppDb db) =>
                await db.ScrapListings
                    .OrderByDescending(x => x.CreatedAt)
                    .ToListAsync()
            );

            // tạo bài đăng
            app.MapPost("/api/listings", async (AppDb db, ScrapListing s) =>
            {
                s.CreatedAt = DateTime.UtcNow;
                db.ScrapListings.Add(s);
                await db.SaveChangesAsync();

                return Results.Created($"/api/listings/{s.Id}", s);
            });

            // search theo từ khoá + bán kính
            app.MapGet("/api/listings/search", async (
                AppDb db,
                string? q,
                double? lat,
                double? lng,
                double? radiusKm,
                int? top) =>
            {
                var query = db.ScrapListings.AsQueryable();

                if (!string.IsNullOrWhiteSpace(q))
                {
                    query = query.Where(x =>
                        x.Title.Contains(q) ||
                        x.Description.Contains(q));
                }

                var max = top is > 0 and <= 200 ? top.Value : 100;

                // lấy trước 1000 bản ghi
                var list = await query
                    .OrderByDescending(x => x.CreatedAt)
                    .Take(1000)
                    .ToListAsync();

                if (lat is not null && lng is not null && radiusKm is not null)
                {
                    list = list
                        .Where(x => x.Lat != null && x.Lng != null)
                        .Select(x => new
                        {
                            Item = x,
                            DistKm = GeoUtils.Haversine(
                                lat.Value,
                                lng.Value,
                                x.Lat!.Value,
                                x.Lng!.Value
                            )
                        })
                        .Where(t => t.DistKm <= radiusKm.Value)
                        .OrderBy(t => t.DistKm)
                        .Take(max)
                        .Select(t => t.Item)
                        .ToList();
                }
                else
                {
                    list = list.Take(max).ToList();
                }

                return Results.Ok(list);
            });
        }
    }
}
