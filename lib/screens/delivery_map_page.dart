import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/delivery_history.dart';
import '../models/delivery_stop.dart';
import '../models/route_models.dart';
import '../services/dijkstra_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';
import '../services/osrm_service.dart';
import 'delivery_history_page.dart';

class DeliveryMapPage extends StatefulWidget {
  const DeliveryMapPage({super.key});

  @override
  State<DeliveryMapPage> createState() => _DeliveryMapPageState();
}

class _DeliveryMapPageState extends State<DeliveryMapPage> {
  // ==========================================================
  // CONFIGURATION
  // ==========================================================

  static const Color _primary = Color(0xFF2563EB);
  static const Color _pending = Color(0xFFC2410C);
  static const Color _success = Color(0xFF15803D);
  static const Color _heading = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFDC2626);

  static const LatLng _fallbackCenter = LatLng(-2.9761, 104.7754);

  static const int _minimumDestinations = 3;
  static const int _maximumDestinations = 8;

  // ==========================================================
  // CONTROLLERS AND SERVICES
  // ==========================================================

  final MapController _mapController = MapController();

  final LocationService _locationService = LocationService();

  final OsrmService _osrmService = OsrmService();

  final DijkstraService _dijkstraService = DijkstraService();

  final LocalStorageService _storageService = LocalStorageService();

  // ==========================================================
  // APPLICATION STATE
  // ==========================================================

  LatLng? _userLocation;

  final List<DeliveryStop> _destinations = [];

  List<LatLng> _routeGeometry = [];

  DeliveryHistory? _activeHistory;

  int _targetDestinationCount = 3;

  bool _loadingLocation = false;
  bool _calculatingRoute = false;
  bool _savingDelivery = false;
  bool _addingDestination = false;
  bool _mapReady = false;
  bool _hasError = false;

  String _statusMessage = 'Mengambil lokasi GPS pengguna...';

  bool get _isBusy => _loadingLocation || _calculatingRoute || _savingDelivery;

  bool get _hasRoute => _activeHistory != null && _routeGeometry.isNotEmpty;

  int get _completedCount =>
      _destinations.where((stop) => stop.isDelivered).length;

  bool get _canEdit => !_isBusy && _completedCount == 0;

  bool get _canCalculate =>
      _canEdit &&
      _userLocation != null &&
      _destinations.length == _targetDestinationCount;

  List<DeliveryStop> get _visibleStops =>
      _activeHistory?.stops ?? _destinations;

  // ==========================================================
  // LIFECYCLE
  // ==========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _osrmService.dispose();
    _mapController.dispose();

    super.dispose();
  }

  // ==========================================================
  // GPS AND LOCATION
  // ==========================================================

  Future<void> _loadCurrentLocation() async {
    if (!_canEdit) {
      return;
    }

    setState(() {
      _loadingLocation = true;
      _hasError = false;

      _statusMessage = 'Mengambil lokasi GPS pengguna...';
    });

    try {
      final position = await _locationService.determineCurrentPosition();

      if (!mounted) {
        return;
      }

      final LatLng currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _userLocation = currentLocation;
        _loadingLocation = false;
        _hasError = false;

        // Rute sebelumnya tidak berlaku untuk posisi baru.
        _clearRouteResultOnly();

        _statusMessage = _destinationStatus();
      });

      _centerOnUser();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = _formatError(error);

      setState(() {
        _loadingLocation = false;
        _hasError = true;
        _statusMessage = message;
      });

      _showMessage(message, isError: true);
    }
  }

  void _centerOnUser() {
    if (!_mapReady || _userLocation == null) {
      return;
    }

    _mapController.move(_userLocation!, 15);
  }

  void _onMapReady() {
    _mapReady = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) {
        return;
      }

      if (_hasRoute) {
        _fitRoute();
      } else if (_userLocation != null) {
        _centerOnUser();
      }
    });
  }

  // ==========================================================
  // DESTINATION MANAGEMENT
  // ==========================================================

  String _destinationStatus() {
    if (_userLocation == null) {
      return 'Aktifkan GPS untuk menentukan titik awal.';
    }

    final int remaining = _targetDestinationCount - _destinations.length;

    if (remaining > 0) {
      return 'Tekan lama pada peta untuk menambahkan '
          '$remaining titik tujuan lagi.';
    }

    return 'Semua paket siap. Hitung rute pengiriman.';
  }

  Future<void> _addDestination(LatLng point) async {
    if (_isBusy || _addingDestination) {
      return;
    }

    if (_completedCount > 0) {
      _showMessage(
        'Pengiriman sedang berlangsung. '
        'Reset untuk membuat rencana baru.',
      );

      return;
    }

    if (_userLocation == null) {
      _showMessage('Lokasi GPS belum tersedia.', isError: true);

      return;
    }

    if (_destinations.length >= _targetDestinationCount) {
      _showMessage(
        'Jumlah tujuan sudah mencapai '
        '$_targetDestinationCount titik.',
      );

      return;
    }

    _addingDestination = true;

    DeliveryStop? newStop;

    try {
      newStop = await showDialog<DeliveryStop>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _DeliveryStopDialog(
            number: _destinations.length + 1,
            point: point,
          );
        },
      );
    } finally {
      _addingDestination = false;
    }

    if (!mounted ||
        newStop == null ||
        !_canEdit ||
        _destinations.length >= _targetDestinationCount) {
      return;
    }

    final DeliveryStop stop = newStop.copyWith(
      number: _destinations.length + 1,
    );

    setState(() {
      _destinations.add(stop);

      _clearRouteResultOnly();

      _hasError = false;
      _statusMessage = _destinationStatus();
    });

    _showMessage('Paket untuk ${stop.recipientName} ditambahkan.');
  }

  void _changeTargetCount(int newValue) {
    if (!_canEdit) {
      return;
    }

    final int safeValue = newValue
        .clamp(_minimumDestinations, _maximumDestinations)
        .toInt();

    if (safeValue == _targetDestinationCount) {
      return;
    }

    setState(() {
      _targetDestinationCount = safeValue;

      while (_destinations.length > safeValue) {
        _destinations.removeLast();
      }

      _renumberDestinations();
      _clearRouteResultOnly();

      _hasError = false;
      _statusMessage = _destinationStatus();
    });
  }

  void _removeDestination(int number) {
    if (!_canEdit) {
      return;
    }

    final int index = _destinations.indexWhere((stop) => stop.number == number);

    if (index == -1) {
      return;
    }

    setState(() {
      _destinations.removeAt(index);

      _renumberDestinations();
      _clearRouteResultOnly();

      _hasError = false;
      _statusMessage = _destinationStatus();
    });
  }

  void _renumberDestinations() {
    for (int index = 0; index < _destinations.length; index++) {
      _destinations[index] = _destinations[index].copyWith(number: index + 1);
    }
  }

  void _clearRouteResultOnly() {
    _routeGeometry = [];
    _activeHistory = null;
  }

  Future<void> _resetAll() async {
    if (_isBusy) {
      return;
    }

    if (_completedCount > 0) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Mulai pengiriman baru?'),
            content: const Text(
              'Rencana pengiriman aktif akan dihapus. '
              'Riwayat pengiriman terakhir tetap '
              'tersimpan pada perangkat.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Reset'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmed != true || _isBusy) {
        return;
      }
    }

    setState(() {
      _destinations.clear();

      _clearRouteResultOnly();

      _hasError = false;
      _statusMessage = _destinationStatus();
    });

    _centerOnUser();

    _showMessage('Rencana pengiriman berhasil direset.');
  }

  // ==========================================================
  // ROUTE OPTIMIZATION
  // ==========================================================

  Future<void> _calculateOptimizedRoute() async {
    if (!_canCalculate) {
      return;
    }

    final LatLng startPoint = _userLocation!;

    // Snapshot data agar input tetap konsisten
    // selama proses perhitungan.
    final List<DeliveryStop> stops = List<DeliveryStop>.of(_destinations);

    final List<LatLng> allPoints = [
      startPoint,
      ...stops.map((stop) => stop.point),
    ];

    setState(() {
      _calculatingRoute = true;
      _hasError = false;

      _clearRouteResultOnly();

      _statusMessage = 'Mengambil matriks waktu tempuh dari OSRM...';
    });

    try {
      // 1. Mengambil matriks durasi dan jarak.
      final OsrmMatrix matrix = await _osrmService.fetchMatrix(allPoints);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Menjalankan Dijkstra pada state graph...';
      });

      // 2. Mengoptimalkan urutan kunjungan.
      final DijkstraResult optimized = _dijkstraService.optimizeVisitOrder(
        durations: matrix.durations,
        destinationCount: stops.length,
      );

      // 3. Menyusun tujuan berdasarkan hasil Dijkstra.
      final List<DeliveryStop> orderedStops = optimized.order.map((pointIndex) {
        return stops[pointIndex - 1];
      }).toList();

      final List<LatLng> orderedPoints = [
        startPoint,
        ...orderedStops.map((stop) => stop.point),
      ];

      setState(() {
        _statusMessage = 'Mengambil geometri rute perjalanan...';
      });

      // 4. Mengambil geometri jalan dari OSRM.
      final OsrmRoute route = await _osrmService.fetchRoute(orderedPoints);

      if (!mounted) {
        return;
      }

      // 5. Membentuk riwayat pengiriman.
      final DateTime now = DateTime.now();

      final DeliveryHistory history = DeliveryHistory(
        createdAt: now,
        updatedAt: now,
        startPoint: startPoint,
        stops: orderedStops,
        totalDistanceMeters: route.distanceMeters,
        totalDurationSeconds: route.durationSeconds,
      );

      setState(() {
        _statusMessage = 'Menyimpan riwayat pengiriman...';
      });

      // 6. Menyimpan riwayat pada perangkat.
      await _storageService.saveHistory(history);

      if (!mounted) {
        return;
      }

      // 7. Menampilkan hasil optimasi.
      setState(() {
        _activeHistory = history;
        _routeGeometry = route.geometry;

        _calculatingRoute = false;
        _hasError = false;

        _statusMessage = 'Rute optimal siap. Mulai pengiriman paket.';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasRoute) {
          _fitRoute();
        }
      });

      _showMessage('Optimasi berhasil. Riwayat tersimpan.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = _formatError(error);

      setState(() {
        _calculatingRoute = false;
        _hasError = true;
        _statusMessage = message;
      });

      _showMessage(message, isError: true);
    }
  }

  void _fitRoute() {
    if (!_mapReady || _routeGeometry.isEmpty) {
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          ..._routeGeometry,
          ?_userLocation,
          ..._destinations.map((stop) => stop.point),
        ],
        padding: const EdgeInsets.fromLTRB(36, 36, 60, 36),
        maxZoom: 16,
      ),
    );
  }

  // ==========================================================
  // DELIVERY COMPLETION
  // ==========================================================

  Future<void> _markDelivered(int number) async {
    if (_isBusy || !_hasRoute) {
      return;
    }

    final DeliveryHistory? history = _activeHistory;

    if (history == null) {
      return;
    }

    final int destinationIndex = _destinations.indexWhere(
      (stop) => stop.number == number,
    );

    if (destinationIndex == -1) {
      return;
    }

    final DeliveryStop currentStop = _destinations[destinationIndex];

    if (currentStop.isDelivered) {
      return;
    }

    // Memperbarui status tanpa mengubah identitas paket.
    final DeliveryStop updatedStop = currentStop.copyWith(isDelivered: true);

    final List<DeliveryStop> updatedStops = history.stops.map((stop) {
      if (stop.number == number) {
        return updatedStop;
      }

      return stop;
    }).toList();

    final DeliveryHistory updatedHistory = history.copyWith(
      updatedAt: DateTime.now(),
      stops: updatedStops,
    );

    setState(() {
      _savingDelivery = true;
      _hasError = false;

      _statusMessage = 'Menyimpan status pengiriman paket...';
    });

    try {
      // Simpan terlebih dahulu agar UI dan riwayat
      // tidak memiliki status yang berbeda.
      await _storageService.saveHistory(updatedHistory);

      if (!mounted) {
        return;
      }

      setState(() {
        _destinations[destinationIndex] = updatedStop;

        _activeHistory = updatedHistory;

        _savingDelivery = false;
        _hasError = false;

        _statusMessage = updatedHistory.isCompleted
            ? 'Seluruh paket berhasil dikirim.'
            : '${updatedHistory.completedPackages} dari '
                  '${updatedHistory.totalPackages} '
                  'paket telah terkirim.';
      });

      _showMessage(
        updatedHistory.isCompleted
            ? 'Seluruh pengiriman selesai.'
            : 'Paket untuk ${updatedStop.recipientName} '
                  'telah terkirim.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = _formatError(error);

      setState(() {
        _savingDelivery = false;
        _hasError = true;
        _statusMessage = message;
      });

      _showMessage(message, isError: true);
    }
  }

  // ==========================================================
  // HISTORY AND ATTRIBUTION
  // ==========================================================

  void _openHistory() {
    if (_isBusy) {
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const DeliveryHistoryPage(),
      ),
    );
  }

  Future<void> _openAttribution() async {
    final Uri uri = Uri.parse('https://www.openstreetmap.org/copyright');

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showMessage(
          'Halaman OpenStreetMap tidak dapat dibuka.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Halaman OpenStreetMap tidak dapat dibuka.',
          isError: true,
        );
      }
    }
  }

  // ==========================================================
  // UTILITIES
  // ==========================================================

  String _formatError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
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

  int _visitNumber(DeliveryStop stop) {
    final DeliveryHistory? history = _activeHistory;

    if (history == null) {
      return stop.number;
    }

    final int index = history.stops.indexWhere(
      (item) => item.number == stop.number,
    );

    return index == -1 ? stop.number : index + 1;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _danger : _heading,
        ),
      );
  }

  // ==========================================================
  // MAP MARKERS
  // ==========================================================

  List<Marker> _buildMarkers() {
    final LatLng? userLocation = _userLocation;

    return [
      // Marker titik awal GPS.
      if (userLocation != null)
        Marker(
          point: userLocation,
          width: 52,
          height: 52,
          child: Semantics(
            label: 'Lokasi awal pengguna',
            child: Container(
              decoration: BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
        ),

      // Marker tujuan berdasarkan urutan hasil Dijkstra.
      ..._destinations.map((stop) {
        final int visitNumber = _visitNumber(stop);

        final Color markerColor = stop.isDelivered ? _success : _pending;

        return Marker(
          point: stop.point,
          width: 46,
          height: 46,
          child: Semantics(
            label:
                'Tujuan $visitNumber, '
                '${stop.recipientName}, '
                '${stop.statusLabel}',
            child: Container(
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$visitNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ];
  }

  // ==========================================================
  // MAP INTERFACE
  // ==========================================================

  Widget _buildMapControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(14),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: _primary,
        disabledColor: _muted,
        constraints: const BoxConstraints.tightFor(width: 46, height: 46),
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? _fallbackCenter,
              initialZoom: 13.5,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: _onMapReady,
              onLongPress: (_, point) {
                _addDestination(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'id.ac.ukmc.smartdelivery',
                maxNativeZoom: 19,
              ),

              if (_routeGeometry.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeGeometry,
                      strokeWidth: 6,
                      color: _primary,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
        ),

        // Kontrol kamera.
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _buildMapControl(
                icon: Icons.my_location_rounded,
                tooltip: 'Kembali ke lokasi awal',
                onPressed: _userLocation == null ? null : _centerOnUser,
              ),

              if (_hasRoute) ...[
                const SizedBox(height: 8),
                _buildMapControl(
                  icon: Icons.fit_screen_rounded,
                  tooltip: 'Tampilkan seluruh rute',
                  onPressed: _fitRoute,
                ),
              ],
            ],
          ),
        ),

        // Legenda marker.
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendItem(color: _primary, label: 'Lokasi awal'),
                SizedBox(height: 5),
                _LegendItem(color: _pending, label: 'Belum terkirim'),
                SizedBox(height: 5),
                _LegendItem(color: _success, label: 'Terkirim'),
              ],
            ),
          ),
        ),

        // Attribution wajib OpenStreetMap.
        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _openAttribution,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    color: _heading,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // DESTINATION COUNTER
  // ==========================================================

  Widget _buildDestinationCounter() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Kurangi jumlah tujuan',
            icon: const Icon(Icons.remove_rounded, size: 19),
            color: _primary,
            onPressed:
                !_canEdit || _targetDestinationCount <= _minimumDestinations
                ? null
                : () {
                    _changeTargetCount(_targetDestinationCount - 1);
                  },
          ),

          SizedBox(
            width: 22,
            child: Text(
              '$_targetDestinationCount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _heading,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Tambah jumlah tujuan',
            icon: const Icon(Icons.add_rounded, size: 19),
            color: _primary,
            onPressed:
                !_canEdit || _targetDestinationCount >= _maximumDestinations
                ? null
                : () {
                    _changeTargetCount(_targetDestinationCount + 1);
                  },
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS PANEL
  // ==========================================================

  Widget _buildStatusPanel() {
    final Color statusColor = _hasError
        ? _danger
        : _hasRoute && !_isBusy
        ? _success
        : _primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isBusy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            )
          else
            Icon(
              _hasError
                  ? Icons.error_outline_rounded
                  : _hasRoute
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: statusColor,
              size: 19,
            ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ROUTE SUMMARY
  // ==========================================================

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _primary, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: _heading,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
      ],
    );
  }

  Widget _buildRouteSummary(DeliveryHistory history) {
    final String order = [
      'GPS',
      ...history.stops.map((stop) => 'T${stop.number}'),
    ].join(' → ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            history.isCompleted ? 'Pengiriman selesai' : 'Ringkasan pengiriman',
            style: TextStyle(
              color: history.isCompleted ? _success : _primary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

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

          const SizedBox(height: 14),

          const Divider(),

          const SizedBox(height: 12),

          const Text(
            'Urutan tujuan awal hasil Dijkstra',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            order,
            style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progres pengiriman',
                  style: TextStyle(
                    color: _heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(history.progress * 100).round()}%',
                style: const TextStyle(
                  color: _success,
                  fontSize: 13,
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
              minHeight: 7,
              backgroundColor: const Color(0xFFDCE7F5),
              valueColor: const AlwaysStoppedAnimation<Color>(_success),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DELIVERY STOP CARDS
  // ==========================================================

  Widget _buildEmptyDestinations() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.touch_app_outlined, color: _muted, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tekan lama pada peta, kemudian isi nama '
              'penerima dan deskripsi paket.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(DeliveryStop stop) {
    final int visitNumber = _visitNumber(stop);

    final Color statusColor = stop.isDelivered ? _success : _pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: stop.isDelivered ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stop.isDelivered ? const Color(0xFFBBF7D0) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: statusColor,
                child: Text(
                  '$visitNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(width: 11),

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
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _hasRoute
                          ? 'Kunjungan $visitNumber · '
                                'Tujuan awal ${stop.number}'
                          : stop.label,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),

              if (_canEdit)
                IconButton(
                  tooltip: 'Hapus ${stop.label}',
                  onPressed: () {
                    _removeDestination(stop.number);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: _muted,
                ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            '${stop.point.latitude.toStringAsFixed(5)}, '
            '${stop.point.longitude.toStringAsFixed(5)}',
            style: const TextStyle(color: _muted, fontSize: 10),
          ),

          if (_hasRoute) ...[
            const SizedBox(height: 10),

            if (stop.isDelivered)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _success,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    stop.statusLabel,
                    style: const TextStyle(
                      color: _success,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () {
                          _markDelivered(stop.number);
                        },
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: const Text('Tandai terkirim'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _success,
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // CALCULATE BUTTON
  // ==========================================================

  Widget _buildCalculateButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _canCalculate ? _calculateOptimizedRoute : null,

        icon: _calculatingRoute
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.alt_route_rounded, size: 21),

        label: Text(
          _calculatingRoute
              ? 'Menghitung rute...'
              : _hasRoute
              ? 'Hitung ulang rute'
              : 'Hitung Rute Dijkstra',
        ),
      ),
    );
  }

  // ==========================================================
  // DELIVERY PANEL
  // ==========================================================

  Widget _buildDeliveryPanel() {
    final DeliveryHistory? history = _activeHistory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _hasRoute ? 'Pengiriman aktif' : 'Rencana pengiriman',
                        style: const TextStyle(
                          color: _heading,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    TextButton.icon(
                      onPressed: _isBusy || _destinations.isEmpty
                          ? null
                          : _resetAll,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Reset'),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_destinations.length} dari '
                            '$_targetDestinationCount tujuan',
                            style: const TextStyle(
                              color: _heading,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Minimum 3, maksimum 8 tujuan',
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    _buildDestinationCounter(),
                  ],
                ),

                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _destinations.length / _targetDestinationCount,
                    minHeight: 5,
                    backgroundColor: _border,
                    valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),

                const SizedBox(height: 12),

                _buildStatusPanel(),

                if (history != null) ...[
                  const SizedBox(height: 12),

                  _buildRouteSummary(history),
                ],

                const SizedBox(height: 15),

                Text(
                  _hasRoute
                      ? 'Urutan kunjungan paket'
                      : 'Daftar paket pengiriman',
                  style: const TextStyle(
                    color: _heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (_hasRoute) ...[
                  const SizedBox(height: 4),

                  const Text(
                    'Nomor mengikuti hasil optimasi Dijkstra.',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],

                const SizedBox(height: 10),

                if (_destinations.isEmpty)
                  _buildEmptyDestinations()
                else
                  ..._visibleStops.map(_buildStopCard),

                const SizedBox(height: 4),
              ],
            ),
          ),

          // Optimasi dapat diulang sebelum paket
          // pertama ditandai terkirim.
          if (_completedCount == 0) ...[
            const SizedBox(height: 10),

            _buildCalculateButton(),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // APP BAR
  // ==========================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 72,

      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Delivery',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _heading,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'OpenStreetMap · Dijkstra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      actions: [
        IconButton(
          tooltip: 'Riwayat pengiriman',
          onPressed: _isBusy ? null : _openHistory,
          icon: const Icon(Icons.history_rounded),
          color: _primary,
        ),

        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: IconButton.filledTonal(
            tooltip: 'Ambil ulang lokasi GPS',
            onPressed: _canEdit ? _loadCurrentLocation : null,
            icon: _loadingLocation
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.gps_fixed_rounded, size: 21),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // MAIN BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),

      body: SafeArea(
        top: false,

        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool useWideLayout =
                constraints.maxWidth >= 600 &&
                constraints.maxWidth > constraints.maxHeight;

            // Layout horizontal untuk layar lebar.
            if (useWideLayout) {
              return Row(
                children: [
                  Expanded(child: _buildMap()),

                  SizedBox(
                    width: constraints.maxWidth * 0.43,
                    child: _buildDeliveryPanel(),
                  ),
                ],
              );
            }

            // Layout vertikal untuk smartphone.
            return Column(
              children: [
                Expanded(child: _buildMap()),

                SizedBox(
                  height: constraints.maxHeight * 0.55,
                  child: _buildDeliveryPanel(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// MAP LEGEND COMPONENT
// ============================================================

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DELIVERY STOP FORM
// ============================================================

class _DeliveryStopDialog extends StatefulWidget {
  final int number;
  final LatLng point;

  const _DeliveryStopDialog({required this.number, required this.point});

  @override
  State<_DeliveryStopDialog> createState() => _DeliveryStopDialogState();
}

class _DeliveryStopDialogState extends State<_DeliveryStopDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _recipientController = TextEditingController();

  final TextEditingController _packageController = TextEditingController();

  @override
  void dispose() {
    _recipientController.dispose();
    _packageController.dispose();

    super.dispose();
  }

  String? _validateRecipient(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama penerima wajib diisi.';
    }

    return null;
  }

  String? _validatePackage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Deskripsi paket wajib diisi.';
    }

    return null;
  }

  void _submitForm() {
    final bool valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    final DeliveryStop stop = DeliveryStop(
      number: widget.number,
      point: widget.point,
      recipientName: _recipientController.text.trim(),
      packageDescription: _packageController.text.trim(),
      isDelivered: false,
    );

    Navigator.of(context).pop(stop);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFF2563EB),
            size: 30,
          ),

          const SizedBox(height: 10),

          Text(
            'Tambah tujuan ${widget.number}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),

      content: Form(
        key: _formKey,

        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Lengkapi informasi penerima dan paket.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),

            const SizedBox(height: 18),

            TextFormField(
              controller: _recipientController,
              validator: _validateRecipient,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,

              decoration: InputDecoration(
                labelText: 'Nama penerima',
                hintText: 'Masukkan nama penerima',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: _packageController,
              validator: _validatePackage,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              minLines: 2,
              maxLines: 3,
              maxLength: 200,

              decoration: InputDecoration(
                labelText: 'Deskripsi paket',
                hintText: 'Contoh: Dokumen kantor',
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      '${widget.point.latitude.toStringAsFixed(5)}, '
                      '${widget.point.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),

        FilledButton(onPressed: _submitForm, child: const Text('Simpan')),
      ],
    );
  }
}
