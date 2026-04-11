import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../audio/data/datasources/audio_service.dart';
import '../../../audio/data/datasources/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Profil
  final _nameController = TextEditingController();
  double _weight = 70.0;
  double _height = 170.0;
  int _age = 25;
  String _gender = 'male';

  // Objectifs
  int _stepGoal = 10000;
  double _distanceGoal = 7.0;
  double _caloriesGoal = 500.0;
  int _durationGoal = 60;

  // Audio
  bool _soundEnabled = true;
  bool _ttsEnabled = true;
  double _volume = 0.8;

  // Notifications
  bool _reminderEnabled = false;
  int _reminderHour = 8;
  int _reminderMinute = 0;

  // Thème

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('user_profile_box');
    final audio = AudioService();
    await audio.initialize();
    final notifSettings = await NotificationService.loadSettings();

    setState(() {
      _nameController.text =
          box.get('user_name', defaultValue: 'Athlète');
      _weight = box.get('user_weight', defaultValue: 70.0);
      _height = box.get('user_height', defaultValue: 170.0);
      _age = box.get('user_age', defaultValue: 25);
      _gender = box.get('user_gender', defaultValue: 'male');
      _stepGoal = 
          (box.get('daily_step_goal', defaultValue: 10000) as int).clamp(1, 30000);
      _distanceGoal =
          box.get('daily_distance_goal', defaultValue: 7.0);
      _caloriesGoal =
          box.get('daily_calories_goal', defaultValue: 500.0);
      _durationGoal =
          box.get('daily_duration_goal', defaultValue: 60);
      _soundEnabled = audio.state.soundEnabled;
      _ttsEnabled = audio.state.ttsEnabled;
      _volume = audio.state.volume;
      _reminderEnabled =
          notifSettings['enabled'] as bool;
      _reminderHour = notifSettings['hour'] as int;
      _reminderMinute = notifSettings['minute'] as int;
      _loading = false;
    });
    _animController.forward();
  }

  Future<void> _saveProfile() async {
    final box = await Hive.openBox('user_profile_box');
    await box.putAll({
      'user_name': _nameController.text.trim().isEmpty
          ? 'Athlète'
          : _nameController.text.trim(),
      'user_weight': _weight,
      'user_height': _height,
      'user_age': _age,
      'user_gender': _gender,
      'daily_step_goal': _stepGoal,
      'daily_distance_goal': _distanceGoal,
      'daily_calories_goal': _caloriesGoal,
      'daily_duration_goal': _durationGoal,
    });

    final audio = AudioService();
    await audio.toggleSound(_soundEnabled);
    await audio.toggleTts(_ttsEnabled);
    await audio.setVolume(_volume);

    if (_reminderEnabled) {
      await NotificationService.scheduleDailyReminder(
        hour: _reminderHour,
        minute: _reminderMinute,
      );
    } else {
      await NotificationService.cancelAll();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ Paramètres sauvegardés !',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _resetData({required bool full}) async {
    final confirmed = await _showConfirmDialog(
      title: full ? 'Réinitialisation totale' : 'Réinitialisation partielle',
      message: full
          ? 'Toutes vos données (pas, sessions, badges, XP) seront supprimées. Cette action est irréversible.'
          : 'Seules les statistiques des 7 derniers jours seront effacées.',
      confirmLabel: 'Supprimer',
      confirmColor: AppColors.alertRed,
    );

    if (!confirmed) return;

    final box = await Hive.openBox('user_profile_box');

    if (full) {
      // Supprime tout
      final keysToDelete = box.keys
          .where((k) => k.toString().startsWith('daily_steps_'))
          .toList();
      await box.deleteAll(keysToDelete);
      await Hive.openBox('badges_box').then((b) => b.clear());
      await Hive.openBox('gamification_box').then((b) => b.clear());
      await Hive.openBox('gps_sessions').then((b) => b.clear());
      await Hive.openBox('heart_rate_box').then((b) => b.clear());
    } else {
      // Supprime les 7 derniers jours
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final key = 'daily_steps_${date.year}-${date.month}-${date.day}';
        await box.delete(key);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            full
                ? '🗑️ Toutes les données supprimées.'
                : '🗑️ Données des 7 derniers jours supprimées.',
            style: const TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2A3A),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: confirmColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded,
                    color: confirmColor, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color:
                                  Colors.white.withValues(alpha: 0.15)),
                        ),
                      ),
                      child: const Text(
                        'Annuler',
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
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
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.energyOrange))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),
                        _buildSection('👤 Profil', _buildProfileSection()),
                        const SizedBox(height: 16),
                        _buildSection('🎯 Objectifs journaliers',
                            _buildGoalsSection()),
                        const SizedBox(height: 16),
                        _buildSection(
                            '🔔 Rappel quotidien',
                            _buildNotificationSection()),
                        const SizedBox(height: 16),
                        _buildSection('🔊 Audio', _buildAudioSection()),
                        const SizedBox(height: 16),
                        _buildSection(
                            '🗑️ Gestion des données',
                            _buildDataSection()),
                        const SizedBox(height: 16),
                        _buildSection('ℹ️ À propos', _buildAboutSection()),
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return const SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: true,
      backgroundColor: Color(0xFF0D1B2A),
      leading: BackButton(color: Colors.white),
      title: Text(
        'Paramètres',
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

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF1A2A3A),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: content,
        ),
      ],
    );
  }

  // ── PROFIL ──
  Widget _buildProfileSection() {
    return Column(
      children: [
        _buildTextField('Prénom', _nameController,
            Icons.person_outline_rounded),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _genderBtn('male', Icons.male_rounded, 'Homme')),
            const SizedBox(width: 10),
            Expanded(
                child:
                    _genderBtn('female', Icons.female_rounded, 'Femme')),
          ],
        ),
        const SizedBox(height: 16),
        _buildSliderField(
            'Poids', '${_weight.toInt()} kg', _weight, 40, 150, (v) {
          setState(() => _weight = v);
        }),
        _buildSliderField(
            'Taille', '${_height.toInt()} cm', _height, 140, 220, (v) {
          setState(() => _height = v);
        }),
        _buildSliderField('Âge', '$_age ans', _age.toDouble(), 10, 80,
            (v) {
          setState(() => _age = v.toInt());
        }),
      ],
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(
          fontFamily: 'Inter', color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: AppColors.energyOrange, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.energyOrange, width: 2),
        ),
      ),
    );
  }

  Widget _genderBtn(String value, IconData icon, String label) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () {
        setState(() => _gender = value);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.energyOrange
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.energyOrange
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderField(String label, String value, double current,
      double min, double max, ValueChanged<double> onChanged) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.energyOrange,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.energyOrange,
            inactiveTrackColor:
                Colors.white.withValues(alpha: 0.1),
            thumbColor: Colors.white,
            overlayColor:
                AppColors.energyOrange.withValues(alpha: 0.2),
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 9),
            trackHeight: 4,
          ),
          child: Slider(
            value: current,
            min: min,
            max: max,
            onChanged: (v) {
              onChanged(v);
              HapticFeedback.selectionClick();
            },
          ),
        ),
      ],
    );
  }

  // ── OBJECTIFS ──
  Widget _buildGoalsSection() {
    return Column(
      children: [
        _goalRow('👟 Pas quotidiens', '$_stepGoal pas', () {
        _showGoalPicker(
          title: 'Objectif de pas',
          value: _stepGoal.toDouble(),
          min: 1,
          max: 30000,
          divisions: 599, // pas de 50 en 50
          unit: 'pas',
          onChanged: (v) =>
              setState(() => _stepGoal = v.round()),
        );
        }),
        const Divider(color: Colors.white10, height: 20),
        _goalRow('🗺️ Distance', '${_distanceGoal.toStringAsFixed(1)} km',
            () {
          _showGoalPicker(
            title: 'Objectif de distance',
            value: _distanceGoal,
            min: 1,
            max: 30,
            divisions: 58,
            unit: 'km',
            onChanged: (v) => setState(
                () => _distanceGoal = double.parse(v.toStringAsFixed(1))),
          );
        }),
        const Divider(color: Colors.white10, height: 20),
        _goalRow('🔥 Calories', '${_caloriesGoal.toInt()} kcal', () {
          _showGoalPicker(
            title: 'Objectif calories',
            value: _caloriesGoal,
            min: 100,
            max: 2000,
            divisions: 38,
            unit: 'kcal',
            onChanged: (v) =>
                setState(() => _caloriesGoal = (v / 50).round() * 50),
          );
        }),
        const Divider(color: Colors.white10, height: 20),
        _goalRow('⏱️ Durée', '$_durationGoal min', () {
          _showGoalPicker(
            title: 'Objectif durée',
            value: _durationGoal.toDouble(),
            min: 10,
            max: 180,
            divisions: 34,
            unit: 'min',
            onChanged: (v) =>
                setState(() => _durationGoal = (v / 5).round() * 5),
          );
        }),
      ],
    );
  }

  Widget _goalRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.energyOrange,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.edit_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

void _showGoalPicker({
  required String title,
  required double value,
  required double min,
  required double max,
  required int divisions,
  required String unit,
  required ValueChanged<double> onChanged,
}) {
  double tempValue = value.clamp(min, max);
  final TextEditingController inputController =
      TextEditingController(text: tempValue.toInt().toString());

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1A2A3A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Titre
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Valeur affichée grande
              Text(
                '${tempValue.toInt()} $unit',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.energyOrange,
                ),
              ),
              const SizedBox(height: 16),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.energyOrange,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: Colors.white,
                  trackHeight: 6,
                ),
                child: Slider(
                  value: tempValue,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: (v) {
                    setModalState(() {
                      tempValue = v;
                      inputController.text = v.toInt().toString();
                    });
                    onChanged(v);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Champ saisie manuelle
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Saisir manuellement',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                        suffixText: unit,
                        suffixStyle: const TextStyle(
                          color: AppColors.energyOrange,
                          fontWeight: FontWeight.w700,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.energyOrange, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (text) {
                        final parsed = double.tryParse(text);
                        if (parsed != null) {
                          final clamped = parsed.clamp(min, max);
                          setModalState(() => tempValue = clamped);
                          onChanged(clamped);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Bouton appliquer
                  GestureDetector(
                    onTap: () {
                      final parsed =
                          double.tryParse(inputController.text);
                      if (parsed != null) {
                        final clamped = parsed.clamp(min, max);
                        setModalState(() => tempValue = clamped);
                        onChanged(clamped);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.energyOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bouton confirmer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.energyOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Confirmer',
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
        ),
      ),
    ),
  );
}

  // ── NOTIFICATIONS ──
  Widget _buildNotificationSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rappel quotidien',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            Switch(
              value: _reminderEnabled,
              onChanged: (v) async {
                setState(() => _reminderEnabled = v);
                HapticFeedback.selectionClick();
                // Sauvegarde immédiate
                if (v) {
                  await NotificationService.scheduleDailyReminder(
                    hour: _reminderHour,
                    minute: _reminderMinute,
                  );
                } else {
                  await NotificationService.cancelAll();
                }
              },
              activeThumbColor: AppColors.energyOrange,
              inactiveThumbColor: Colors.white.withValues(alpha: 0.3),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            ),
          ],
        ),
        if (_reminderEnabled) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: _reminderHour, minute: _reminderMinute),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.energyOrange,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (time != null) {
                setState(() {
                  _reminderHour = time.hour;
                  _reminderMinute = time.minute;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.energyOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.energyOrange
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_rounded,
                      color: AppColors.energyOrange, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Rappel à ${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.energyOrange,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.edit_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── AUDIO ──
  Widget _buildAudioSection() {
    return Column(
      children: [
        _switchRow('Sons de récompense', '🔔', _soundEnabled,
            AppColors.energyOrange, (v) {
          setState(() => _soundEnabled = v);
        }),
        const Divider(color: Colors.white10, height: 20),
        _switchRow('Voix motivante', '🗣️', _ttsEnabled,
            AppColors.successGreen, (v) {
          setState(() => _ttsEnabled = v);
        }),
        const Divider(color: Colors.white10, height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🔊 Volume',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            Text(
              '${(_volume * 100).toInt()}%',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.energyOrange,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.energyOrange,
            inactiveTrackColor:
                Colors.white.withValues(alpha: 0.1),
            thumbColor: Colors.white,
            trackHeight: 4,
          ),
          child: Slider(
            value: _volume,
            min: 0,
            max: 1,
            onChanged: (v) {
              setState(() => _volume = v);
              HapticFeedback.selectionClick();
            },
          ),
        ),
      ],
    );
  }

  Widget _switchRow(String label, String emoji, bool value, Color color,
      ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: color,
          inactiveThumbColor:
              Colors.white.withValues(alpha: 0.3),
          inactiveTrackColor:
              Colors.white.withValues(alpha: 0.1),
        ),
      ],
    );
  }

  // ── DONNÉES ──
  Widget _buildDataSection() {
    return Column(
      children: [
        _dataRow(
          '🗑️ Réinitialiser 7 derniers jours',
          AppColors.energyOrange,
          () => _resetData(full: false),
        ),
        const Divider(color: Colors.white10, height: 20),
        _dataRow(
          '💣 Réinitialisation totale',
          AppColors.alertRed,
          () => _resetData(full: true),
        ),
      ],
    );
  }

  Widget _dataRow(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
        ],
      ),
    );
  }

  // ── À PROPOS ──
  Widget _buildAboutSection() {
    return Column(
      children: [
        _aboutRow('Version', '1.0.0'),
        const Divider(color: Colors.white10, height: 20),
        _aboutRow('Développeur', 'Freddy · Master 1 SIGL'),
        const Divider(color: Colors.white10, height: 20),
        _aboutRow('Framework', 'Flutter 3.x · Dart'),
        const Divider(color: Colors.white10, height: 20),
        _aboutRow('Architecture', 'Clean Architecture · Offline First'),
        const Divider(color: Colors.white10, height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '© 2025 MoveSense',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const Text(
              '🚀 Made with Flutter',
              style: TextStyle(fontSize: 12, color: AppColors.energyOrange),
            ),
          ],
        ),
      ],
    );
  }

  Widget _aboutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ── BOUTON SAUVEGARDER ──
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.energyOrange,
          elevation: 8,
          shadowColor: AppColors.energyOrange.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          'Sauvegarder les paramètres',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}