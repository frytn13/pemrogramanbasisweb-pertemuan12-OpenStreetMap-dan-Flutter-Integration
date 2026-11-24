import 'package:flutter/material.dart';

import '../models/delivery_history.dart';
import '../models/delivery_stop.dart';
import '../services/local_storage_service.dart';

class DeliveryHistoryPage extends StatefulWidget {
  const DeliveryHistoryPage({super.key});

  @override
  State<DeliveryHistoryPage> createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _success = Color(0xFF15803D);
  static const Color _pending = Color(0xFFC2410C);
  static const Color _heading = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  final LocalStorageService _storageService = LocalStorageService();

  late Future<DeliveryHistory?> _historyFuture;

  @override
  void initState() {
    super.initState();

    _historyFuture = _storageService.loadHistory();
  }

  void _reloadHistory() {
    setState(() {
      _historyFuture = _storageService.loadHistory();
    });
  }

  String _formatDate(DateTime date) {
    final DateTime local = date.toLocal();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} · '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(double seconds) {
    final int minutes = (seconds / 60).ceil();

    if (minutes < 60) {
      return '$minutes menit';
    }

    final int hours = minutes ~/ 60;
    final int remaining = minutes % 60;

    return remaining == 0 ? '$hours jam' : '$hours jam $remaining menit';
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _heading,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSummary(DeliveryHistory history) {
    final Color statusColor = history.isCompleted ? _success : _primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  history.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.local_shipping_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history.isCompleted
                          ? 'Pengiriman selesai'
                          : 'Pengiriman belum selesai',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(history.createdAt),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMetric(
                  icon: Icons.straighten_rounded,
                  label: 'Total jarak',
                  value: _formatDistance(history.totalDistanceMeters),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetric(
                  icon: Icons.schedule_rounded,
                  label: 'Estimasi waktu',
                  value: _formatDuration(history.totalDurationSeconds),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetric(
                  icon: Icons.inventory_2_outlined,
                  label: 'Paket terkirim',
                  value:
                      '${history.completedPackages}/'
                      '${history.totalPackages}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progres pengiriman',
                  style: TextStyle(
                    color: _heading,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(history.progress * 100).round()}%',
                style: const TextStyle(
                  color: _success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: history.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(_success),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Terakhir diperbarui: '
            '${_formatDate(history.updatedAt)}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(DeliveryStop stop, int visitNumber) {
    final Color statusColor = stop.isDelivered ? _success : _pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: statusColor,
            child: Text(
              '$visitNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.recipientName,
                  style: const TextStyle(
                    color: _heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stop.packageDescription,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  'Tujuan awal ${stop.number} · '
                  '${stop.point.latitude.toStringAsFixed(4)}, '
                  '${stop.point.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      stop.isDelivered
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        stop.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(DeliveryHistory history) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummary(history),
        const SizedBox(height: 22),
        const Text(
          'Urutan kunjungan',
          style: TextStyle(
            color: _heading,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Berdasarkan hasil optimasi Dijkstra.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        for (int index = 0; index < history.stops.length; index++)
          _buildStopCard(history.stops[index], index + 1),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 64, color: _muted),
            SizedBox(height: 16),
            Text(
              'Belum ada riwayat pengiriman',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _heading,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Riwayat akan tersimpan secara otomatis '
              'setelah rute pengiriman berhasil dihitung.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Riwayat pengiriman tidak dapat dibaca.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reloadHistory,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Riwayat pengiriman',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<DeliveryHistory?>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final DeliveryHistory? history = snapshot.data;

            if (history == null) {
              return _buildEmptyState();
            }

            return _buildHistory(history);
          },
        ),
      ),
    );
  }
}
