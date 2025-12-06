using System.Security.Cryptography;
using System.Text;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;
using System.Security.Claims;

namespace ScrapApi.Auth
{
    public static class AuthUtils
    {
        // Băm password người dùng trước khi lưu DB
        public static string HashPassword(string raw)
        {
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(raw));
            return Convert.ToBase64String(bytes);
        }

        // Tạo JWT token sau khi user đăng nhập thành công
        public static string CreateJwtToken(
            string username,
            string role,
            string issuer,
            string key,
            int? customerId,
            int? collectorId
        )
        {
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.Name, username),
                new Claim(ClaimTypes.Role, role),
            };

            if (customerId != null)
                claims.Add(new Claim("customerId", customerId.Value.ToString()));

            if (collectorId != null)
                claims.Add(new Claim("collectorId", collectorId.Value.ToString()));

            var creds = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
                SecurityAlgorithms.HmacSha256
            );

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: null, // mình không check audience nên để null
                claims: claims,
                expires: DateTime.UtcNow.AddDays(7), // token sống 7 ngày
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }
}
