using Microsoft.EntityFrameworkCore;
using ScrapApi.Models;

namespace ScrapApi.Data
{
    public class AppDb : DbContext
    {
        public AppDb(DbContextOptions<AppDb> options) : base(options) { }

        // Các bảng
        public DbSet<Customer> Customers => Set<Customer>();
        public DbSet<CollectorCompany> CollectorCompanies => Set<CollectorCompany>();
        public DbSet<Collector> Collectors => Set<Collector>();
        public DbSet<PickupRequest> PickupRequests => Set<PickupRequest>();
        public DbSet<ScrapListing> ScrapListings => Set<ScrapListing>();
        public DbSet<User> Users => Set<User>(); // bảng user mới

        protected override void OnModelCreating(ModelBuilder b)
        {
            // 1. Customer (1) -> (n) PickupRequest
            b.Entity<Customer>()
             .HasMany(x => x.PickupRequests)
             .WithOne(x => x.Customer!)
             .HasForeignKey(x => x.CustomerId)
             .OnDelete(DeleteBehavior.Cascade);

            // 2. CollectorCompany (1) -> (n) Collector
            //
            // Quan hệ này EF Core tự hiểu được nhờ:
            // - Collector has int CompanyId
            // - Collector has CollectorCompany? Company
            // - CollectorCompany has List<Collector> Collectors
            //
            // => Không cần cấu hình thủ công .HasMany<Collector>("Collectors")... như lúc nãy
            //
            // Nếu muốn ghi rõ cho dễ đọc (optional, không bắt buộc), bạn có thể làm kiểu strongly-typed như vầy:
            b.Entity<CollectorCompany>()
             .HasMany(cc => cc.Collectors)
             .WithOne(c => c.Company!)
             .HasForeignKey(c => c.CompanyId)
             .OnDelete(DeleteBehavior.Cascade);

            // 3. Collector (1) -> (n) PickupRequest.AcceptedByCollector
            b.Entity<Collector>()
             .HasMany(x => x.AcceptedRequests)
             .WithOne(r => r.AcceptedByCollector!)
             .HasForeignKey(r => r.AcceptedByCollectorId)
             .OnDelete(DeleteBehavior.SetNull);

            // 4. User -> Customer (optional)
            b.Entity<User>()
             .HasOne(u => u.Customer)
             .WithMany() // cho phép 1 khách có nhiều tài khoản nếu sau này muốn
             .HasForeignKey(u => u.CustomerId)
             .OnDelete(DeleteBehavior.SetNull);

            // 5. User -> Collector (optional)
            b.Entity<User>()
             .HasOne(u => u.Collector)
             .WithMany() // tương tự
             .HasForeignKey(u => u.CollectorId)
             .OnDelete(DeleteBehavior.SetNull);
        }
    }


public static class SeedData
{
    public static async Task InitAsync(AppDb db)
    {
        // đảm bảo DB đã tạo
        await db.Database.EnsureCreatedAsync();

        // 1. Seed công ty + collector demo
        if (!db.CollectorCompanies.Any())
        {
            var co = new CollectorCompany
            {
                Name = "GreenCycle Co.",
                ContactPhone = "0909-000-111",
                Address = "HCM"
            };

            db.CollectorCompanies.Add(co);

            db.Collectors.AddRange(
                new Collector
                {
                    FullName = "Nguyen Van A",
                    Phone = "0901111222",
                    Company = co
                },
                new Collector
                {
                    FullName = "Tran Thi B",
                    Phone = "0902333444",
                    Company = co
                }
            );
        }

        // lưu tạm để Collectors có Id
        await db.SaveChangesAsync();

        // lấy 1 collector ổn định (id nhỏ nhất)
        var sampleCollector = await db.Collectors
            .OrderBy(c => c.Id)
            .FirstOrDefaultAsync();

        // 2. Seed khách hàng demo
        if (!db.Customers.Any())
        {
            db.Customers.AddRange(
                new Customer
                {
                    FullName = "Khach 1",
                    Phone = "0987000001",
                    Address = "Q1"
                },
                new Customer
                {
                    FullName = "Khach 2",
                    Phone = "0987000002",
                    Address = "Q3"
                }
            );
        }

        // lưu tạm để Customers có Id
        await db.SaveChangesAsync();

        // lấy 1 customer ổn định (id nhỏ nhất)
        var sampleCustomer = await db.Customers
            .OrderBy(cu => cu.Id)
            .FirstOrDefaultAsync();

        // 3. Seed listing demo
        if (!db.ScrapListings.Any())
        {
            db.ScrapListings.Add(new ScrapListing
            {
                Title = "Nhua PET 200kg",
                Description = "Bao sach",
                PricePerKg = 7000,
                Lat = 10.78,
                Lng = 106.68,
                CreatedAt = DateTime.UtcNow
            });
        }

        // 4. Seed users (admin + customer + collector)
        var adminUser = await db.Users.FirstOrDefaultAsync(u => u.Username == "admin");
        if (adminUser is null)
        {
            db.Users.Add(new User
            {
                Username = "admin",
                PasswordHash = ScrapApi.Auth.AuthUtils.HashPassword("123456"),
                Role = "admin",
                CustomerId = null,
                CollectorId = null
            });
        }
        else
        {
            adminUser.PasswordHash = ScrapApi.Auth.AuthUtils.HashPassword("123456");
            adminUser.Role = "admin";
            adminUser.CustomerId = null;
            adminUser.CollectorId = null;
        }

        if (sampleCustomer != null)
        {
            var custUser = await db.Users.FirstOrDefaultAsync(u => u.Username == "us@gmail.com");
            if (custUser is null)
            {
                db.Users.Add(new User
                {
                    Username = "us@gmail.com",
                    PasswordHash = ScrapApi.Auth.AuthUtils.HashPassword("123456"),
                    Role = "customer",
                    CustomerId = sampleCustomer.Id,
                    CollectorId = null
                });
            }
            else
            {
                custUser.PasswordHash = ScrapApi.Auth.AuthUtils.HashPassword("123456");
                custUser.Role = "customer";
                custUser.CustomerId = sampleCustomer.Id;
                custUser.CollectorId = null;
            }
        }

        if (sampleCollector != null)
        {
            var collUser = await db.Users.FirstOrDefaultAsync(u => u.Username == "nv@gmail.com");
            if (collUser is null)
            {
                db.Users.Add(new User
                {
                    Username = "nv@gmail.com",
                    PasswordHash = ScrapApi.Auth.AuthUtils.HashPassword("123456"),
                    Role = "collector",
                    CustomerId = null,
                    CollectorId = sampleCollector.Id
                });
            }
            else
            {
                collUser.PasswordHash = ScrapApi.Auth.AuthUtils.HashPassword("123456");
                collUser.Role = "collector";
                collUser.CustomerId = null;
                collUser.CollectorId = sampleCollector.Id;
            }
        }

        var oldUsernames = new[] { "admin1", "admin2", "khach1", "nhanvien1" };
        var olds = db.Users.Where(u => oldUsernames.Contains(u.Username)).ToList();
        if (olds.Count > 0)
        {
            db.Users.RemoveRange(olds);
        }

        // 5. Seed 1 PickupRequest gán cho collector sampleCollector
        //    => chính là job sẽ hiện ở app collector
        if (!db.PickupRequests.Any()
            && sampleCollector != null
            && sampleCustomer != null)
        {
            db.PickupRequests.Add(new PickupRequest
            {
                CustomerId = sampleCustomer.Id,          // khách hàng
                ScrapType = "Nhựa PET",
                QuantityKg = 42.5,
                PickupTime = DateTime.UtcNow.AddHours(2),
                Lat = 10.780,                            // toạ độ test
                Lng = 106.680,
                Note = "Khách dặn gọi trước 15 phút",
                Status = PickupStatus.Accepted,          // số 1 (Accepted) trong app
                AcceptedByCollectorId = sampleCollector.Id,
                CreatedAt = DateTime.UtcNow
            });
        }

        await db.SaveChangesAsync();
    }
}


}
