import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_delivery_dijkstra/models/delivery_stop.dart';
import 'package:smart_delivery_dijkstra/models/delivery_history.dart';
import 'package:smart_delivery_dijkstra/services/local_storage_service.dart';

/// Membentuk data simulasi berdasarkan urutan optimal Dijkstra.
DeliveryHistory createSampleHistory() {
  return DeliveryHistory(
    createdAt: DateTime.utc(2026, 11, 24, 2, 30),
    updatedAt: DateTime.utc(2026, 11, 24, 2, 30),
    startPoint: const LatLng(-2.9761, 104.7754),
    stops: const [
      DeliveryStop(
        number: 2,
        point: LatLng(-2.9825, 104.7801),
        recipientName: 'Andi',
        packageDescription: 'Dokumen kantor',
      ),
      DeliveryStop(
        number: 3,
        point: LatLng(-2.9902, 104.7905),
        recipientName: 'Budi',
        packageDescription: 'Paket elektronik',
      ),
      DeliveryStop(
        number: 1,
        point: LatLng(-2.9800, 104.7850),
        recipientName: 'Siti',
        packageDescription: 'Pakaian',
      ),
    ],
    totalDistanceMeters: 5420.0,
    totalDurationSeconds: 840.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // DELIVERY STOP MODEL
  // ==========================================================

  group('DeliveryStop Model', () {
    test('Menyimpan informasi paket dengan benar', () {
      const DeliveryStop stop = DeliveryStop(
        number: 1,
        point: LatLng(-2.9800, 104.7850),
        recipientName: 'Andi',
        packageDescription: 'Dokumen kantor',
      );

      expect(stop.number, 1);
      expect(stop.recipientName, 'Andi');
      expect(stop.packageDescription, 'Dokumen kantor');
      expect(stop.point.latitude, -2.9800);
      expect(stop.point.longitude, 104.7850);
      expect(stop.isDelivered, isFalse);
      expect(stop.label, 'Tujuan 1');
      expect(stop.statusLabel, 'Belum terkirim');
    });

    test('Memperbarui status paket tanpa mengubah data asli', () {
      const DeliveryStop original = DeliveryStop(
        number: 2,
        point: LatLng(-2.9825, 104.7801),
        recipientName: 'Andi',
        packageDescription: 'Dokumen kantor',
      );

      final DeliveryStop updated = original.copyWith(isDelivered: true);

      expect(original.isDelivered, isFalse);
      expect(updated.isDelivered, isTrue);
      expect(updated.statusLabel, 'Terkirim');

      expect(updated.number, original.number);
      expect(updated.recipientName, original.recipientName);
      expect(updated.packageDescription, original.packageDescription);
      expect(updated.point.latitude, original.point.latitude);
      expect(updated.point.longitude, original.point.longitude);
    });

    test('Melakukan serialisasi dan deserialisasi DeliveryStop', () {
      const DeliveryStop original = DeliveryStop(
        number: 3,
        point: LatLng(-2.9902, 104.7905),
        recipientName: 'Budi',
        packageDescription: 'Paket elektronik',
        isDelivered: true,
      );

      final String encoded = jsonEncode(original.toJson());

      final DeliveryStop restored = DeliveryStop.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(restored.number, original.number);
      expect(restored.recipientName, original.recipientName);
      expect(restored.packageDescription, original.packageDescription);
      expect(restored.point.latitude, original.point.latitude);
      expect(restored.point.longitude, original.point.longitude);
      expect(restored.isDelivered, isTrue);
    });
  });

  // ==========================================================
  // DELIVERY HISTORY MODEL
  // ==========================================================

  group('DeliveryHistory Model', () {
    test('Mempertahankan urutan kunjungan optimal', () {
      final DeliveryHistory history = createSampleHistory();

      expect(history.stops.map((stop) => stop.number).toList(), [2, 3, 1]);

      expect(history.stops.map((stop) => stop.recipientName).toList(), [
        'Andi',
        'Budi',
        'Siti',
      ]);

      expect(history.totalDistanceMeters, 5420.0);
      expect(history.totalDurationSeconds, 840.0);
    });

    test('Menghitung progres awal pengiriman', () {
      final DeliveryHistory history = createSampleHistory();

      expect(history.totalPackages, 3);
      expect(history.completedPackages, 0);
      expect(history.pendingPackages, 3);
      expect(history.progress, 0.0);
      expect(history.isCompleted, isFalse);
    });

    test('Menghitung progres setelah satu paket terkirim', () {
      final DeliveryHistory original = createSampleHistory();

      final List<DeliveryStop> updatedStops = [
        original.stops.first.copyWith(isDelivered: true),
        ...original.stops.skip(1),
      ];

      final DeliveryHistory updated = original.copyWith(
        stops: updatedStops,
        updatedAt: DateTime.utc(2026, 11, 24, 2, 45),
      );

      expect(updated.totalPackages, 3);
      expect(updated.completedPackages, 1);
      expect(updated.pendingPackages, 2);
      expect(updated.progress, closeTo(1 / 3, 0.000001));
      expect(updated.isCompleted, isFalse);

      // Data riwayat sebelumnya tidak berubah.
      expect(original.completedPackages, 0);
    });

    test('Mendeteksi seluruh paket telah terkirim', () {
      final DeliveryHistory original = createSampleHistory();

      final DeliveryHistory completed = original.copyWith(
        stops: original.stops.map((stop) {
          return stop.copyWith(isDelivered: true);
        }).toList(),
      );

      expect(completed.totalPackages, 3);
      expect(completed.completedPackages, 3);
      expect(completed.pendingPackages, 0);
      expect(completed.progress, 1.0);
      expect(completed.isCompleted, isTrue);
    });

    test('Melakukan serialisasi riwayat secara lengkap', () {
      final DeliveryHistory original = createSampleHistory();

      final String encoded = jsonEncode(original.toJson());

      final DeliveryHistory restored = DeliveryHistory.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);

      expect(restored.startPoint.latitude, original.startPoint.latitude);

      expect(restored.startPoint.longitude, original.startPoint.longitude);

      expect(restored.totalDistanceMeters, original.totalDistanceMeters);

      expect(restored.totalDurationSeconds, original.totalDurationSeconds);

      expect(
        restored.stops.map((stop) => stop.toJson()).toList(),
        original.stops.map((stop) => stop.toJson()).toList(),
      );
    });

    test('Menangani riwayat tanpa paket', () {
      final DeliveryHistory original = createSampleHistory();

      final DeliveryHistory empty = original.copyWith(stops: []);

      expect(empty.totalPackages, 0);
      expect(empty.completedPackages, 0);
      expect(empty.pendingPackages, 0);
      expect(empty.progress, 0.0);
      expect(empty.isCompleted, isFalse);
    });
  });

  // ==========================================================
  // LOCAL STORAGE SERVICE
  // ==========================================================

  group('LocalStorageService', () {
    late LocalStorageService service;

    setUp(() {
      // Menggunakan penyimpanan simulasi yang kosong
      // sebelum setiap pengujian.
      SharedPreferences.setMockInitialValues({});

      service = LocalStorageService();
    });

    test('Mengembalikan null jika belum ada riwayat', () async {
      final DeliveryHistory? history = await service.loadHistory();

      expect(history, isNull);
    });

    test('Menyimpan dan membaca riwayat pengiriman', () async {
      final DeliveryHistory original = createSampleHistory();

      await service.saveHistory(original);

      final DeliveryHistory? restored = await service.loadHistory();

      expect(restored, isNotNull);

      expect(restored!.toJson(), original.toJson());
    });

    test('Menyimpan perubahan status paket terkirim', () async {
      final DeliveryHistory original = createSampleHistory();

      await service.saveHistory(original);

      final DeliveryHistory updated = original.copyWith(
        stops: [
          original.stops.first.copyWith(isDelivered: true),
          ...original.stops.skip(1),
        ],
        updatedAt: DateTime.utc(2026, 11, 24, 2, 45),
      );

      await service.saveHistory(updated);

      final DeliveryHistory? restored = await service.loadHistory();

      expect(restored, isNotNull);
      expect(restored!.completedPackages, 1);
      expect(restored.pendingPackages, 2);
      expect(restored.stops.first.isDelivered, isTrue);
      expect(restored.updatedAt, updated.updatedAt);
    });

    test('Menggantikan riwayat lama dengan riwayat terbaru', () async {
      final DeliveryHistory first = createSampleHistory();

      await service.saveHistory(first);

      final DeliveryHistory second = first.copyWith(
        createdAt: DateTime.utc(2026, 11, 24, 3, 30),
        updatedAt: DateTime.utc(2026, 11, 24, 3, 30),
        totalDistanceMeters: 8200.0,
        totalDurationSeconds: 1200.0,
      );

      await service.saveHistory(second);

      final DeliveryHistory? restored = await service.loadHistory();

      expect(restored, isNotNull);
      expect(restored!.createdAt, second.createdAt);
      expect(restored.totalDistanceMeters, 8200.0);
      expect(restored.totalDurationSeconds, 1200.0);
    });

    test('Membaca riwayat melalui instance service baru', () async {
      final DeliveryHistory original = createSampleHistory();

      await service.saveHistory(original);

      final LocalStorageService newService = LocalStorageService();

      final DeliveryHistory? restored = await newService.loadHistory();

      expect(restored, isNotNull);
      expect(restored!.toJson(), original.toJson());
    });

    test('Menangani data riwayat JSON yang rusak', () async {
      SharedPreferences.setMockInitialValues({
        'smart_delivery_last_history': 'invalid-json',
      });

      await expectLater(service.loadHistory(), throwsA(isA<FormatException>()));
    });
  });
}
