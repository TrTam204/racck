using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using ScrapApi.Data;
using ScrapApi.Endpoints; // <- để gọi MapXxxEndpoints()
using Microsoft.AspNetCore.Authorization;

var builder = WebApplication.CreateBuilder(args);

// 1. DbContext (SQL Server)
builder.Services.AddDbContext<AppDb>(opt =>
    opt.UseSqlServer(
        builder.Configuration.GetConnectionString("SqlServer")
        ?? @"Data Source=(localdb)\MSSQLLocalDB;Initial Catalog=ScrapApiDb;
             Integrated Security=True;TrustServerCertificate=True;Connect Timeout=30"
    )
);

// 2. Swagger + Bearer
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "ScrapApi", Version = "v1" });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name         = "Authorization",
        In           = ParameterLocation.Header,
        Type         = SecuritySchemeType.Http,
        Scheme       = "bearer",
        BearerFormat = "JWT",
        Description  = "Nhập: Bearer {token}"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement {
    {
        new OpenApiSecurityScheme {
            Reference = new OpenApiReference {
                Id   = "Bearer",
                Type = ReferenceType.SecurityScheme
            }
        },
        Array.Empty<string>()
    }});
});

// 3. CORS mở full cho Flutter trong dev
builder.Services.AddCors(opt =>
{
    opt.AddDefaultPolicy(p =>
        p.AllowAnyOrigin()
         .AllowAnyHeader()
         .AllowAnyMethod()
    );
});

// 4. JWT auth
var jwtKey    = builder.Configuration["Jwt:Key"]    ?? "dev_temp_secret_123456";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "ScrapApi";

builder.Services.AddAuthentication(o =>
{
    o.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    o.DefaultChallengeScheme    = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(o =>
{
    o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer           = true,
        ValidateAudience         = false,
        ValidateIssuerSigningKey = true,
        ValidIssuer              = jwtIssuer,
        IssuerSigningKey         = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(jwtKey)
        ),
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

// 5. middleware thứ tự chuẩn
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// bật Swagger khi Develop
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.DocumentTitle  = "ScrapApi Swagger";
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "ScrapApi v1");
    });
}

// 6. migrate + seed DB trước khi nhận request
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDb>();
    await db.Database.MigrateAsync();
    await SeedData.InitAsync(db);
}

// ================== health check đơn giản ==================
app.MapGet("/health", () => Results.Ok(new { status = "OK" }));

app.MapGet("/whoami", (HttpContext ctx) =>
{
    // localIp: cố lấy địa chỉ IP của server trong mạng LAN
    // gợi ý: lấy từ Connection
    var localIp = ctx.Connection.LocalIpAddress?.ToString() ?? "unknown";
    var localPort = ctx.Connection.LocalPort;

    return Results.Ok(new {
        ip = localIp,
        port = localPort,
        status = "OK"
    });
});


// 7. map các nhóm endpoint vào app
app.MapAuthEndpoints();        // /api/auth/register, /api/auth/login
app.MapCompaniesEndpoints();   // /api/companies ... (có [Authorize(Roles="admin")])
app.MapCustomersEndpoints();   // /api/customers...
app.MapPickupsEndpoints();     // /api/pickups...
app.MapCollectorsEndpoints();  // /api/collectors/... (location, công việc của tôi)
app.MapListingsEndpoints();    // /api/listings...
app.MapDispatchEndpoints();    // /api/dispatch/live, /dispatch-nearest
app.MapManagementEndpoints();


app.Run();
