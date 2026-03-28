import 'package:Movesense/core/utils/app_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/gamification_service.dart';
import 'badges_screen.dart';

class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});
  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}
class _GamificationScreenState extends ConsumerState<GamificationScreen>
    with TickerProviderStateMixin {
  final GamificationService _service = GamificationService();
  GamificationState? _state;
  bool _loading = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _loadData();
  }

  Future<void> _loadData() async {
    final state = await _service.loadState();
    setState(() {
      _state = state;
      _loading = false;
    });
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionRefreshProvider, (_, __) => _loadData());
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.energyOrange))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildLevelCard(),
                            const SizedBox(height: 16),
                            _buildStreakCard(),
                            const SizedBox(height: 16),
                            _buildActivityCalendar(),
                            const SizedBox(height: 16),
                            _buildStatsGrid(),
                            const SizedBox(height: 16),
                            _buildBadgesPreview(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── APP BAR ──
Widget _buildAppBar() {
  return const SliverAppBar(
    pinned: true,
    automaticallyImplyLeading: false,
    backgroundColor: Color(0xFF0D1B2A),
    title: Text(
      'Progression',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    centerTitle: true,
  );
}

  // ── CARTE NIVEAU ──
  Widget _buildLevelCard() {
    final state = _state!;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            state.levelColor.withValues(alpha: 0.25),
            state.levelColor.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: state.levelColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: state.levelColor.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Badge niveau
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.levelColor.withValues(alpha: 0.2),
                  border: Border.all(
                    color: state.levelColor,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: state.levelColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.levelEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    Text(
                      'Niv. ${state.currentLevel}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.levelTitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: state.levelColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.totalXp} XP total',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Barre XP
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: state.levelProgress,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(state.levelColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(state.levelProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: state.levelColor,
                          ),
                        ),
                        if (state.currentLevel < 10)
                          Text(
                            'encore ${state.xpForNextLevel} XP',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Niveaux suivants
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              5,
              (i) {
                final lvl = state.currentLevel + i;
                if (lvl > 10) return const SizedBox();
                final isCurrentLevel = lvl == state.currentLevel;
                final color = GamificationState.levelColors[
                    (lvl - 1).clamp(0, 9)];
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isCurrentLevel ? 40 : 32,
                      height: isCurrentLevel ? 40 : 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lvl <= state.currentLevel
                            ? color.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: isCurrentLevel
                              ? color
                              : Colors.white.withValues(alpha: 0.1),
                          width: isCurrentLevel ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          GamificationState.levelEmojis[
                              (lvl - 1).clamp(0, 9)],
                          style: TextStyle(
                            fontSize: isCurrentLevel ? 16 : 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$lvl',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: isCurrentLevel
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isCurrentLevel
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── CARTE STREAK ──
  Widget _buildStreakCard() {
    final state = _state!;
    final streakColor = state.currentStreak >= 7
        ? AppColors.alertRed
        : state.currentStreak >= 3
            ? AppColors.energyOrange
            : AppColors.activeBlue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A2A3A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Flame animée
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: streakColor.withValues(alpha: 0.15),
              border: Border.all(
                color: streakColor.withValues(alpha: 0.4),
              ),
            ),
            child: Center(
              child: Text(
                state.currentStreak >= 7
                    ? '🔥'
                    : state.currentStreak >= 3
                        ? '⚡'
                        : '📅',
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${state.currentStreak}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: streakColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'jours consécutifs',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Record : ${state.longestStreak} jours',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          // Joker
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: state.jokerUsedThisMonth < 1
                      ? AppColors.successGreen.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: state.jokerUsedThisMonth < 1
                        ? AppColors.successGreen.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  state.jokerUsedThisMonth < 1 ? '🃏' : '❌',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Joker',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CALENDRIER ACTIVITÉ (GitHub-like) ──
  Widget _buildActivityCalendar() {
    final state = _state!;
    final today = DateTime.now();
    final days = List.generate(49, (i) {
      return today.subtract(Duration(days: 48 - i));
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A2A3A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activité — 7 dernières semaines',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.energyOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.activeDays.length} jours actifs',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.energyOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grille GitHub-like
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: 49,
            itemBuilder: (context, index) {
              final day = days[index];
              final key =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final isActive = state.activeDays.contains(key);
              final isToday = key ==
                  '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

              return Tooltip(
                message:
                    '${day.day}/${day.month}${isActive ? ' ✅' : ''}',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isActive
                        ? AppColors.energyOrange
                        : Colors.white.withValues(alpha: 0.06),
                    border: isToday
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          )
                        : null,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.energyOrange
                                  .withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Moins',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 6),
              ...List.generate(4, (i) {
                return Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: AppColors.energyOrange
                        .withValues(alpha: 0.2 + i * 0.25),
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text(
                'Plus',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── STATS GRID ──
  Widget _buildStatsGrid() {
    final state = _state!;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _statCard('${state.totalSessions}', 'Sessions', '🏃',
            AppColors.activeBlue),
        _statCard('${state.totalSteps}', 'Pas total', '👟',
            AppColors.energyOrange),
        _statCard(
            '${state.totalDistance.toStringAsFixed(1)} km',
            'Distance',
            '🗺️',
            AppColors.successGreen),
        _statCard('${state.goalsReached}', 'Objectifs', '🎯',
            const Color(0xFF9B59B6)),
      ],
    );
  }

  Widget _statCard(
      String value, String label, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── APERÇU BADGES ──
  Widget _buildBadgesPreview() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BadgesScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppColors.energyOrange.withValues(alpha: 0.12),
              AppColors.energyOrange.withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(
            color: AppColors.energyOrange.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes Badges',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Voir tous les badges et récompenses',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: AppColors.energyOrange,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.energyOrange,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}