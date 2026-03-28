import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/presentation/screens/main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Formulaire profil
  final _nameController = TextEditingController();
  double _weight = 70.0;
  double _height = 170.0;
  int _age = 25;
  String _gender = 'male';
  int _dailyStepGoal = 10000;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _saveAndContinue();
    }
  }

  Future<void> _saveAndContinue() async {
    final box = Hive.box(AppConstants.userProfileBox);
    final strideLength = UserProfileHelper.calculateStrideLength(
      _height,
      _gender,
    );

    await box.put(AppConstants.onboardingDoneKey, true);
    await box.put(AppConstants.userNameKey, _nameController.text.trim().isEmpty
        ? 'Athlète' : _nameController.text.trim());
    await box.put(AppConstants.userWeightKey, _weight);
    await box.put(AppConstants.userHeightKey, _height);
    await box.put(AppConstants.userAgeKey, _age);
    await box.put(AppConstants.userGenderKey, _gender);
    await box.put(AppConstants.userStrideLengthKey, strideLength);
    await box.put(AppConstants.dailyStepGoalKey, _dailyStepGoal);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D2137), Color(0xFF1A3A5C), Color(0xFF1E4976)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header avec skip
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo petit
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.energyOrange.withOpacity(0.6),
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/movesense_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'MoveSense',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      // Indicateur étape
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          '${_currentPage + 1} / 3',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      HapticFeedback.lightImpact();
                    },
                    children: [
                      _buildWelcomePage(),
                      _buildProfilePage(),
                      _buildGoalPage(),
                    ],
                  ),
                ),

                // Bottom navigation
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      // Page indicator
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: 3,
                        effect: ExpandingDotsEffect(
                          activeDotColor: AppColors.energyOrange,
                          dotColor: Colors.white.withOpacity(0.3),
                          dotHeight: 8,
                          dotWidth: 8,
                          expansionFactor: 3,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bouton suivant
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.energyOrange,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor:
                                AppColors.energyOrange.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _currentPage == 2 ? 'Commencer !' : 'Continuer',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // PAGE 1 — BIENVENUE
  // ═══════════════════════════════════════
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration centrale
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.activeBlue.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cercles concentriques animés
                ...List.generate(3, (i) {
                  return Container(
                    width: 80.0 + i * 40,
                    height: 80.0 + i * 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.energyOrange.withOpacity(0.15 - i * 0.04),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
                // Icône centrale
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.energyOrange,
                        AppColors.energyOrange.withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.energyOrange.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_walk_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Titre
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFB8D4F0)],
            ).createShader(bounds),
            child: const Text(
              'Bienvenue sur\nMoveSense',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Transformez chaque pas en victoire.\nSuivez, analysez et dépassez vos limites\navec votre coach fitness personnel.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Colors.white.withOpacity(0.75),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),

          // Features chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _featureChip(Icons.gps_fixed_rounded, 'GPS Tracking'),
              _featureChip(Icons.favorite_rounded, 'BPM Live'),
              _featureChip(Icons.emoji_events_rounded, 'Gamification'),
              _featureChip(Icons.psychology_rounded, 'IA Embarquée'),
              _featureChip(Icons.wifi_off_rounded, '100% Offline'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.energyOrange, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // PAGE 2 — PROFIL
  // ═══════════════════════════════════════
  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFB8D4F0)],
            ).createShader(bounds),
            child: const Text(
              'Votre profil',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ces données permettent de calculer précisément\nvos calories et votre distance.',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Nom
          _buildLabel('Prénom'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hint: 'Ex: Freddy',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 20),

          // Genre
          _buildLabel('Genre'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _genderButton('male', Icons.male_rounded, 'Homme'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _genderButton('female', Icons.female_rounded, 'Femme'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Poids
          _buildLabel('Poids  •  ${_weight.toStringAsFixed(0)} kg'),
          const SizedBox(height: 4),
          _buildSlider(
            value: _weight,
            min: 40,
            max: 150,
            divisions: 110,
            onChanged: (v) => setState(() => _weight = v),
          ),

          // Taille
          _buildLabel('Taille  •  ${_height.toStringAsFixed(0)} cm'),
          const SizedBox(height: 4),
          _buildSlider(
            value: _height,
            min: 140,
            max: 220,
            divisions: 80,
            onChanged: (v) => setState(() => _height = v),
          ),

          // Âge
          _buildLabel('Âge  •  $_age ans'),
          const SizedBox(height: 4),
          _buildSlider(
            value: _age.toDouble(),
            min: 10,
            max: 80,
            divisions: 70,
            onChanged: (v) => setState(() => _age = v.toInt()),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // PAGE 3 — OBJECTIF
  // ═══════════════════════════════════════
  Widget _buildGoalPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFB8D4F0)],
            ).createShader(bounds),
            child: const Text(
              'Votre objectif\nquotidien',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Combien de pas souhaitez-vous\nfaire chaque jour ?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              color: Colors.white.withOpacity(0.65),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Affichage objectif
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.energyOrange.withOpacity(0.25),
                  AppColors.energyOrange.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: AppColors.energyOrange.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.energyOrange.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _formatSteps(_dailyStepGoal),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'pas / jour',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    color: AppColors.energyOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Slider objectif
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.energyOrange,
              inactiveTrackColor: Colors.white.withOpacity(0.15),
              thumbColor: Colors.white,
              overlayColor: AppColors.energyOrange.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 6,
            ),
            child: Slider(
              value: _dailyStepGoal.toDouble(),
              min: 2000,
              max: 30000,
              divisions: 56,
              onChanged: (v) {
                setState(() => _dailyStepGoal = (v / 500).round() * 500);
                HapticFeedback.selectionClick();
              },
            ),
          ),
          const SizedBox(height: 8),

          // Presets rapides
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _goalPreset(5000, 'Léger'),
              _goalPreset(8000, 'Modéré'),
              _goalPreset(10000, 'Actif'),
              _goalPreset(15000, 'Sportif'),
            ],
          ),
          const SizedBox(height: 32),

          // Info OMS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.successGreen.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.successGreen,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "L'OMS recommande 10 000 pas/jour pour une bonne santé cardiovasculaire.",
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // WIDGETS UTILITAIRES
  // ═══════════════════════════════════════

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontFamily: 'Inter',
        color: Colors.white,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(icon, color: AppColors.energyOrange, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.energyOrange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _genderButton(String value, IconData icon, String label) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () {
        setState(() => _gender = value);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.energyOrange
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.energyOrange
                : Colors.white.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.energyOrange.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
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
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.energyOrange,
        inactiveTrackColor: Colors.white.withOpacity(0.15),
        thumbColor: Colors.white,
        overlayColor: AppColors.energyOrange.withOpacity(0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        trackHeight: 5,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: (v) {
          onChanged(v);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }

  Widget _goalPreset(int steps, String label) {
    final isSelected = _dailyStepGoal == steps;
    return GestureDetector(
      onTap: () {
        setState(() => _dailyStepGoal = steps);
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.energyOrange
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.energyOrange
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Text(
              _formatSteps(steps),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(steps % 1000 == 0 ? 0 : 1)}k';
    }
    return steps.toString();
  }
}

class UserProfileHelper {
  static double calculateStrideLength(double heightCm, String gender) {
    return gender == 'male'
        ? heightCm * 0.415 / 100
        : heightCm * 0.413 / 100;
  }
}