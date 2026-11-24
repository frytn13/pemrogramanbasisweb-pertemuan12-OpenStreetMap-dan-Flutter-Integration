import 'package:flutter_test/flutter_test.dart';

import 'package:smart_delivery_dijkstra/services/dijkstra_service.dart';

void main() {
  late DijkstraService service;

  setUp(() {
    service = DijkstraService();
  });

  group('Dijkstra State Graph', () {
    // ========================================================
    // TEST 1: SATU TUJUAN
    // ========================================================

    test('Menghitung rute dengan satu tujuan', () {
      final List<List<double?>> durations = [
        [0, 120],
        [120, 0],
      ];

      final result = service.optimizeVisitOrder(
        durations: durations,
        destinationCount: 1,
      );

      expect(result.order, [1]);
      expect(result.totalCostSeconds, 120.0);
    });

    // ========================================================
    // TEST 2: TIGA TUJUAN SESUAI CONTOH MODUL
    // ========================================================

    test('Menentukan urutan optimal untuk tiga tujuan', () {
      final List<List<double?>> durations = [
        [0, 480, 300, 720],
        [480, 0, 240, 360],
        [300, 240, 0, 180],
        [720, 360, 180, 0],
      ];

      final result = service.optimizeVisitOrder(
        durations: durations,
        destinationCount: 3,
      );

      // GPS -> T2 -> T3 -> T1.
      expect(result.order, [2, 3, 1]);

      // 300 + 180 + 360 = 840 detik.
      expect(result.totalCostSeconds, 840.0);
    });

    // ========================================================
    // TEST 3: EMPAT TUJUAN
    // ========================================================

    test('Menentukan urutan optimal untuk empat tujuan', () {
      final List<List<double?>> durations = [
        [0, 100, 100, 10, 100],
        [100, 0, 100, 100, 10],
        [100, 100, 0, 100, 100],
        [100, 10, 100, 0, 100],
        [100, 100, 10, 100, 0],
      ];

      final result = service.optimizeVisitOrder(
        durations: durations,
        destinationCount: 4,
      );

      // GPS -> T3 -> T1 -> T4 -> T2.
      expect(result.order, [3, 1, 4, 2]);
      expect(result.totalCostSeconds, 40.0);
    });

    // ========================================================
    // TEST 4: DELAPAN TUJUAN
    // ========================================================

    test('Mendukung batas maksimum delapan tujuan', () {
      const int destinationCount = 8;

      final List<List<double?>> durations = List.generate(
        destinationCount + 1,
        (from) => List<double?>.generate(destinationCount + 1, (to) {
          if (from == to) {
            return 0.0;
          }

          if (to == from + 1) {
            return 10.0;
          }

          return 100.0;
        }),
      );

      final result = service.optimizeVisitOrder(
        durations: durations,
        destinationCount: destinationCount,
      );

      expect(result.order, [1, 2, 3, 4, 5, 6, 7, 8]);

      expect(result.order.length, 8);
      expect(result.order.toSet().length, 8);
      expect(result.totalCostSeconds, 80.0);
    });

    // ========================================================
    // TEST 5: OPTIMASI GLOBAL
    // ========================================================

    test('Tidak hanya memilih tujuan terdekat', () {
      final List<List<double?>> durations = [
        [0, 10, 20],
        [10, 0, 100],
        [20, 20, 0],
      ];

      final result = service.optimizeVisitOrder(
        durations: durations,
        destinationCount: 2,
      );

      // GPS -> T1 -> T2 = 110 detik.
      // GPS -> T2 -> T1 = 40 detik.

      expect(result.order, [2, 1]);
      expect(result.totalCostSeconds, 40.0);
    });

    // ========================================================
    // TEST 6: JALUR NULL
    // ========================================================

    test('Melewati edge yang tidak dapat dilalui', () {
      final List<List<double?>> durations = [
        [0, null, 20],
        [null, 0, null],
        [20, 10, 0],
      ];

      final result = service.optimizeVisitOrder(
        durations: durations,
        destinationCount: 2,
      );

      expect(result.order, [2, 1]);
      expect(result.totalCostSeconds, 30.0);
    });

    // ========================================================
    // TEST 7: RUTE TIDAK TERSEDIA
    // ========================================================

    test('Menangani tujuan yang tidak dapat dijangkau', () {
      final List<List<double?>> durations = [
        [0, 10, null],
        [10, 0, null],
        [null, null, 0],
      ];

      expect(
        () => service.optimizeVisitOrder(
          durations: durations,
          destinationCount: 2,
        ),
        throwsException,
      );
    });

    // ========================================================
    // TEST 8: UKURAN MATRIKS TIDAK VALID
    // ========================================================

    test('Menolak ukuran matriks yang tidak sesuai', () {
      final List<List<double?>> durations = [
        [0, 10],
        [10, 0],
      ];

      expect(
        () => service.optimizeVisitOrder(
          durations: durations,
          destinationCount: 3,
        ),
        throwsException,
      );
    });

    // ========================================================
    // TEST 9: BOBOT NEGATIF
    // ========================================================

    test('Menolak bobot durasi negatif', () {
      final List<List<double?>> durations = [
        [0, -10],
        [10, 0],
      ];

      expect(
        () => service.optimizeVisitOrder(
          durations: durations,
          destinationCount: 1,
        ),
        throwsException,
      );
    });

    // ========================================================
    // TEST 10: BATAS JUMLAH TUJUAN
    // ========================================================

    test('Menolak jumlah tujuan di luar batas 1 sampai 8', () {
      expect(
        () => service.optimizeVisitOrder(
          durations: [
            [0],
          ],
          destinationCount: 0,
        ),
        throwsException,
      );

      expect(
        () => service.optimizeVisitOrder(durations: [], destinationCount: 9),
        throwsException,
      );
    });
  });
}
