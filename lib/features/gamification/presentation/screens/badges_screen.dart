import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/badge_service.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with TickerProviderStateMixin {
  final BadgeService _badgeService = BadgeService();
  List<Badge> _badges = [];
  String _selectedCategory = 'all';
  bool _loading = true;

  late AnimationController _headerController;
  late Animation<double> _headerFade;

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': 'Tous', 'icon': Icons.grid_view_rounded},
    {'key': 'steps', 'label': 'Pas', 'icon': Icons.directions_walk_rounded},
    {'key': 'distance', 'label': 'Distance', 'icon': Icons.route_rounded},
    {'key': 'streak', 'label': 'Streak', 'icon': Icons.local_fire_department_rounded},
    {'key': 'session', 'label': 'Sessions', 'icon': Icons.timer_rounded},
    {'key': 'secret', 'label': 'Secrets', 'icon': Icons.lock_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeIn,
    );
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final badges = await _badgeService.loadBadges();
    setState(() {
      _badges = badges;
      _loading = false;
    });
    _headerController.forward();
  }

  List<Badge> get _filteredBadges {
    if (_selectedCategory == 'all') return _badges;
    return _badges.where((b) => b.category == _selectedCategory).toList();
  }

  int get _unlockedCount => _badges.where((b) => b.isUnlocked).length;

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.energyOrange))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(child: _buildStatsBar()),
                SliverToBoxAdapter(child: _buildCategoryFilter()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: _buildBadgesGrid(),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A3A5C), Color(0xFF0D1B2A)],
            ),
          ),
          child: Stack(
            children: [
              // Déco
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.energyOrange.withValues(alpha: 0.07),
                  ),
                ),
              ),
              // Contenu
              SafeArea(
                child: FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.energyOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.energyOrange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                '🏆',
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mes Badges',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '$_unlockedCount / ${_badges.length} débloqués',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final progress = _badges.isEmpty ? 0.0 : _unlockedCount / _badges.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A2A3A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('$_unlockedCount', 'Obtenus', AppColors.energyOrange),
              _statDivider(),
              _statItem(
                '${_badges.length - _unlockedCount}',
                'À débloquer',
                Colors.white.withValues(alpha: 0.4),
              ),
              _statDivider(),
              _statItem(
                '${(_unlockedCount * 50)}',
                'XP gagnés',
                AppColors.successGreen,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(AppColors.energyOrange),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toInt()}% de completion',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
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
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 32,
        color: Colors.white.withValues(alpha: 0.08),
      );

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat['key'];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = cat['key']);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.energyOrange
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.energyOrange
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'],
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadgesGrid() {
    final filtered = _filteredBadges;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildBadgeCard(filtered[index]),
        childCount: filtered.length,
      ),
    );
  }

  Widget _buildBadgeCard(Badge badge) {
    final isSecret = badge.isSecret && !badge.isUnlocked;

    return GestureDetector(
      onTap: () => _showBadgeDetail(badge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: badge.isUnlocked
              ? badge.color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: badge.isUnlocked
                ? badge.color.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: badge.isUnlocked ? 1.5 : 1,
          ),
          boxShadow: badge.isUnlocked
              ? [
                  BoxShadow(
                    color: badge.color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji / icône
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badge.isUnlocked
                        ? badge.color.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                isSecret
                    ? Icon(
                        Icons.lock_rounded,
                        color: Colors.white.withValues(alpha: 0.2),
                        size: 26,
                      )
                    : ColorFiltered(
                        colorFilter: badge.isUnlocked
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.saturation,
                              )
                            : const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 0.4, 0,
                              ]),
                        child: Text(
                          badge.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                // Checkmark si débloqué
                if (badge.isUnlocked)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: badge.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0D1B2A),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                isSecret ? '???' : badge.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badge.isUnlocked
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
            if (badge.isUnlocked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${badge.xpReward} XP',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badge.color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(Badge badge) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BadgeDetailSheet(badge: badge),
    );
  }
}

// ═══════════════════════════════════════
// SHEET DÉTAIL BADGE
// ═══════════════════════════════════════
class _BadgeDetailSheet extends StatelessWidget {
  final Badge badge;
  const _BadgeDetailSheet({required this.badge});

  @override
  Widget build(BuildContext context) {
    final isSecret = badge.isSecret && !badge.isUnlocked;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Emoji grand
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.isUnlocked
                  ? badge.color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: badge.isUnlocked
                    ? badge.color.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
              boxShadow: badge.isUnlocked
                  ? [BoxShadow(color: badge.color.withValues(alpha: 0.3), blurRadius: 20)]
                  : [],
            ),
            child: Center(
              child: isSecret
                  ? Icon(Icons.lock_rounded,
                      color: Colors.white.withValues(alpha: 0.3), size: 36)
                  : Text(badge.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            isSecret ? 'Badge Secret' : badge.name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSecret
                ? 'Continuez à explorer pour débloquer ce badge mystère...'
                : badge.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Statut
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: badge.isUnlocked
                  ? badge.color.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: badge.isUnlocked
                    ? badge.color.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      badge.isUnlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_clock_rounded,
                      color: badge.isUnlocked
                          ? badge.color
                          : Colors.white.withValues(alpha: 0.3),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      badge.isUnlocked ? 'Débloqué !' : 'Verrouillé',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: badge.isUnlocked
                            ? badge.color
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                Text(
                  '+${badge.xpReward} XP',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: badge.isUnlocked
                        ? AppColors.energyOrange
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),

          if (badge.isUnlocked && badge.unlockedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Obtenu le ${badge.unlockedAt!.day}/${badge.unlockedAt!.month}/${badge.unlockedAt!.year}',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// OVERLAY BADGE DÉBLOQUÉ (animation Lottie)
// ═══════════════════════════════════════

class BadgeUnlockOverlay extends StatefulWidget {
  final Badge badge;
  final VoidCallback onDismiss;

  const BadgeUnlockOverlay({
    super.key,
    required this.badge,
    required this.onDismiss,
  });

  @override
  State<BadgeUnlockOverlay> createState() => _BadgeUnlockOverlayState();
}

class _BadgeUnlockOverlayState extends State<BadgeUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), widget.onDismiss);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: widget.onDismiss,
        child: FadeTransition(
          opacity: _fade,
          child: Container(
            color: Colors.black.withValues(alpha: 0.85),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A3A),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: widget.badge.color.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.badge.color.withValues(alpha: 0.35),
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
                        widget.badge.emoji,
                        style: const TextStyle(fontSize: 56),
                      ),
                      const SizedBox(height: 12),

                      // Nom du badge
                      Text(
                        widget.badge.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: widget.badge.color,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // XP gagné
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.energyOrange
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.energyOrange
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '+${widget.badge.xpReward} XP',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.energyOrange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tap pour fermer
                      Text(
                        'Appuyer pour continuer',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}