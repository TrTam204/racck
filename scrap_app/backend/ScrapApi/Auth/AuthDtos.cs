namespace ScrapApi.Auth
{
    // Dùng khi người dùng tự đăng ký (nếu bạn còn giữ luồng này)
    // Body ví dụ:
    // {
    //   "username": "alice",
    //   "password": "123456",
    //   "role": "customer",
    //   "customerId": 3,
    //   "collectorId": null
    // }
    public record RegisterDto(
        string Username,
        string Password,
        string? Role,
        int? CustomerId,
        int? CollectorId
    );

    // Dùng khi đăng nhập
    // {
    //    "username": "alice",
    //    "password": "123456"
    // }
    public record LoginDto(
        string Username,
        string Password
    );

    // Dùng cho ADMIN tạo tài khoản đăng nhập cho nhân viên thu gom đã tồn tại trong bảng Collectors
    //
    // POST /api/admin/createCollectorUser
    // {
    //    "collectorId": 7,
    //    "username": "nhanvien7",
    //    "password": "123456"
    // }
    //
    // API sẽ tạo 1 User:
    //  - Username = "nhanvien7"
    //  - PasswordHash = hash("123456")
    //  - Role = "collector"
    //  - CollectorId = 7
    //  - CustomerId = null
    public record CreateCollectorUserDto(
        int CollectorId,
        string Username,
        string Password
    );

    public record ChangePasswordDto(
        string OldPassword,
        string NewPassword
    );

    public record ForgotPasswordDto(
        string Username
    );

    public record ResetPasswordDto(
        string Username,
        string Code,
        string NewPassword
    );
}
