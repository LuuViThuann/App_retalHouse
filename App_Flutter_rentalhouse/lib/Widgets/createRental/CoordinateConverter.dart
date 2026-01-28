import 'dart:math';

/// Chuyển đổi tọa độ VN2000 ↔ WGS84 (Sai số: ~10m)
/// Công thức từ Bộ Tài nguyên & Môi trường Việt Nam
class CoordinateConverter {
  // Tham số WGS84
  static const double a = 6378137.0;
  static const double b = 6356752.314245;
  static const double e2 = 0.00669438;
  static const double ep2 = 0.00673949;

  // Tham số VN2000 (3 vùng)
  static const Map<String, Map<String, double>> vn2000Params = {
    'zone1': {
      // Vùng 1: 102°E - 108°E (Tây Nguyên, Tây Nam bộ)
      'lon0': 102.0,
      'falseEasting': 500000.0,
      'falseNorthing': 0.0,
      'scale': 0.9996,
    },
    'zone2': {
      // Vùng 2: 108°E - 114°E (Trung bộ, Đông Nam bộ) - SỬ DỤNG CHO CẦN THƠ
      'lon0': 108.0,
      'falseEasting': 500000.0,
      'falseNorthing': 0.0,
      'scale': 0.9996,
    },
    'zone3': {
      // Vùng 3: 114°E - 120°E (Bắc bộ, Đông bắc bộ)
      'lon0': 114.0,
      'falseEasting': 500000.0,
      'falseNorthing': 0.0,
      'scale': 0.9996,
    },
  };

  /// Xác định vùng VN2000 dựa trên kinh độ
  static String getVN2000Zone(double longitude) {
    if (longitude >= 102 && longitude < 108) return 'zone1';
    if (longitude >= 108 && longitude < 114) return 'zone2';
    return 'zone3';
  }

  /// WGS84 → VN2000
  static Map<String, double> wgs84ToVN2000(double latitude, double longitude) {
    final zone = getVN2000Zone(longitude);
    final params = vn2000Params[zone]!;
    final lon0 = params['lon0']!;
    final k0 = params['scale']!;
    final x0 = params['falseEasting']!;
    final y0 = params['falseNorthing']!;

    // Chuyển từ độ sang radian
    final lat = latitude * pi / 180;
    final lon = longitude * pi / 180;
    final lon0Rad = lon0 * pi / 180;

    // Tính N, E
    final cosPhi = cos(lat);
    final cosLon = cos(lon - lon0Rad);
    final sinLon = sin(lon - lon0Rad);
    final tanLon = tan(lon - lon0Rad);
    final tanPhi = tan(lat);

    final W = sqrt(1 - e2 * pow(sin(lat), 2));
    final N = a / W;

    final T = pow(tanPhi, 2);
    final C = ep2 * pow(cosPhi, 2);
    final A = (lon - lon0Rad) * cosPhi;

    final M = a *
        ((1 -
            e2 / 4 -
            3 * pow(e2, 2) / 64 -
            5 * pow(e2, 3) / 256) *
            lat -
            (3 * e2 / 8 +
                3 * pow(e2, 2) / 32 -
                45 * pow(e2, 3) / 1024) *
                sin(2 * lat) +
            (15 * pow(e2, 2) / 256 -
                45 * pow(e2, 3) / 1024) *
                sin(4 * lat) -
            (35 * pow(e2, 3) / 3072) * sin(6 * lat));

    final easting = k0 *
        N *
        (A +
            A * pow(A, 2) / 6 * (1 - T + C) +
            A * pow(A, 5) / 120 * (5 - 18 * T + pow(T, 2) + 72 * C - 58 * ep2)) +
        x0;

    final northing = k0 *
        (M +
            N *
                tanPhi *
                (pow(A, 2) / 2 +
                    pow(A, 4) / 24 * (5 - T + 9 * C + 4 * pow(C, 2)) +
                    pow(A, 6) /
                        720 *
                        (61 - 58 * T + pow(T, 2) + 600 * C - 330 * ep2))) +
        y0;

    return {
      'easting': easting,
      'northing': northing,
      'zone': double.parse(zone.replaceAll('zone', '')),
    };
  }

  /// VN2000 → WGS84
  static Map<String, double> vn2000ToWGS84(
      double easting,
      double northing,
      String zone, // 'zone1', 'zone2', 'zone3'
      ) {
    final params = vn2000Params[zone]!;
    final lon0 = params['lon0']!;
    final k0 = params['scale']!;
    final x0 = params['falseEasting']!;
    final y0 = params['falseNorthing']!;

    // Loại bỏ false easting/northing
    var x = easting - x0;
    var y = northing - y0;

    // Tính M
    final M = y / k0;
    final mu = M / (a * (1 - e2 / 4 - 3 * pow(e2, 2) / 64 - 5 * pow(e2, 3) / 256));

    final e1 =
        (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2));

    final phi1 = mu +
        (3 * e1 / 2 - 27 * pow(e1, 3) / 32) * sin(2 * mu) +
        (21 * pow(e1, 2) / 16 - 55 * pow(e1, 4) / 32) * sin(4 * mu);

    final cosPhi1 = cos(phi1);
    final sinPhi1 = sin(phi1);
    final tanPhi1 = tan(phi1);

    final W1 = sqrt(1 - e2 * pow(sinPhi1, 2));
    final N1 = a / W1;
    final T1 = pow(tanPhi1, 2);
    final C1 = ep2 * pow(cosPhi1, 2);
    final R1 = a * (1 - e2) / pow(W1, 3);

    final D = x / (N1 * k0);

    final latitude = phi1 -
        (N1 * tanPhi1 / R1) *
            (pow(D, 2) / 2 -
                pow(D, 4) / 24 * (5 + 3 * T1 + 10 * C1 - 4 * pow(C1, 2) - 9 * ep2) +
                pow(D, 6) /
                    720 *
                    (61 + 90 * T1 + 28 * pow(T1, 2) + 45 * C1 - 252 * ep2 - 3 * pow(C1, 2)));

    final longitude = (lon0 +
        (D -
            pow(D, 3) / 6 * (1 + 2 * T1 + C1) +
            pow(D, 5) / 120 * (5 - 2 * C1 + 28 * T1 - 3 * pow(C1, 2) + 8 * ep2 + 24 * pow(T1, 2))) /
            cosPhi1) *
        180 /
        pi;

    return {
      'latitude': latitude * 180 / pi,
      'longitude': longitude,
    };
  }

  /// Kiểm tra xem tọa độ có hợp lệ không
  static bool isValidWGS84(double latitude, double longitude) {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  /// Kiểm tra xem tọa độ có nằm trong Việt Nam không (WGS84)
  static bool isInVietnam(double latitude, double longitude) {
    // Giới hạn tương đối của Việt Nam
    return latitude >= 8.0 &&
        latitude <= 23.5 &&
        longitude >= 102.0 &&
        longitude <= 109.5;
  }

  /// Tính khoảng cách giữa 2 điểm (WGS84)==============================================================
  static double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const R = 6371000; // Bán kính Trái Đất (mét)
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return R * c; // Khoảng cách tính bằng mét
  }
}