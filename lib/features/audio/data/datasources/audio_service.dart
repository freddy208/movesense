import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

// ═══════════════════════════════════════
// MODÈLE ÉTAT AUDIO
// ═══════════════════════════════════════
class AudioState {
  final bool soundEnabled;
  final bool musicEnabled;
  final bool ttsEnabled;
  final double volume;
  final String? currentMusicPath;
  final bool isPlaying;
  final List<String> playlist;

  const AudioState({
    this.soundEnabled = true,
    this.musicEnabled = false,
    this.ttsEnabled = true,
    this.volume = 0.8,
    this.currentMusicPath,
    this.isPlaying = false,
    this.playlist = const [],
  });

  AudioState copyWith({
    bool? soundEnabled,
    bool? musicEnabled,
    bool? ttsEnabled,
    double? volume,
    String? currentMusicPath,
    bool? isPlaying,
    List<String>? playlist,
  }) {
    return AudioState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      volume: volume ?? this.volume,
      currentMusicPath: currentMusicPath ?? this.currentMusicPath,
      isPlaying: isPlaying ?? this.isPlaying,
      playlist: playlist ?? this.playlist,
    );
  }
}

// ═══════════════════════════════════════
// SONS DISPONIBLES
// ═══════════════════════════════════════
enum AppSound {
  success,
  badge,
  levelUp,
  heartAlert,
}

extension AppSoundExt on AppSound {
  String get assetPath {
    switch (this) {
      case AppSound.success:
        return 'sounds/success.mp3';
      case AppSound.badge:
        return 'sounds/badge.mp3';
      case AppSound.levelUp:
        return 'sounds/level_up.mp3';
      case AppSound.heartAlert:
        return 'sounds/heart_alert.mp3';
    }
  }
}

// ═══════════════════════════════════════
// CITATIONS MOTIVANTES
// ═══════════════════════════════════════
class MotivationalQuotes {
  static const List<String> french = [
    "Chaque pas te rapproche de ton objectif.",
    "La régularité bat l'intensité. Continue !",
    "Ton corps peut le faire. C'est ton esprit qu'il faut convaincre.",
    "Un pas à la fois, une victoire à la fois.",
    "L'excellence n'est pas un acte, c'est une habitude.",
    "Aujourd'hui difficile, demain plus fort.",
    "Bouge maintenant, repose-toi plus tard.",
    "La douleur d'aujourd'hui est la force de demain.",
    "Ne t'arrête pas quand tu es fatigué. Arrête-toi quand tu as fini.",
    "Chaque matin est une nouvelle chance de devenir meilleur.",
    "Le succès est la somme de petits efforts répétés chaque jour.",
    "Tu es plus fort que tu ne le penses.",
    "Les champions s'entraînent quand personne ne regarde.",
    "Commence où tu es. Utilise ce que tu as. Fais ce que tu peux.",
    "La seule mauvaise séance est celle que tu n'as pas faite.",
    "Ton seul concurrent, c'est toi d'hier.",
    "Chaque pas compte. Ne sous-estime jamais ta progression.",
    "La persévérance transforme l'ordinaire en extraordinaire.",
    "Sois fier de chaque pas, chaque effort, chaque progrès.",
    "Le voyage de mille kilomètres commence par un seul pas.",
  ];

  static String get random {
    final index = DateTime.now().millisecondsSinceEpoch % french.length;
    return french[index];
  }

  static String get daily {
    final dayIndex = DateTime.now().day % french.length;
    return french[dayIndex];
  }
}

// ═══════════════════════════════════════
// AUDIO SERVICE
// ═══════════════════════════════════════
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();
  
  static const String _boxName = 'audio_box';

  // Players
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  AudioState _state = const AudioState();
  AudioState get state => _state;

  Timer? _bpmSyncTimer;

  // ── INITIALISATION ──
  Future<void> initialize() async {
    await _loadSettings();
    await _setupTts();
    _setupMusicPlayer();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox(_boxName);
    final playlist = List<String>.from(
      box.get('playlist', defaultValue: <String>[]),
    );
    _state = AudioState(
      soundEnabled: box.get('sound_enabled', defaultValue: true),
      musicEnabled: box.get('music_enabled', defaultValue: false),
      ttsEnabled: box.get('tts_enabled', defaultValue: true),
      volume: box.get('volume', defaultValue: 0.8),
      playlist: playlist,
    );
  }

  Future<void> _saveSettings() async {
    final box = await Hive.openBox(_boxName);
    await box.putAll({
      'sound_enabled': _state.soundEnabled,
      'music_enabled': _state.musicEnabled,
      'tts_enabled': _state.ttsEnabled,
      'volume': _state.volume,
      'playlist': _state.playlist,
    });
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(_state.volume);
    await _tts.setPitch(1.0);
  }

  void _setupMusicPlayer() {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    _musicPlayer.setVolume(_state.volume);
    _musicPlayer.onPlayerComplete.listen((_) => _playNextTrack());
  }

  // ── SONS SFX ──
  Future<void> playSound(AppSound sound) async {
    if (!_state.soundEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(_state.volume);
      await _sfxPlayer.play(AssetSource(sound.assetPath));
    } catch (e) {
      // Son non trouvé — silencieux
    }
  }

  // ── MUSIQUE ──
  Future<void> pickMusicFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();

    _state = _state.copyWith(
      playlist: [..._state.playlist, ...paths],
    );
    await _saveSettings();
  }

  Future<void> playMusic() async {
    if (_state.playlist.isEmpty) return;
    final path = _state.currentMusicPath ?? _state.playlist.first;
    await _musicPlayer.play(DeviceFileSource(path));
    _state = _state.copyWith(isPlaying: true, currentMusicPath: path);
  }

  Future<void> pauseMusic() async {
    await _musicPlayer.pause();
    _state = _state.copyWith(isPlaying: false);
  }

  Future<void> resumeMusic() async {
    await _musicPlayer.resume();
    _state = _state.copyWith(isPlaying: true);
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
    _state = _state.copyWith(isPlaying: false);
    _bpmSyncTimer?.cancel();
  }

  Future<void> _playNextTrack() async {
    if (_state.playlist.isEmpty) return;
    final currentIdx =
        _state.playlist.indexOf(_state.currentMusicPath ?? '');
    final nextIdx = (currentIdx + 1) % _state.playlist.length;
    final nextPath = _state.playlist[nextIdx];
    await _musicPlayer.play(DeviceFileSource(nextPath));
    _state = _state.copyWith(currentMusicPath: nextPath);
  }

  void syncMusicToPace(double paceMinKm) {
    
    // Allure rapide (< 6 min/km) → volume plus fort
    // Allure lente (> 10 min/km) → volume plus doux
    if (paceMinKm <= 0) return;
    double adjustedVolume;
    if (paceMinKm < 6) {
      adjustedVolume = (_state.volume * 1.1).clamp(0.0, 1.0);
    } else if (paceMinKm > 10) {
      adjustedVolume = (_state.volume * 0.8).clamp(0.0, 1.0);
    } else {
      adjustedVolume = _state.volume;
    }
    _musicPlayer.setVolume(adjustedVolume);
  }

  // ── TTS ──
  Future<void> speakQuote([String? quote]) async {
    if (!_state.ttsEnabled) return;
    final text = quote ?? MotivationalQuotes.random;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> speakMilestone(int steps) async {
    if (!_state.ttsEnabled) return;
    String message = '';
    if (steps == 1000) message = 'Mille pas ! Excellent début !';
    if (steps == 5000) message = 'Cinq mille pas ! Tu es en feu !';
    if (steps == 10000) message = 'Dix mille pas ! Objectif atteint ! Félicitations !';
    if (message.isNotEmpty) await _tts.speak(message);
  }

  Future<void> stopTts() async => await _tts.stop();

  // ── PARAMÈTRES ──
  Future<void> toggleSound(bool enabled) async {
    _state = _state.copyWith(soundEnabled: enabled);
    await _saveSettings();
  }

  Future<void> toggleMusic(bool enabled) async {
    _state = _state.copyWith(musicEnabled: enabled);
    if (!enabled) await stopMusic();
    await _saveSettings();
  }

  Future<void> toggleTts(bool enabled) async {
    _state = _state.copyWith(ttsEnabled: enabled);
    if (!enabled) await stopTts();
    await _saveSettings();
  }

  Future<void> setVolume(double volume) async {
    _state = _state.copyWith(volume: volume);
    await _sfxPlayer.setVolume(volume);
    await _musicPlayer.setVolume(volume);
    await _tts.setVolume(volume);
    await _saveSettings();
  }

  Future<void> clearPlaylist() async {
    await stopMusic();
    _state = _state.copyWith(playlist: [], currentMusicPath: null);
    await _saveSettings();
  }

  void dispose() {
    _sfxPlayer.dispose();
    _musicPlayer.dispose();
    _tts.stop();
    _bpmSyncTimer?.cancel();
  }
}