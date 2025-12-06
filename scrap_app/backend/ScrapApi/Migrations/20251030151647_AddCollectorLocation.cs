using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ScrapApi.Migrations
{
    /// <inheritdoc />
    public partial class AddCollectorLocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<double>(
                name: "PricePerKg",
                table: "ScrapListings",
                type: "float",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "decimal(18,4)");

            migrationBuilder.AddColumn<double>(
                name: "CurrentLat",
                table: "Collectors",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "CurrentLng",
                table: "Collectors",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSeenAt",
                table: "Collectors",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CurrentLat",
                table: "Collectors");

            migrationBuilder.DropColumn(
                name: "CurrentLng",
                table: "Collectors");

            migrationBuilder.DropColumn(
                name: "LastSeenAt",
                table: "Collectors");

            migrationBuilder.AlterColumn<decimal>(
                name: "PricePerKg",
                table: "ScrapListings",
                type: "decimal(18,4)",
                nullable: false,
                oldClrType: typeof(double),
                oldType: "float");
        }
    }
}
