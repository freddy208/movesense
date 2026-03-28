import 'package:Movesense/core/utils/app_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pedometer/data/datasources/pedometer_service.dart';
import '../../../gps/presentation/screens/active_session_screen.dart';
import '../../../../core/utils/app_router.dart';
import '../../../audio/data/datasources/audio_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _cardController;
  late AnimationController _fabController;
  late List<Animation<Offset>> _cardAnimations;
  late Animation<double> _fabScale;

  bool _sessionStarted = false;
  String _userName = 'Athlète';
  int _dailySteps = 0;
  int _dailyGoal = 10000;
  int _dailyDuration = 0;
  double _dailyCalories = 0.0;

  final List<String> _motivationalQuotes = [
    "Chaque pas compte. Continue ! 💪",
    "La régularité bat l'intensité. 🔥",
    "Ton corps peut le faire. C'est ton esprit qu'il faut convaincre. 🧠",
    "Un pas à la fois, une victoire à la fois. 🏆",
    "L'excellence n'est pas un acte, c'est une habitude. ⚡",
    "Aujourd'hui difficile = Demain plus fort. 💎",
    "Bouge maintenant, repose-toi plus tard. 🚀",
  ];

  String get _todayQuote {
    final dayIndex = DateTime.now().day % _motivationalQuotes.length;
    return _motivationalQuotes[dayIndex];
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupAnimations();
    // Lit la citation du jour après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final audio = AudioService();
        audio.initialize().then((_) {
          if (audio.state.ttsEnabled) {
            audio.speakQuote(_todayQuote);
          }
        });
      }
    });
  }
  void _loadUserData() {
    final box = Hive.box(AppConstants.userProfileBox);
    final today = _todayKey();
    setState(() {
      _userName = box.get(AppConstants.userNameKey, defaultValue: 'Athlète');
      _dailyGoal = box.get(AppConstants.dailyStepGoalKey, defaultValue: 10000);
      _dailySteps = box.get('daily_steps_$today', defaultValue: 0);
      _dailyDuration = box.get('daily_duration_$today', defaultValue: 0);
      _dailyCalories = box.get('daily_calories_$today', defaultValue: 0.0);
    });
  }
  void _setupAnimations() {
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _cardAnimations = List.generate(5, (i) {
      return Tween<Offset>(
        begin: const Offset(0, 0.4),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _cardController,
          curve: Interval(i * 0.12, 0.6 + i * 0.08, curve: Curves.easeOutCubic),
        ),
      );
    });

    _fabScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      _cardController.forward();
      _fabController.forward();
    });
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

void _toggleSession() {
  HapticFeedback.mediumImpact();
  if (_sessionStarted) return;

  setState(() => _sessionStarted = true);

  Navigator.of(context).push(
    AppRouter.slideUp(const ActiveSessionScreen()),
  ).then((_) {
    // Retour de la session → reset bouton + reload données
    if (mounted) {
      setState(() => _sessionStarted = false);
      _loadUserData();
    }
  });
}

  @override
  void dispose() {
    _cardController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveSession = ref.watch(liveSessionProvider);
    // Écoute fin de session → recharge les données du dashboard
    ref.listen(sessionRefreshProvider, (_, __) {
      if (mounted) _loadUserData();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Fond décoratif
          _buildBackground(),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Salutation
                  _buildGreeting(),
                  const SizedBox(height: 24),

                  // Cercle progression principal
                  SlideTransition(
                    position: _cardAnimations[0],
                    child: _buildMainProgressCircle(liveSession),
                  ),
                  const SizedBox(height: 24),

                  // 4 Metric Cards
                  SlideTransition(
                    position: _cardAnimations[1],
                    child: _buildMetricCards(liveSession),
                  ),
                  const SizedBox(height: 20),

                  // Session live card
                  if (_sessionStarted)
                    SlideTransition(
                      position: _cardAnimations[2],
                      child: _buildLiveSessionCard(liveSession),
                    ),
                  if (_sessionStarted) const SizedBox(height: 20),

                  // Score santé
                  SlideTransition(
                    position: _cardAnimations[3],
                    child: _buildHealthScoreCard(liveSession),
                  ),
                  const SizedBox(height: 20),

                  // Citation motivante
                  SlideTransition(
                    position: _cardAnimations[4],
                    child: _buildMotivationCard(),
                  ),
                ],
              ),
            ),
          ),

          // FAB centré en bas
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: ScaleTransition(
              scale: _fabScale,
              child: _buildStartButton(),
            ),
          ),
        ],
      ),
    );
  }

 //buildAppBar()

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.activeBlue.withValues(alpha: 0.07),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -60,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.energyOrange.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    String emoji;
    if (hour < 12) {
      greeting = 'Bonjour';
      emoji = '☀️';
    } else if (hour < 18) {
      greeting = 'Bon après-midi';
      emoji = '⚡';
    } else {
      greeting = 'Bonsoir';
      emoji = '🌙';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $_userName $emoji',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getDateString(),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _buildMainProgressCircle(AsyncValue<LiveSessionData> liveSession) {
    final session = liveSession.valueOrNull;
    final totalSteps = _dailySteps + (session?.steps ?? 0);
    final progress = (_dailyGoal > 0 ? totalSteps / _dailyGoal : 0.0).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A5C).withValues(alpha: 0.9),
            const Color(0xFF0D2137).withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.activeBlue.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Objectif du jour',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: percent >= 100
                      ? AppColors.successGreen.withValues(alpha: 0.2)
                      : AppColors.energyOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: percent >= 100
                        ? AppColors.successGreen.withValues(alpha: 0.4)
                        : AppColors.energyOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  percent >= 100 ? '✅ Atteint !' : '$percent%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: percent >= 100
                        ? AppColors.successGreen
                        : AppColors.energyOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CircularPercentIndicator(
            radius: 100,
            lineWidth: 14,
            percent: progress,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatNumber(totalSteps),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'pas',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '/ ${_formatNumber(_dailyGoal)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.energyOrange.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            progressColor: percent >= 100
                ? AppColors.successGreen
                : AppColors.energyOrange,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 1000,
          ),
          const SizedBox(height: 16),
          // Barre progression linéaire
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent >= 100 ? AppColors.successGreen : AppColors.energyOrange,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Encore ${_formatNumber((_dailyGoal - totalSteps).clamp(0, _dailyGoal))} pas pour atteindre votre objectif',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(AsyncValue<LiveSessionData> liveSession) {
    final totalDistance = _dailySteps * 0.00075;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _metricCard(
          icon: Icons.route_rounded,
          label: 'Distance',
          value: totalDistance.toStringAsFixed(2),
          unit: 'km',
          color: AppColors.activeBlue,
          iconBg: AppColors.activeBlue.withValues(alpha: 0.2),
        ),
        _metricCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Calories',
          value: _dailyCalories.toStringAsFixed(0),
          unit: 'kcal',
          color: const Color(0xFFFF6B35),
          iconBg: const Color(0xFFFF6B35).withValues(alpha: 0.2),
        ),
        _metricCard(
          icon: Icons.timer_rounded,
          label: 'Durée',
          value: _formatDuration(_dailyDuration),
          unit: '',
          color: const Color(0xFF9B59B6),
          iconBg: const Color(0xFF9B59B6).withValues(alpha: 0.2),
        ),
        _metricCard(
          icon: Icons.favorite_rounded,
          label: 'BPM',
          value: '--',
          unit: 'bpm',
          color: AppColors.alertRed,
          iconBg: AppColors.alertRed.withValues(alpha: 0.2),
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF1A2A3A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _sessionStarted ? AppColors.successGreen : Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSessionCard(AsyncValue<LiveSessionData> liveSession) {
    final session = liveSession.valueOrNull;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.energyOrange.withValues(alpha: 0.15),
            AppColors.energyOrange.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: AppColors.energyOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.successGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'SESSION EN COURS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.energyOrange,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                session?.formattedDuration ?? '00:00',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _liveMetric('${session?.steps ?? 0}', 'pas'),
              _liveDivider(),
              _liveMetric(
                '${session?.distance.toStringAsFixed(2) ?? '0.00'}',
                'km',
              ),
              _liveDivider(),
              _liveMetric(
                '${session?.speedKmh.toStringAsFixed(1) ?? '0.0'}',
                'km/h',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveMetric(String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _liveDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildHealthScoreCard(AsyncValue<LiveSessionData> liveSession) {
    final session = liveSession.valueOrNull;
    final totalSteps = _dailySteps + (session?.steps ?? 0);
    final score = ((totalSteps / _dailyGoal) * 100).clamp(0, 100).toInt();

    Color scoreColor;
    String scoreLabel;
    if (score >= 80) {
      scoreColor = AppColors.successGreen;
      scoreLabel = 'Excellent 🔥';
    } else if (score >= 50) {
      scoreColor = AppColors.energyOrange;
      scoreLabel = 'Bien 👍';
    } else {
      scoreColor = AppColors.alertRed;
      scoreLabel = 'À améliorer 💪';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A2A3A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scoreColor, width: 3),
              color: scoreColor.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Score Santé du jour',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scoreLabel,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: scoreColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navyBlue.withValues(alpha: 0.8),
            AppColors.activeBlue.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(color: AppColors.activeBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.energyOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.format_quote_rounded,
              color: AppColors.energyOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _todayQuote,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: GestureDetector(
        onTap: _toggleSession,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: _sessionStarted
                  ? [AppColors.alertRed, AppColors.alertRed.withValues(alpha: 0.8)]
                  : [AppColors.energyOrange, const Color(0xFFFF9A3C)],
            ),
            boxShadow: [
              BoxShadow(
                color: (_sessionStarted ? AppColors.alertRed : AppColors.energyOrange)
                    .withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _sessionStarted
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                _sessionStarted ? 'Arrêter la session' : 'Démarrer une session',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k == k.truncateToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return n.toString();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}