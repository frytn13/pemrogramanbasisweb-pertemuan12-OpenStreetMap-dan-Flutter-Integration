import 'package:latlong2/latlong.dart';

/// Model hasil matriks dari OSRM Table Service.
class OsrmMatrix {
  /// Matriks waktu tempuh antar titik dalam satuan detik.
  final List<List<double?>> durations;

  /// Matriks jarak tempuh antar titik dalam satuan meter.
  final List<List<double?>> distances;

  const OsrmMatrix({required this.durations, required this.distances});
}

/// Model hasil rute dari OSRM Route Service.
class OsrmRoute {
  /// Koordinat geometri jalan untuk menggambar polyline.
  final List<LatLng> geometry;

  /// Total jarak perjalanan dalam satuan meter.
  final double distanceMeters;

  /// Total estimasi waktu perjalanan dalam satuan detik.
  final double durationSeconds;

  const OsrmRoute({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Model hasil optimasi algoritma Dijkstra pada state graph.
class DijkstraResult {
  /// Urutan indeks tujuan berdasarkan hasil optimasi.
  /// Indeks 0 merupakan posisi awal pengguna.
  final List<int> order;

  /// Total biaya minimum berdasarkan matriks durasi.
  final double totalCostSeconds;

  const DijkstraResult({required this.order, required this.totalCostSeconds});
}
