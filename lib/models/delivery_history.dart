import 'package:latlong2/latlong.dart';

import 'delivery_stop.dart';

/// Model riwayat pengiriman terakhir.
class DeliveryHistory {
  /// Waktu pembuatan rencana pengiriman.
  final DateTime createdAt;

  /// Waktu terakhir informasi pengiriman diperbarui.
  final DateTime updatedAt;

  /// Koordinat awal pengiriman.
  final LatLng startPoint;

  /// Daftar tujuan berdasarkan urutan optimal Dijkstra.
  final List<DeliveryStop> stops;

  /// Total jarak perjalanan dalam meter.
  final double totalDistanceMeters;

  /// Total estimasi waktu perjalanan dalam detik.
  final double totalDurationSeconds;

  DeliveryHistory({
    required this.createdAt,
    required this.updatedAt,
    required this.startPoint,
    required List<DeliveryStop> stops,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
  }) : stops = List<DeliveryStop>.unmodifiable(stops);

  /// Total paket yang terdapat dalam rencana pengiriman.
  int get totalPackages => stops.length;

  /// Total paket yang telah berhasil dikirim.
  int get completedPackages {
    return stops.where((stop) => stop.isDelivered).length;
  }

  /// Total paket yang belum dikirim.
  int get pendingPackages {
    return totalPackages - completedPackages;
  }

  /// Persentase penyelesaian pengiriman dari 0 sampai 1.
  double get progress {
    if (totalPackages == 0) {
      return 0.0;
    }

    return completedPackages / totalPackages;
  }

  /// Memeriksa apakah seluruh paket telah terkirim.
  bool get isCompleted {
    return totalPackages > 0 && completedPackages == totalPackages;
  }

  /// Membuat salinan riwayat dengan perubahan tertentu.
  DeliveryHistory copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    LatLng? startPoint,
    List<DeliveryStop>? stops,
    double? totalDistanceMeters,
    double? totalDurationSeconds,
  }) {
    return DeliveryHistory(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startPoint: startPoint ?? this.startPoint,
      stops: stops ?? this.stops,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
    );
  }

  /// Mengubah seluruh riwayat menjadi data JSON.
  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'startPoint': {
        'latitude': startPoint.latitude,
        'longitude': startPoint.longitude,
      },
      'stops': stops.map((stop) => stop.toJson()).toList(),
      'totalDistanceMeters': totalDistanceMeters,
      'totalDurationSeconds': totalDurationSeconds,
    };
  }

  /// Membentuk kembali riwayat dari data JSON.
  factory DeliveryHistory.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawStartPoint =
        json['startPoint'] as Map<String, dynamic>;

    final List<dynamic> rawStops = json['stops'] as List<dynamic>;

    return DeliveryHistory(
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      startPoint: LatLng(
        (rawStartPoint['latitude'] as num).toDouble(),
        (rawStartPoint['longitude'] as num).toDouble(),
      ),
      stops: rawStops.map((rawStop) {
        return DeliveryStop.fromJson(rawStop as Map<String, dynamic>);
      }).toList(),
      totalDistanceMeters: (json['totalDistanceMeters'] as num).toDouble(),
      totalDurationSeconds: (json['totalDurationSeconds'] as num).toDouble(),
    );
  }
}
