import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_models.dart';

/// Service untuk mengambil matriks waktu tempuh
/// dan geometri rute melalui OSRM API.
class OsrmService {
  /// Base URL public demo server OSRM.
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// HTTP client untuk mengirim request ke OSRM.
  final http.Client _client = http.Client();

  /// Identitas aplikasi ketika mengakses OSRM API.
  static const Map<String, String> _headers = {
    'User-Agent': 'UKMC-SmartDelivery-Practicum/1.0',
    'Accept': 'application/json',
  };

  /// Batas waktu maksimal untuk setiap request.
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Mengambil matriks durasi dan jarak antar titik
  /// melalui OSRM Table Service.
  Future<OsrmMatrix> fetchMatrix(List<LatLng> points) async {
    // Minimal terdapat satu titik awal dan satu tujuan.
    if (points.length < 2) {
      throw Exception('Minimal diperlukan dua titik untuk membuat matriks.');
    }

    // Mengubah koordinat ke format longitude,latitude.
    final String coordinates = _formatCoordinates(points);

    // Membentuk URL OSRM Table Service.
    final Uri uri = Uri.parse(
      '$_baseUrl/table/v1/driving/$coordinates'
      '?annotations=duration,distance',
    );

    // Mengirim request HTTP dengan batas waktu.
    final http.Response response = await _client
        .get(uri, headers: _headers)
        .timeout(_requestTimeout);

    // Memeriksa status HTTP.
    if (response.statusCode != 200) {
      throw Exception('OSRM matrix gagal. HTTP ${response.statusCode}.');
    }

    // Mengubah response JSON menjadi Map.
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    // Memeriksa status response OSRM.
    if (data['code'] != 'Ok') {
      throw Exception(
        'OSRM matrix error: '
        '${data['message'] ?? data['code']}.',
      );
    }

    // Mengubah matriks durasi menjadi List<List<double?>>.
    final List<List<double?>> durations = _parseMatrix(data['durations']);

    // Mengubah matriks jarak menjadi List<List<double?>>.
    final List<List<double?>> distances = _parseMatrix(data['distances']);

    // Mengembalikan hasil matriks OSRM.
    return OsrmMatrix(durations: durations, distances: distances);
  }

  /// Mengambil geometri rute berdasarkan urutan tujuan
  /// yang telah dioptimalkan oleh algoritma Dijkstra.
  Future<OsrmRoute> fetchRoute(List<LatLng> orderedPoints) async {
    // Minimal terdapat satu titik awal dan satu tujuan.
    if (orderedPoints.length < 2) {
      throw Exception('Minimal diperlukan dua titik untuk membuat rute.');
    }

    // Mengubah koordinat sesuai format OSRM.
    final String coordinates = _formatCoordinates(orderedPoints);

    // Membentuk URL OSRM Route Service.
    final Uri uri = Uri.parse(
      '$_baseUrl/route/v1/driving/$coordinates'
      '?overview=full&geometries=geojson&steps=false',
    );

    // Mengirim request HTTP dengan batas waktu.
    final http.Response response = await _client
        .get(uri, headers: _headers)
        .timeout(_requestTimeout);

    // Memeriksa status HTTP.
    if (response.statusCode != 200) {
      throw Exception('OSRM route gagal. HTTP ${response.statusCode}.');
    }

    // Mengubah response JSON menjadi Map.
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    // Memastikan OSRM berhasil menemukan rute.
    if (data['code'] != 'Ok') {
      throw Exception(
        'OSRM route error: '
        '${data['message'] ?? data['code']}.',
      );
    }

    // Mengambil daftar rute dari response.
    final List<dynamic> routes = data['routes'] as List<dynamic>;

    // Memastikan terdapat minimal satu rute.
    if (routes.isEmpty) {
      throw Exception('OSRM tidak mengembalikan geometri rute.');
    }

    // Mengambil rute rekomendasi pertama.
    final Map<String, dynamic> route = routes.first as Map<String, dynamic>;

    // Mengambil geometri rute dalam format GeoJSON.
    final Map<String, dynamic> geometry =
        route['geometry'] as Map<String, dynamic>;

    // Mengambil daftar koordinat pembentuk rute.
    final List<dynamic> rawCoordinates =
        geometry['coordinates'] as List<dynamic>;

    // Mengubah koordinat GeoJSON menjadi objek LatLng.
    final List<LatLng> points = rawCoordinates.map((dynamic rawPair) {
      final List<dynamic> pair = rawPair as List<dynamic>;

      // GeoJSON menggunakan longitude terlebih dahulu.
      final double longitude = (pair[0] as num).toDouble();

      // Latitude berada pada indeks kedua.
      final double latitude = (pair[1] as num).toDouble();

      // LatLng menggunakan latitude terlebih dahulu.
      return LatLng(latitude, longitude);
    }).toList();

    // Memastikan geometri rute tersedia.
    if (points.length < 2) {
      throw Exception('Geometri rute dari OSRM tidak valid.');
    }

    // Mengembalikan geometri, jarak, dan durasi perjalanan.
    return OsrmRoute(
      geometry: points,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }

  /// Mengubah daftar LatLng menjadi format koordinat OSRM.
  String _formatCoordinates(List<LatLng> points) {
    return points
        .map((LatLng point) => '${point.longitude},${point.latitude}')
        .join(';');
  }

  /// Mengubah matriks JSON menjadi matriks double nullable.
  List<List<double?>> _parseMatrix(dynamic rawMatrix) {
    // Memastikan data matriks tersedia.
    if (rawMatrix is! List) {
      throw Exception('OSRM tidak mengembalikan data matriks yang valid.');
    }

    // Mengubah setiap baris matriks.
    return rawMatrix.map<List<double?>>((dynamic rawRow) {
      final List<dynamic> row = rawRow as List<dynamic>;

      // Mengubah setiap nilai pada baris matriks.
      return row.map<double?>((dynamic value) {
        // Null berarti tidak tersedia jalur antar titik.
        if (value == null) {
          return null;
        }

        // Mengubah nilai numerik menjadi double.
        return (value as num).toDouble();
      }).toList();
    }).toList();
  }

  /// Menutup HTTP client ketika service tidak digunakan.
  void dispose() {
    _client.close();
  }
}
