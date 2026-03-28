import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/audio/data/datasources/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialiser Hive
  await Hive.initFlutter();

  // Ouvrir toutes les boxes nécessaires
  await Future.wait([
    Hive.openBox(AppConstants.userProfileBox),
    Hive.openBox(AppConstants.appSettingsBox),
    Hive.openBox('gamification_box'),
    Hive.openBox('badges_box'),
    Hive.openBox('gps_sessions'),
    Hive.openBox('heart_rate_box'),
    Hive.openBox('audio_box'),
    Hive.openBox('notifications_box'),
  ]);

  // Initialiser les notifications
  await NotificationService.initialize();

  runApp(const ProviderScope(child: MoveSenseApp()));
}

class MoveSenseApp extends ConsumerWidget {
  const MoveSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}