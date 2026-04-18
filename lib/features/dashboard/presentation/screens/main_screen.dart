import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import '../../../gps/presentation/screens/map_history_screen.dart';
import '../../../gamification/presentation/screens/gamification_screen.dart';
import '../../../ai_advisor/presentation/screens/ai_screen.dart';
import '../../../audio/presentation/screens/audio_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../../core/utils/app_router.dart';
import '../../../gamification/data/datasources/badge_service.dart'
    as badge_model;
import '../../../../core/utils/app_state_provider.dart';
import '../../../audio/data/datasources/audio_service.dart';

// ═══════════════════════════════════════
// DIALOG BADGE DÉBLOQUÉ (remplace overlay)
// ═══════════════════════════════════════
class BadgeUnlockedDialog extends StatelessWidget {
  final badge_model.Badge badge;
  const BadgeUnlockedDialog({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2A3A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: badge.color.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: badge.color.withValues(alpha: 0.35),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animation Lottie
            SizedBox(
              height: 130,
              child: Lottie.asset(
                'assets/animations/badge_unlock.json',
                repeat: false,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),

            // Emoji badge
            Text(
              badge.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),

            // Nom du badge
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: badge.color,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // XP + bouton
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.energyOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.energyOrange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+${badge.xpReward} XP',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.energyOrange,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    onPressed: () => Navigator.of(context).pop(),
                    backgroundColor: AppColors.successGreen,
                    elevation: 0,
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// TRANSITIONS FLUIDES
// ═══════════════════════════════════════
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.015),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: IndexedStack(
          index: widget.index,
          children: widget.children,
        ),
      ),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HistoryScreen(),
    MapHistoryScreen(),
    GamificationScreen(),
    AIScreen(),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Écoute fin de session → affiche badges débloqués
    ref.listen(sessionRefreshProvider, (prev, next) async {
      if (prev == null || next <= prev) return;

      // Attendre que la navigation de fin de session se termine
      await Future.delayed(const Duration(milliseconds: 800));

      final badgeService = badge_model.BadgeService();
      final badges = await badgeService.loadBadges();
      final now = DateTime.now();
      final recentBadges = badges
          .where((b) =>
              b.isUnlocked &&
              b.unlockedAt != null &&
              now.difference(b.unlockedAt!).inSeconds < 20)
          .toList();

      if (!mounted) return;

      for (final badge in recentBadges) {
        if (!mounted) return;
        await AudioService().playSound(AppSound.badge);
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.6),
            builder: (_) => BadgeUnlockedDialog(badge: badge),
          );
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: _buildTopBar(),
      body: FadeIndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── TOP BAR GLOBAL ──
  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1B2A),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.energyOrange.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.energyOrange.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/movesense_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFB8D4F0)],
            ).createShader(bounds),
            child: const Text(
              'MoveSense',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.push(
              context,
              AppRouter.slideUp(const AudioScreen()),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.push(
              context,
              AppRouter.slideUp(const SettingsScreen()),
            ),
          ),
        ),
      ],
    );
  }

  // ── BOTTOM NAV : 5 ONGLETS ──
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111E2D),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Accueil'),
              _navItem(1, Icons.bar_chart_rounded, Icons.bar_chart_outlined,
                  'Stats'),
              _navItem(2, Icons.map_rounded, Icons.map_outlined, 'Carte'),
              _navItem(3, Icons.emoji_events_rounded,
                  Icons.emoji_events_outlined, 'XP'),
              _navItem(
                  4, Icons.psychology_rounded, Icons.psychology_outlined, 'IA'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.energyOrange.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(
                  color: AppColors.energyOrange.withValues(alpha: 0.25))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                key: ValueKey(isSelected),
                color: isSelected
                    ? AppColors.energyOrange
                    : Colors.white.withValues(alpha: 0.35),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.energyOrange
                    : Colors.white.withValues(alpha: 0.35),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
