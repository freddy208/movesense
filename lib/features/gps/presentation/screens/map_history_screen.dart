import 'package:Movesense/core/utils/app_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/gps_service.dart';

// ═══════════════════════════════════════
// PROVIDER SESSIONS HISTORIQUE
// ═══════════════════════════════════════
final sessionsHistoryProvider = FutureProvider<List<Map>>((ref) async {
  final service = ref.read(gpsServiceProvider);
  return service.loadSessions();
});

class MapHistoryScreen extends ConsumerStatefulWidget {
  const MapHistoryScreen({super.key});
  @override
  ConsumerState<MapHistoryScreen> createState() => _MapHistoryScreenState();
}

class _MapHistoryScreenState extends ConsumerState<MapHistoryScreen>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  bool _heatmapMode = false;

  late AnimationController _listController;
  late List<Animation<Offset>> _itemAnimations;

  final List<Color> _trackColors = [
    AppColors.energyOrange,
    AppColors.activeBlue,
    AppColors.successGreen,
    const Color(0xFF9B59B6),
    const Color(0xFFFF6B35),
  ];

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _itemAnimations = List.generate(
      10,
      (i) => Tween<Offset>(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _listController,
        curve: Interval(i * 0.08, 0.5 + i * 0.05, curve: Curves.easeOutCubic),
      )),
    );
    _listController.forward();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  List<LatLng> _extractPoints(Map session) {
    try {
      final points = session['points'] as List;
      return points
          .map((p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  LatLng _getCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(4.0511, 9.7679);
    final avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) /
        points.length;
    final avgLng = points.map((p) => p.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(avgLat, avgLng);
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const months = [
        'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
        'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Date inconnue';
    }
  }

  String _formatTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m >= 60) {
      return '${m ~/ 60}h ${m % 60}min';
    }
    return '${m}min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
  ref.listen(sessionRefreshProvider, (_, __) {
    ref.invalidate(sessionsHistoryProvider);
  });
    final sessionsAsync = ref.watch(sessionsHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: sessionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.energyOrange),
        ),
        error: (e, _) => Center(
          child: Text('Erreur: $e',
              style: const TextStyle(color: Colors.white)),
        ),
        data: (sessions) => _buildContent(sessions),
      ),
    );
  }

  Widget _buildContent(List<Map> sessions) {
    return Stack(
      children: [
        // ── CARTE PRINCIPALE ──
        _buildMainMap(sessions),

        // ── OVERLAY TOP ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(sessions),
        ),

        // ── PANEL BAS : liste sessions ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildSessionsList(sessions),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // CARTE PRINCIPALE
  // ═══════════════════════════════════════
  Widget _buildMainMap(List<Map> sessions) {
    // Collecte tous les points pour centrage
    List<LatLng> allPoints = [];
    for (final s in sessions) {
      allPoints.addAll(_extractPoints(s));
    }
    final center = allPoints.isNotEmpty
        ? _getCenter(allPoints)
        : const LatLng(4.0511, 9.7679);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15.0,
      ),
      children: [
        // Tuiles OSM (mode sombre)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.freddy.movesense',
          tileBuilder: _darkTileBuilder,
        ),

        // Mode heatmap : tous les parcours superposés
        if (_heatmapMode)
          PolylineLayer(
            polylines: sessions.asMap().entries.map((entry) {
              final points = _extractPoints(entry.value);
              final color = _trackColors[entry.key % _trackColors.length];
              return Polyline(
                points: points,
                strokeWidth: 4,
                color: color.withValues(alpha: 0.6),
              );
            }).toList(),
          ),

        // Mode normal : parcours sélectionné ou dernier
        if (!_heatmapMode)
          PolylineLayer(
            polylines: [
              if (sessions.isNotEmpty)
                () {
                  final idx = _selectedIndex ?? 0;
                  final points = _extractPoints(sessions[idx]);
                  return Polyline(
                    points: points,
                    strokeWidth: 5,
                    color: AppColors.energyOrange,
                    strokeCap: StrokeCap.round,
                  );
                }(),
            ].whereType<Polyline>().toList(),
          ),

        // Marqueurs départ/arrivée
        if (!_heatmapMode && sessions.isNotEmpty)
          MarkerLayer(
            markers: () {
              final idx = _selectedIndex ?? 0;
              final points = _extractPoints(sessions[idx]);
              if (points.isEmpty) return <Marker>[];
              return [
                Marker(
                  point: points.first,
                  width: 24,
                  height: 24,
                  child: _mapMarker(AppColors.successGreen, Icons.play_arrow_rounded),
                ),
                if (points.length > 1)
                  Marker(
                    point: points.last,
                    width: 24,
                    height: 24,
                    child: _mapMarker(AppColors.alertRed, Icons.stop_rounded),
                  ),
              ];
            }(),
          ),
      ],
    );
  }

  Widget _mapMarker(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 12),
    );
  }

  Widget _darkTileBuilder(BuildContext context, Widget tile, TileImage _) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.2, 0, 0, 0, 50,
        0, -0.2, 0, 0, 50,
        0, 0, -0.2, 0, 70,
        0, 0, 0, 1, 0,
      ]),
      child: tile,
    );
  }

  // ═══════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════
  Widget _buildTopBar(List<Map> sessions) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mes Parcours',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${sessions.length} session${sessions.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle heatmap
              GestureDetector(
                onTap: () {
                  setState(() => _heatmapMode = !_heatmapMode);
                  HapticFeedback.lightImpact();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _heatmapMode
                        ? AppColors.energyOrange
                        : Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _heatmapMode
                          ? AppColors.energyOrange
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Heatmap',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // LISTE SESSIONS
  // ═══════════════════════════════════════
  Widget _buildSessionsList(List<Map> sessions) {
    if (sessions.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        color: const Color(0xF00D1B2A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historique',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.activeBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.activeBlue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${sessions.length} parcours',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.activeBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste scrollable
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              physics: const BouncingScrollPhysics(),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final animIdx = index.clamp(0, 9);
                return SlideTransition(
                  position: _itemAnimations[animIdx],
                  child: _buildSessionCard(sessions[index], index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map session, int index) {
    final isSelected = _selectedIndex == index;
    final points = _extractPoints(session);
    final color = _trackColors[index % _trackColors.length];
    final distance = (session['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (session['duration'] as num?)?.toInt() ?? 0;
    final date = session['date']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = isSelected ? null : index;
          _heatmapMode = false;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Minimap
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1A2A3A),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: points.length > 1
                    ? _buildMiniMap(points, color)
                    : Center(
                        child: Icon(Icons.route_rounded,
                            color: color.withValues(alpha: 0.5), size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Parcours ${index + 1}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(date),
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date),
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statChip(
                        '${distance.toStringAsFixed(2)} km',
                        Icons.route_rounded,
                        color,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        _formatDuration(duration),
                        Icons.timer_rounded,
                        Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        '${points.length} pts',
                        Icons.location_on_rounded,
                        Colors.white.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              isSelected
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded,
              color: isSelected ? color : Colors.white.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMap(List<LatLng> points, Color color) {
    final center = _getCenter(points);
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.freddy.movesense',
          tileBuilder: _darkTileBuilder,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              strokeWidth: 3,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statChip(String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        color: const Color(0xF00D1B2A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun parcours enregistré',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Démarrez une session pour voir\nvos parcours ici.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.25),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}