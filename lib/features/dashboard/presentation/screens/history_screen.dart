import 'package:Movesense/core/utils/app_state_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  String _selectedFilter = '7j';
  List<Map<String, dynamic>> _dailyData = [];
  bool _loading = true;

  final List<String> _filters = ['7j', '30j', '3m'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final box = await Hive.openBox('user_profile_box');
    final goal = box.get('daily_step_goal', defaultValue: 10000) as int;

    int days;
    switch (_selectedFilter) {
      case '30j': days = 30; break;
      case '3m': days = 90; break;
      default: days = 7;
    }

    final data = <Map<String, dynamic>>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = 'daily_steps_${date.year}-${date.month}-${date.day}';
      final steps = box.get(key, defaultValue: 0) as int;
      data.add({
        'date': date,
        'steps': steps,
        'goal': goal,
        'achieved': steps >= goal,
        'progress': goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0,
        'duration': box.get(
          'daily_duration_${date.year}-${date.month}-${date.day}',
          defaultValue: 0,
        ) as int,
      });
    }

    setState(() {
      _dailyData = data;
      _loading = false;
    });
    _animController.forward(from: 0);
  }

  List<Map<String, dynamic>> get _weeklyData {
    final weeks = <Map<String, dynamic>>[];
    for (int w = 0; w < (_dailyData.length / 7).ceil(); w++) {
      final start = w * 7;
      final end = (start + 7).clamp(0, _dailyData.length);
      final week = _dailyData.sublist(start, end);
      final total = week.fold(0, (s, d) => s + (d['steps'] as int));
      final avg = week.isEmpty ? 0 : total ~/ week.length;
      weeks.add({'week': w + 1, 'total': total, 'avg': avg});
    }
    return weeks;
  }

  int get _totalSteps =>
      _dailyData.fold(0, (s, d) => s + (d['steps'] as int));

  int get _activeDays =>
      _dailyData.where((d) => (d['steps'] as int) > 0).length;

  int get _goalsAchieved =>
      _dailyData.where((d) => d['achieved'] as bool).length;

  double get _avgSteps =>
      _dailyData.isEmpty ? 0 : _totalSteps / _dailyData.length;

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
              child:
                  CircularProgressIndicator(color: AppColors.energyOrange))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(child: _buildFilterBar()),
                  SliverToBoxAdapter(child: _buildStatsRow()),
                  SliverToBoxAdapter(child: _buildHeatmapCalendar()),
                  SliverToBoxAdapter(child: _buildWeeklyBarChart()),
                  SliverToBoxAdapter(child: _buildMonthlyLineChart()),
                  SliverToBoxAdapter(child: _buildDaysList()),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  // ── APP BAR ──
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF0D1B2A),
      title: const Text(
        'Historique',
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

  // ── FILTRES ──
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: _filters.map((f) {
          final isSelected = _selectedFilter == f;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = f);
              HapticFeedback.selectionClick();
              _loadData();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
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
              child: Text(
                f,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── STATS RAPIDES ──
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
        children: [
          _statCard(_formatNumber(_totalSteps), 'Total pas',
              Icons.directions_walk_rounded, AppColors.activeBlue),

          _statCard('${_activeDays}j', 'Jours actifs',
              Icons.calendar_today_rounded, AppColors.energyOrange),

          _statCard(_formatNumber(_avgSteps.toInt()), 'Moy. / jour',
              Icons.bar_chart_rounded, AppColors.successGreen),

          _statCard(_goalsAchieved.toString(), 'Objectifs',
              Icons.emoji_events_rounded, const Color(0xFF9B59B6)),
        ],
      ),
    );
  }

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
          ),
        ],
      ),
    );
  }

  // ── CALENDRIER THERMIQUE ──
  Widget _buildHeatmapCalendar() {
    final days30 = _dailyData.length >= 30
        ? _dailyData.sublist(_dailyData.length - 30)
        : _dailyData;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                  'Calendrier d\'activité',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '30 derniers jours',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: days30.length,
              itemBuilder: (context, index) {
                final day = days30[index];
                final progress = day['progress'] as double;
                final steps = day['steps'] as int;
                final date = day['date'] as DateTime;

                Color cellColor;
                if (progress == 0) {
                  cellColor = Colors.white.withValues(alpha: 0.05);
                } else if (progress < 0.3) {
                  cellColor =
                      AppColors.energyOrange.withValues(alpha: 0.2);
                } else if (progress < 0.6) {
                  cellColor =
                      AppColors.energyOrange.withValues(alpha: 0.45);
                } else if (progress < 1.0) {
                  cellColor =
                      AppColors.energyOrange.withValues(alpha: 0.7);
                } else {
                  cellColor = AppColors.energyOrange;
                }

                return Tooltip(
                  message:
                      '${date.day}/${date.month} — $steps pas',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: cellColor,
                      boxShadow: progress >= 1.0
                          ? [
                              BoxShadow(
                                color: AppColors.energyOrange
                                    .withValues(alpha: 0.4),
                                blurRadius: 4,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Inactif',
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
                  'Objectif atteint',
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
      ),
    );
  }

  // ── GRAPHIQUE BARRES HEBDOMADAIRE ──
  Widget _buildWeeklyBarChart() {
    final weekly = _weeklyData;
    if (weekly.isEmpty) return const SizedBox();
    final maxVal = weekly
        .map((w) => w['total'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1A2A3A),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pas par semaine',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'S${v.toInt() + 1}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color:
                                  Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  barGroups: weekly.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: (e.value['total'] as int).toDouble(),
                          width: 32,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.activeBlue
                                  .withValues(alpha: 0.5),
                              AppColors.activeBlue,
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── COURBE MENSUELLE ──
  Widget _buildMonthlyLineChart() {
    if (_dailyData.length < 7) return const SizedBox();
    final spots = _dailyData.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), (e.value['steps'] as int).toDouble());
    }).toList();

    final maxY = _dailyData
        .map((d) => d['steps'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1A2A3A),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Évolution quotidienne',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  maxY: maxY * 1.2,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppColors.energyOrange,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.energyOrange
                                .withValues(alpha: 0.3),
                            AppColors.energyOrange
                                .withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LISTE JOURS ──
  Widget _buildDaysList() {
    final reversed = _dailyData.reversed.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détail par jour',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...reversed.map((day) => _buildDayCard(day)),
        ],
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final date = day['date'] as DateTime;
    final steps = day['steps'] as int;
    final progress = day['progress'] as double;
    final achieved = day['achieved'] as bool;
    final goal = day['goal'] as int;

    final isToday = _isToday(date);
    final color = achieved
        ? AppColors.successGreen
        : steps > 0
            ? AppColors.energyOrange
            : Colors.white.withValues(alpha: 0.1);

    return GestureDetector(
      onTap: () => _showDayDetail(day),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isToday
              ? AppColors.activeBlue.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: isToday
                ? AppColors.activeBlue.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Date
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    _getDayName(date),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? AppColors.activeBlue
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color:
                          isToday ? AppColors.activeBlue : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Barre progression
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatNumber(steps)} pas',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (achieved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✅ Objectif',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toInt()}% de $goal pas',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_right_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showDayDetail(Map<String, dynamic> day) {
    HapticFeedback.lightImpact();
    final date = day['date'] as DateTime;
    final steps = day['steps'] as int;
    final goal = day['goal'] as int;
    final achieved = day['achieved'] as bool;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2A3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            const SizedBox(height: 20),
            Text(
              '${_getDayName(date)} ${date.day}/${date.month}/${date.year}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _detailStat(_formatNumber(steps), 'Pas',
                    Icons.directions_walk_rounded, AppColors.activeBlue),
                _detailStat(
                    '${(steps * 0.00075).toStringAsFixed(2)} km',
                    'Distance',
                    Icons.route_rounded,
                    AppColors.energyOrange),
                _detailStat(
                    '${(steps * 0.04).toStringAsFixed(0)} kcal',
                    'Calories',
                    Icons.local_fire_department_rounded,
                    AppColors.alertRed),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: achieved
                    ? AppColors.successGreen.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: achieved
                      ? AppColors.successGreen.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                achieved
                    ? '🎯 Objectif atteint ! ($goal pas)'
                    : '📊 Objectif non atteint ($goal pas visés)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: achieved
                      ? AppColors.successGreen
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailStat(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _getDayName(DateTime date) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[date.weekday - 1];
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }
}