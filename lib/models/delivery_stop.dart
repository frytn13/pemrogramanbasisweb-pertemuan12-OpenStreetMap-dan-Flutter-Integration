import 'package:latlong2/latlong.dart';

/// Model untuk merepresentasikan satu tujuan pengiriman.
class DeliveryStop {
  /// Nomor tujuan berdasarkan urutan input.
  final int number;

  /// Koordinat geografis titik tujuan.
  final LatLng point;

  /// Nama penerima paket.
  final String recipientName;

  /// Deskripsi paket yang akan dikirim.
  final String packageDescription;

  /// Status penyelesaian pengiriman.
  final bool isDelivered;

  const DeliveryStop({
    required this.number,
    required this.point,
    this.recipientName = '',
    this.packageDescription = '',
    this.isDelivered = false,
  });

  /// Label tujuan berdasarkan nomor input.
  String get label => 'Tujuan $number';

  /// Label status pengiriman.
  String get statusLabel => isDelivered ? 'Terkirim' : 'Belum terkirim';

  /// Membuat salinan objek dengan perubahan tertentu.
  DeliveryStop copyWith({
    int? number,
    LatLng? point,
    String? recipientName,
    String? packageDescription,
    bool? isDelivered,
  }) {
    return DeliveryStop(
      number: number ?? this.number,
      point: point ?? this.point,
      recipientName: recipientName ?? this.recipientName,
      packageDescription: packageDescription ?? this.packageDescription,
      isDelivered: isDelivered ?? this.isDelivered,
    );
  }

  /// Mengubah objek menjadi data JSON.
  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'recipientName': recipientName,
      'packageDescription': packageDescription,
      'isDelivered': isDelivered,
    };
  }

  /// Membentuk kembali objek dari data JSON.
  factory DeliveryStop.fromJson(Map<String, dynamic> json) {
    return DeliveryStop(
      number: (json['number'] as num).toInt(),
      point: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      recipientName: json['recipientName'] as String,
      packageDescription: json['packageDescription'] as String,
      isDelivered: json['isDelivered'] as bool,
    );
  }
}
