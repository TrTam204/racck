using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class CustomersEndpoints
    {
        public static void MapCustomersEndpoints(this IEndpointRouteBuilder app)
        {
            app.MapGet("/api/customers", async (AppDb db) =>
                await db.Customers.AsNoTracking().ToListAsync()
            );

            app.MapGet("/api/customers/{id:int}", async (AppDb db, int id) =>
                await db.Customers.FindAsync(id) is { } c
                    ? Results.Ok(c)
                    : Results.NotFound()
            );

            app.MapPost("/api/customers", async (AppDb db, Customer c) =>
            {
                db.Customers.Add(c);
                await db.SaveChangesAsync();
                return Results.Created($"/api/customers/{c.Id}", c);
            });

            app.MapPut("/api/customers/{id:int}", async (AppDb db, int id, CustomerUpdateDto input) =>
            {
                var c = await db.Customers.FindAsync(id);
                if (c is null) return Results.NotFound();

                if (!string.IsNullOrWhiteSpace(input.FullName))
                    c.FullName = input.FullName!;
                if (!string.IsNullOrWhiteSpace(input.Phone))
                    c.Phone = input.Phone!;
                if (input.Email != null)
                    c.Email = input.Email;
                if (input.Gender != null)
                    c.Gender = input.Gender;
                if (input.Address != null)
                    c.Address = input.Address;
                if (input.LastLat != null)
                    c.LastLat = input.LastLat;
                if (input.LastLng != null)
                    c.LastLng = input.LastLng;

                await db.SaveChangesAsync();
                return Results.Ok(c);
            });

            app.MapDelete("/api/customers/{id:int}", async (AppDb db, int id) =>
            {
                var c = await db.Customers.FindAsync(id);
                if (c is null) return Results.NotFound();

                db.Customers.Remove(c);
                await db.SaveChangesAsync();
                return Results.NoContent();
            });

            // cập nhật vị trí khách (LastLat/LastLng)
            app.MapPost("/api/customers/{id:int}/location",
                async (AppDb db, int id, double lat, double lng) =>
                {
                    var c = await db.Customers.FindAsync(id);
                    if (c is null) return Results.NotFound();

                    c.LastLat = lat;
                    c.LastLng = lng;
                    await db.SaveChangesAsync();

                    return Results.Ok(new { c.Id, c.LastLat, c.LastLng });
                });
        }
    }

    public class CustomerUpdateDto
    {
        public string? FullName { get; set; }
        public string? Phone    { get; set; }
        public string? Email    { get; set; }
        public string? Gender   { get; set; }
        public string? Address  { get; set; }
        public double? LastLat  { get; set; }
        public double? LastLng  { get; set; }
    }
}
