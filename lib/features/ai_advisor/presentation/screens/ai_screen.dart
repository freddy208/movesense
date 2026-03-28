import 'dart:math';

import 'package:Movesense/core/utils/app_state_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/ai_advisor_service.dart';

class AIScreen extends ConsumerStatefulWidget {
  const AIScreen({super.key});
  @override
  ConsumerState<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends ConsumerState<AIScreen> with TickerProviderStateMixin {
  final AIAdvisorService _service = AIAdvisorService();
  AIReport? _report;
  bool _loading = true;

  late AnimationController _scoreController;
  late AnimationController _cardsController;
  late Animation<double> _scoreAnimation;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadReport();
  }

  void _setupAnimations() {
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scoreAnimation = CurvedAnimation(
      parent: _scoreController,
      curve: Curves.elasticOut,
    );

    _cardAnimations = List.generate(6, (i) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _cardsController,
        curve: Interval(
          i * 0.1,
          0.6 + i * 0.07,
          curve: Curves.easeOutCubic,
        ),
      ));
    });
  }

  Future<void> _loadReport() async {
    final report = await _service.generateReport();
    setState(() {
      _report = report;
      _loading = false;
    });
    await _scoreController.forward();
    await _cardsController.forward();
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    _scoreController.reset();
    _cardsController.reset();
    await _loadReport();
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionRefreshProvider, (_, __) => _refresh());
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _loading
          ? _buildLoading()
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),
                      SlideTransition(
                        position: _cardAnimations[0],
                        child: _buildScoreCard(),
                      ),
                      const SizedBox(height: 16),
                      SlideTransition(
                        position: _cardAnimations[1],
                        child: _buildPredictionCard(),
                      ),
                      const SizedBox(height: 16),
                      SlideTransition(
                        position: _cardAnimations[2],
                        child: _buildWeeklyChart(),
                      ),
                      const SizedBox(height: 16),
                      SlideTransition(
                        position: _cardAnimations[3],
                        child: _buildAdvicesSection(),
                      ),
                      const SizedBox(height: 16),
                      SlideTransition(
                        position: _cardAnimations[4],
                        child: _buildTrendCard(),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // ── LOADING ──
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.energyOrange),
          const SizedBox(height: 20),
          Text(
            'Analyse en cours...',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
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
        'IA & Conseils',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppColors.energyOrange),
          onPressed: _refresh,
        ),
      ],
    );
  }

  // ── SCORE SANTÉ ──
  Widget _buildScoreCard() {
    final report = _report!;
    final score = report.healthScore;

    Color scoreColor;
    if (score >= 70) {
      scoreColor = AppColors.successGreen;
    } else if (score >= 40) {
      scoreColor = AppColors.energyOrange;
    } else {
      scoreColor = AppColors.alertRed;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scoreColor.withValues(alpha: 0.2),
            scoreColor.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.15),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Score Santé',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aujourd\'hui',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: scoreColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  report.healthLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Score animé
          ScaleTransition(
            scale: _scoreAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3 composantes du score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _scoreComponent('Moyenne', '${(report.weeklySteps.isEmpty ? 0 : report.weeklySteps.reduce((a, b) => a + b) / report.weeklySteps.length).toInt()}', '👟'),
              _scoreDivider(),
              _scoreComponent('Régularité', '${report.weeklySteps.where((s) => s > 0).length}/7', '📅'),
              _scoreDivider(),
              _scoreComponent('Tendance', report.trend > 0 ? '+${report.trend.toInt()}%' : '${report.trend.toInt()}%', report.trend > 0 ? '📈' : '📉'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreComponent(String label, String value, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
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
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _scoreDivider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withValues(alpha: 0.08),
      );

  // ── PRÉDICTION OBJECTIF ──
  Widget _buildPredictionCard() {
    final report = _report!;
    final percent = (report.goalPrediction * 100).toInt();

    Color predColor;
    if (percent >= 70) {
      predColor = AppColors.successGreen;
    } else if (percent >= 40) {
      predColor = AppColors.energyOrange;
    } else {
      predColor = AppColors.alertRed;
    }

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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: predColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🎯', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prédiction objectif du jour',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Basé sur vos 7 derniers jours',
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
                '$percent%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: predColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: report.goalPrediction,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(predColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.predictionMessage,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── GRAPHIQUE 7 JOURS ──
  Widget _buildWeeklyChart() {
    final report = _report!;
    final steps = report.weeklySteps;
    final maxSteps = steps.isEmpty
        ? 10000
        : steps.reduce(max).toDouble();

    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final today = DateTime.now().weekday - 1;

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
                'Activité — 7 derniers jours',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.activeBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${steps.where((s) => s > 0).length} jours actifs',
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
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxSteps * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        const Color(0xFF1A3A5C),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${steps[group.x].toString()} pas',
                        const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        final dayIdx =
                            (today - 6 + idx + 7) % 7;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            days[dayIdx],
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: idx == 6
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: idx == 6
                                  ? AppColors.energyOrange
                                  : Colors.white
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(steps.length, (i) {
                  final isToday = i == steps.length - 1;
                  final value = steps[i].toDouble();
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isToday
                              ? [
                                  AppColors.energyOrange
                                      .withValues(alpha: 0.7),
                                  AppColors.energyOrange,
                                ]
                              : [
                                  AppColors.activeBlue
                                      .withValues(alpha: 0.4),
                                  AppColors.activeBlue
                                      .withValues(alpha: 0.8),
                                ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3 CONSEILS IA ──
  Widget _buildAdvicesSection() {
    final report = _report!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.activeBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: AppColors.activeBlue, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Conseils personnalisés',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.activeBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${report.advices.length} conseils',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.activeBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...report.advices
            .asMap()
            .entries
            .map((e) => _buildAdviceCard(e.value, e.key)),
      ],
    );
  }

  Widget _buildAdviceCard(AIAdvice advice, int index) {
    final colors = [
      AppColors.activeBlue,
      AppColors.energyOrange,
      AppColors.successGreen,
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                advice.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice.title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  advice.message,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TENDANCE ──
  Widget _buildTrendCard() {
    final report = _report!;
    final isPositive = report.trend >= 0;
    final trendColor =
        isPositive ? AppColors.successGreen : AppColors.alertRed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A2A3A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: trendColor.withValues(alpha: 0.15),
              border: Border.all(
                  color: trendColor.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: trendColor,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? 'Tendance en hausse' : 'Tendance en baisse',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPositive
                      ? 'Votre activité s\'améliore par rapport à la semaine dernière. Continuez !'
                      : 'Votre activité a légèrement baissé. Reprenez le rythme !',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${report.trend.toStringAsFixed(1)}%',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}