import '../models/route_models.dart';

/// Service untuk menentukan urutan kunjungan optimal
/// menggunakan algoritma Dijkstra pada state graph.
class DijkstraService {
  /// Mengoptimalkan urutan kunjungan seluruh tujuan
  /// berdasarkan matriks waktu tempuh dari OSRM.
  DijkstraResult optimizeVisitOrder({
    required List<List<double?>> durations,
    required int destinationCount,
  }) {
    // Validasi batas jumlah tujuan.
    if (destinationCount < 1 || destinationCount > 8) {
      throw Exception('Jumlah tujuan harus berada antara 1 dan 8.');
    }

    // Ukuran matriks mencakup titik awal dan seluruh tujuan.
    final int expectedSize = destinationCount + 1;

    // Memastikan matriks memiliki ukuran yang sesuai.
    if (durations.length != expectedSize ||
        durations.any((row) => row.length != expectedSize)) {
      throw Exception(
        'Ukuran matriks durasi tidak sesuai dengan jumlah titik.',
      );
    }

    // Memastikan seluruh bobot yang tersedia valid
    // dan tidak bernilai negatif.
    for (final row in durations) {
      for (final duration in row) {
        if (duration != null && (!duration.isFinite || duration < 0)) {
          throw Exception('Matriks mengandung nilai durasi yang tidak valid.');
        }
      }
    }

    // Bitmask penuh menunjukkan semua tujuan telah dikunjungi.
    final int fullMask = (1 << destinationCount) - 1;

    // State awal berada pada titik GPS pengguna.
    // Belum ada tujuan yang dikunjungi.
    const _RouteState startState = _RouteState(mask: 0, current: 0);

    // Menyimpan biaya minimum setiap state.
    final Map<_RouteState, double> bestCost = {startState: 0};

    // Menyimpan state sebelumnya untuk rekonstruksi rute.
    final Map<_RouteState, _RouteState?> parent = {startState: null};

    // Priority queue sederhana untuk jumlah tujuan terbatas.
    final List<_QueueItem> queue = [
      const _QueueItem(state: startState, cost: 0),
    ];

    // Menyimpan state terminal yang optimal.
    _RouteState? finalState;

    // Menjalankan algoritma selama queue belum kosong.
    while (queue.isNotEmpty) {
      // Mengurutkan queue berdasarkan biaya terkecil.
      queue.sort((a, b) => a.cost.compareTo(b.cost));

      // Mengambil state dengan biaya terkecil.
      final _QueueItem item = queue.removeAt(0);

      // Mengambil biaya minimum yang tercatat.
      final double knownCost = bestCost[item.state] ?? double.infinity;

      // Mengabaikan queue item yang sudah tidak optimal.
      if (item.cost > knownCost) {
        continue;
      }

      // Menghentikan pencarian jika seluruh tujuan
      // telah dikunjungi dengan biaya minimum.
      if (item.state.mask == fullMask) {
        finalState = item.state;
        break;
      }

      // Mengevaluasi setiap tujuan yang tersedia.
      for (int next = 1; next <= destinationCount; next++) {
        // Membentuk bit untuk tujuan berikutnya.
        final int bit = 1 << (next - 1);

        // Memeriksa apakah tujuan sudah dikunjungi.
        final bool alreadyVisited = (item.state.mask & bit) != 0;

        // Melewati tujuan yang sudah dikunjungi.
        if (alreadyVisited) {
          continue;
        }

        // Mengambil waktu tempuh menuju tujuan berikutnya.
        final double? edgeCost = durations[item.state.current][next];

        // Nilai null berarti jalur tidak tersedia.
        if (edgeCost == null) {
          continue;
        }

        // Membentuk state baru setelah mengunjungi tujuan.
        final _RouteState nextState = _RouteState(
          mask: item.state.mask | bit,
          current: next,
        );

        // Menghitung total biaya perjalanan.
        final double candidateCost = item.cost + edgeCost;

        // Mengambil biaya state sebelumnya.
        final double oldCost = bestCost[nextState] ?? double.infinity;

        // Relaxation:
        // Memperbarui state apabila ditemukan biaya lebih kecil.
        if (candidateCost < oldCost) {
          // Menyimpan biaya minimum terbaru.
          bestCost[nextState] = candidateCost;

          // Menyimpan state sebelumnya.
          parent[nextState] = item.state;

          // Memasukkan state baru ke priority queue.
          queue.add(_QueueItem(state: nextState, cost: candidateCost));
        }
      }
    }

    // Menangani kondisi ketika tidak ditemukan rute lengkap.
    if (finalState == null) {
      throw Exception('Tidak ditemukan rute yang dapat mencapai semua tujuan.');
    }

    // Menyimpan urutan tujuan dari belakang ke depan.
    final List<int> reversedOrder = [];

    // Memulai rekonstruksi dari state terminal.
    _RouteState? cursor = finalState;

    // Menelusuri seluruh parent sampai state awal.
    while (cursor != null) {
      // Indeks 0 adalah titik awal, bukan tujuan.
      if (cursor.current != 0) {
        reversedOrder.add(cursor.current);
      }

      // Berpindah ke state sebelumnya.
      cursor = parent[cursor];
    }

    // Membalik urutan agar dimulai dari titik awal perjalanan.
    final List<int> order = reversedOrder.reversed.toList();

    // Mengembalikan hasil optimasi Dijkstra.
    return DijkstraResult(
      order: order,
      totalCostSeconds: bestCost[finalState]!,
    );
  }
}

/// Representasi state pada algoritma Dijkstra.
class _RouteState {
  /// Bitmask tujuan yang sudah dikunjungi.
  final int mask;

  /// Indeks posisi kendaraan saat ini.
  final int current;

  const _RouteState({required this.mask, required this.current});

  /// Membandingkan state berdasarkan mask dan posisi.
  @override
  bool operator ==(Object other) {
    return other is _RouteState &&
        other.mask == mask &&
        other.current == current;
  }

  /// Menghasilkan hash agar state dapat digunakan
  /// sebagai key pada Map.
  @override
  int get hashCode => Object.hash(mask, current);
}

/// Representasi item pada priority queue.
class _QueueItem {
  /// State yang akan diproses.
  final _RouteState state;

  /// Total biaya menuju state tersebut.
  final double cost;

  const _QueueItem({required this.state, required this.cost});
}
