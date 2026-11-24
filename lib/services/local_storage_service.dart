import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_history.dart';

/// Service untuk mengelola riwayat pengiriman
/// pada penyimpanan lokal perangkat.
class LocalStorageService {
  /// Key untuk menyimpan riwayat pengiriman terakhir.
  static const String _historyKey = 'smart_delivery_last_history';

  // ==========================================================
  // SAVE DELIVERY HISTORY
  // ==========================================================

  /// Menyimpan riwayat pengiriman terakhir.
  ///
  /// Riwayat sebelumnya akan diperbarui dengan data terbaru.
  Future<void> saveHistory(DeliveryHistory history) async {
    // Mendapatkan instance SharedPreferences.
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    // Mengubah objek riwayat menjadi JSON String.
    final String encodedHistory = jsonEncode(history.toJson());

    // Menyimpan JSON pada penyimpanan lokal.
    final bool saved = await preferences.setString(_historyKey, encodedHistory);

    // Menangani kegagalan penyimpanan.
    if (!saved) {
      throw Exception('Gagal menyimpan riwayat pengiriman.');
    }
  }

  // ==========================================================
  // LOAD DELIVERY HISTORY
  // ==========================================================

  /// Membaca riwayat pengiriman terakhir.
  ///
  /// Mengembalikan null apabila belum ada riwayat tersimpan.
  Future<DeliveryHistory?> loadHistory() async {
    // Mendapatkan instance SharedPreferences.
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    // Membaca JSON dari penyimpanan lokal.
    final String? encodedHistory = preferences.getString(_historyKey);

    // Belum terdapat riwayat pengiriman.
    if (encodedHistory == null || encodedHistory.isEmpty) {
      return null;
    }

    try {
      // Mengubah JSON String menjadi objek Dart.
      final dynamic decodedHistory = jsonDecode(encodedHistory);

      // Memastikan struktur data JSON valid.
      if (decodedHistory is! Map<String, dynamic>) {
        throw const FormatException('Format riwayat pengiriman tidak valid.');
      }

      // Membentuk kembali objek DeliveryHistory.
      return DeliveryHistory.fromJson(decodedHistory);
    } catch (_) {
      throw const FormatException(
        'Data riwayat pengiriman tidak dapat dibaca.',
      );
    }
  }
}
