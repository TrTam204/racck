namespace ScrapApi.Utils
{
    public static class GeoUtils
    {
        // Tính khoảng cách Haversine (km)
        public static double Haversine(double lat1, double lon1, double lat2, double lon2)
        {
            const double R = 6371.0; // km

            double dLat = (lat2 - lat1) * Math.PI / 180.0;
            double dLon = (lon2 - lon1) * Math.PI / 180.0;

            double a =
                Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(lat1 * Math.PI / 180.0) *
                Math.Cos(lat2 * Math.PI / 180.0) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

            double c = 2 * Math.Atan2(
                Math.Sqrt(a),
                Math.Sqrt(1 - a)
            );

            return R * c;
        }
    }
}
