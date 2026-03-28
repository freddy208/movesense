import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../gps/data/datasources/gps_service.dart';
import '../../../pedometer/data/datasources/pedometer_service.dart';
import '../../../audio/data/datasources/audio_service.dart';
import '../../../heart_rate/data/datasources/heart_rate_service.dart';
import '../../../../core/utils/session_completion_service.dart';
import '../../../../core/utils/app_state_provider.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isPaused = false;
  bool _followUser = true;
  bool _panelExpanded = false;

  late AnimationController _pulseController;
  late AnimationController _panelController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _panelAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startServices();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );
  }

  void _startServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(gpsServiceProvider).startTracking();
      ref.read(pedometerServiceProvider).startSession();

      // Musique si activée
      final audio = AudioService();
      await audio.initialize();
      if (audio.state.musicEnabled && audio.state.playlist.isNotEmpty) {
        await audio.playMusic();
      }

      // HeartRate
      final box = Hive.box('user_profile_box');
      final age = box.get('user_age', defaultValue: 25) as int;
      ref.read(heartRateServiceProvider).start(age);
    });
  }

  void _togglePause() {
    HapticFeedback.mediumImpact();
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      ref.read(gpsServiceProvider).pauseTracking();
      ref.read(pedometerServiceProvider).pauseSession();
    } else {
      ref.read(gpsServiceProvider).resumeTracking();
      ref.read(pedometerServiceProvider).resumeSession();
    }
  }

  void _stopSession() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _buildStopDialog(),
    );
  }

void _confirmStop() async {
  final sessionData = ref.read(liveSessionProvider).valueOrNull;
  final gpsData = ref.read(liveGpsProvider).valueOrNull;

  // Arrête les services
  ref.read(gpsServiceProvider).stopTracking();
  ref.read(pedometerServiceProvider).stopSession();
  ref.read(heartRateServiceProvider).stop();
  AudioService().stopMusic();

  // Notifie AVANT de pop (contexte encore valide)
  if (sessionData != null && gpsData != null) {
    await SessionCompletionService.onSessionComplete(
      session: sessionData,
      gpsData: gpsData,
    );
    // Notifie ici — avant de quitter l'écran
    ref.read(sessionRefreshProvider.notifier).state++;
  }

  // Pop après la notification
  if (mounted) {
    Navigator.of(context).pop(); // dialog
    Navigator.of(context).pop(); // screen
  }
}

  @override
  void dispose() {
    _pulseController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpsData = ref.watch(liveGpsProvider);
    final sessionData = ref.watch(liveSessionProvider);
    final hrData = ref.watch(heartRateStreamProvider);

    final gps = gpsData.valueOrNull;
    final session = sessionData.valueOrNull;
    final bpm = hrData.valueOrNull?.bpm ?? 72;
    final zone = hrData.valueOrNull?.zone ?? HeartZone.rest;

    if (_followUser && gps?.lastPoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(gps!.lastPoint!.latLng, 17.0);
        } catch (_) {}
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          _buildMap(gps),
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopOverlay(session, gps),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomPanel(session, gps, bpm, zone),
          ),
          Positioned(
            right: 16,
            bottom: _panelExpanded ? 340 : 260,
            child: _buildFollowButton(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // CARTE
  // ═══════════════════════════════════════
  Widget _buildMap(LiveGpsData? gps) {
    final center = gps?.lastPoint?.latLng ?? const LatLng(4.0511, 9.7679);
    final polylinePoints = gps?.polylinePoints ?? [];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 17.0,
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _followUser) {
            setState(() => _followUser = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.freddy.movesense',
          tileBuilder: _darkModeTileBuilder,
        ),
        if (polylinePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                strokeWidth: 8,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        if (polylinePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                strokeWidth: 5,
                color: AppColors.energyOrange,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
        if (polylinePoints.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: polylinePoints.first,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.successGreen.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        if (gps?.lastPoint != null)
          MarkerLayer(
            markers: [
              Marker(
                point: gps!.lastPoint!.latLng,
                width: 60,
                height: 60,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.activeBlue.withValues(alpha: 0.2),
                            border: Border.all(
                              color: AppColors.activeBlue.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.activeBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.activeBlue.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _darkModeTileBuilder(
      BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.2, 0, 0, 0, 50,
        0, -0.2, 0, 0, 50,
        0, 0, -0.2, 0, 70,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  // ═══════════════════════════════════════
  // TOP OVERLAY
  // ═══════════════════════════════════════
  Widget _buildTopOverlay(dynamic session, LiveGpsData? gps) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: _stopSession,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
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
                      'Session Active',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, __) => Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isPaused
                                  ? AppColors.energyOrange
                                  : AppColors.successGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isPaused
                                          ? AppColors.energyOrange
                                          : AppColors.successGreen)
                                      .withValues(
                                          alpha: _pulseAnimation.value - 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPaused ? 'En pause' : 'En cours',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  session?.formattedDuration ?? '00:00',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
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
  // PANEL BAS
  // ═══════════════════════════════════════
  Widget _buildBottomPanel(
      dynamic session, LiveGpsData? gps, int bpm, HeartZone zone) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEE0D1B2A), Color(0xFF0D1B2A)],
        ),
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
          GestureDetector(
            onTap: () {
              setState(() => _panelExpanded = !_panelExpanded);
              _panelExpanded
                  ? _panelController.forward()
                  : _panelController.reverse();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          // Métriques principales avec BPM réel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPanelMetric(
                  icon: Icons.directions_walk_rounded,
                  value: '${session?.steps ?? 0}',
                  label: 'Pas',
                  color: AppColors.activeBlue,
                ),
                _buildPanelDivider(),
                _buildPanelMetric(
                  icon: Icons.route_rounded,
                  value: (gps?.totalDistance ?? 0).toStringAsFixed(2),
                  label: 'km GPS',
                  color: AppColors.energyOrange,
                ),
                _buildPanelDivider(),
                _buildPanelMetric(
                  icon: Icons.speed_rounded,
                  value: (gps?.currentSpeed ?? 0).toStringAsFixed(1),
                  label: 'km/h',
                  color: AppColors.successGreen,
                ),
                _buildPanelDivider(),
                // BPM réel avec couleur de zone
                _buildPanelMetric(
                  icon: Icons.favorite_rounded,
                  value: '$bpm',
                  label: 'BPM',
                  color: zone.color,
                ),
              ],
            ),
          ),

          // Panel étendu
          SizeTransition(
            sizeFactor: _panelAnimation,
            child: _buildExpandedPanel(session, gps, bpm, zone),
          ),

          const SizedBox(height: 12),

          // Boutons contrôle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _togglePause,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isPaused
                            ? AppColors.successGreen
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isPaused
                              ? AppColors.successGreen
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPaused ? 'Reprendre' : 'Pause',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _stopSession,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.alertRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.alertRed.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.stop_rounded,
                        color: AppColors.alertRed, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedPanel(
      dynamic session, LiveGpsData? gps, int bpm, HeartZone zone) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailCard(
                  label: 'Allure',
                  value: session != null && session.paceMinkm > 0
                      ? '${session.paceMinkm.toStringAsFixed(1)}\'/km'
                      : '--',
                  icon: Icons.av_timer_rounded,
                  color: const Color(0xFF9B59B6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailCard(
                  label: 'Calories',
                  value: '${session?.calories.toStringAsFixed(0) ?? 0} kcal',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailCard(
                  label: 'Altitude',
                  value:
                      '${(gps?.currentAltitude ?? 0).toStringAsFixed(0)} m',
                  icon: Icons.terrain_rounded,
                  color: AppColors.activeBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailCard(
                  label: 'Zone cardiaque',
                  value: '${zone.emoji} ${zone.label}',
                  icon: Icons.monitor_heart_rounded,
                  color: zone.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanelMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildDetailCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _followUser = true);
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _followUser
              ? AppColors.activeBlue
              : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _followUser
                ? AppColors.activeBlue
                : Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          _followUser
              ? Icons.my_location_rounded
              : Icons.location_searching_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStopDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2A3A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.alertRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop_rounded,
                  color: AppColors.alertRed, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arrêter la session ?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Votre session sera sauvegardée\ndans votre historique.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                    child: const Text(
                      'Continuer',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmStop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.alertRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Arrêter',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}