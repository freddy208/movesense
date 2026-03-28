import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/audio_service.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  bool _initialized = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _init();
  }

  Future<void> _init() async {
    await _audioService.initialize();
    setState(() => _initialized = true);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Audio & Motivation',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: !_initialized
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.energyOrange))
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  children: [
                    _buildToggleCard(),
                    const SizedBox(height: 16),
                    _buildVolumeCard(),
                    const SizedBox(height: 16),
                    _buildSoundsCard(),
                    const SizedBox(height: 16),
                    _buildMusicCard(),
                    const SizedBox(height: 16),
                    _buildTtsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── TOGGLES PRINCIPAUX ──
  Widget _buildToggleCard() {
    final s = _audioService.state;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A2A3A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          _toggleRow(
            emoji: '🔔',
            label: 'Sons de récompense',
            subtitle: 'Feedback sonore lors des succès',
            value: s.soundEnabled,
            color: AppColors.energyOrange,
            onChanged: (v) async {
              await _audioService.toggleSound(v);
              setState(() {});
              if (v) await _audioService.playSound(AppSound.success);
            },
          ),
          const Divider(color: Colors.white10, height: 24),
          _toggleRow(
            emoji: '🎵',
            label: 'Musique pendant la session',
            subtitle: 'Lecture de votre playlist personnelle',
            value: s.musicEnabled,
            color: AppColors.activeBlue,
            onChanged: (v) async {
              await _audioService.toggleMusic(v);
              setState(() {});
            },
          ),
          const Divider(color: Colors.white10, height: 24),
          _toggleRow(
            emoji: '🗣️',
            label: 'Voix motivante',
            subtitle: 'Citations lues à voix haute en français',
            value: s.ttsEnabled,
            color: AppColors.successGreen,
            onChanged: (v) async {
              await _audioService.toggleTts(v);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String emoji,
    required String label,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: color,
          inactiveThumbColor: Colors.white.withValues(alpha: 0.3),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        ),
      ],
    );
  }

  // ── VOLUME ──
  Widget _buildVolumeCard() {
    final volume = _audioService.state.volume;
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
              const Text('🔊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              const Text(
                'Volume',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${(volume * 100).toInt()}%',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.energyOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.energyOrange,
              inactiveTrackColor:
                  Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor:
                  AppColors.energyOrange.withValues(alpha: 0.2),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 5,
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              onChanged: (v) async {
                await _audioService.setVolume(v);
                setState(() {});
                HapticFeedback.selectionClick();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── SONS SFX ──
  Widget _buildSoundsCard() {
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
          const Text(
            'Tester les sons',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: [
              _soundButton('🎯 Succès', AppSound.success,
                  AppColors.successGreen),
              _soundButton(
                  '🏆 Badge', AppSound.badge, AppColors.energyOrange),
              _soundButton('⬆️ Niveau', AppSound.levelUp,
                  const Color(0xFF9B59B6)),
              _soundButton('❤️ Alerte', AppSound.heartAlert,
                  AppColors.alertRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _soundButton(String label, AppSound sound, Color color) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await _audioService.playSound(sound);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  // ── MUSIQUE ──
  Widget _buildMusicCard() {
    final s = _audioService.state;
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
                '🎵 Ma Playlist',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '${s.playlist.length} titre(s)',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Boutons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.add_rounded,
                  label: 'Ajouter',
                  color: AppColors.activeBlue,
                  onTap: () async {
                    await _audioService.pickMusicFiles();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: s.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: s.isPlaying ? 'Pause' : 'Jouer',
                  color: AppColors.successGreen,
                  onTap: () async {
                    if (s.isPlaying) {
                      await _audioService.pauseMusic();
                    } else {
                      await _audioService.playMusic();
                    }
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Vider',
                  color: AppColors.alertRed,
                  onTap: () async {
                    await _audioService.clearPlaylist();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),

          // Liste fichiers
          if (s.playlist.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...s.playlist.take(3).map((path) {
              final name = path.split('/').last;
              final isCurrent = s.currentMusicPath == path;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.activeBlue.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.activeBlue.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCurrent
                          ? Icons.music_note_rounded
                          : Icons.audio_file_rounded,
                      color: isCurrent
                          ? AppColors.activeBlue
                          : Colors.white.withValues(alpha: 0.3),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: isCurrent
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (s.playlist.length > 3)
              Text(
                '+${s.playlist.length - 3} autre(s) titre(s)',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── TTS ──
  Widget _buildTtsCard() {
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
          const Text(
            '🗣️ Voix Motivante',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.successGreen.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '"${MotivationalQuotes.daily}"',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Lire la citation',
                  color: AppColors.successGreen,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await _audioService.speakQuote(
                        MotivationalQuotes.daily);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.stop_rounded,
                  label: 'Arrêter',
                  color: AppColors.alertRed,
                  onTap: () async {
                    await _audioService.stopTts();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}