import 'package:geolocator/geolocator.dart';

/// Service untuk menangani GPS dan izin lokasi pengguna.
class LocationService {
  /// Mengambil posisi GPS pengguna saat ini.
  Future<Position> determineCurrentPosition() async {
    // Memeriksa apakah layanan lokasi perangkat aktif.
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    // Menghentikan proses apabila GPS tidak aktif.
    if (!serviceEnabled) {
      throw Exception('GPS belum aktif. Aktifkan Location pada perangkat.');
    }

    // Memeriksa status izin lokasi aplikasi.
    LocationPermission permission = await Geolocator.checkPermission();

    // Meminta izin apabila pengguna belum memberikan akses lokasi.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Menghentikan proses apabila pengguna menolak izin lokasi.
    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak. Aplikasi memerlukan akses GPS.');
    }

    // Menangani izin lokasi yang ditolak secara permanen.
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. '
        'Aktifkan izin melalui Settings aplikasi.',
      );
    }

    // Konfigurasi pengambilan lokasi dengan akurasi tinggi.
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    );

    // Mengambil dan mengembalikan posisi GPS terbaru.
    return Geolocator.getCurrentPosition(locationSettings: settings);
  }
}
