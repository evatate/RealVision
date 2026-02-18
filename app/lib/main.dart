import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/test_progress.dart';
import 'services/progress_storage_service.dart';
import 'utils/colors.dart';
import '../services/service_locator.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/aws_auth_service.dart';
import 'utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  AppLogger.init();

  setupServiceLocator();

  /// Initialize user authentication service
  final awsAuth = getIt<AWSAuthService>();
  await awsAuth.initialize();

  // Load progress from shared preferences
  final loadedProgress = await ProgressStorageService.loadProgress();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://14308657c583e95ba6608a84d8c61626@o4510903463772160.ingest.us.sentry.io/4510903468621824';
      // Adds request headers and IP for users, for more info visit:
      // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
      options.sendDefaultPii = true;
      options.enableLogs = true;
      // Set tracesSampleRate to 0.5 to capture 50% of transactions for tracing.
      options.tracesSampleRate = 0.5;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 0.5 will profile 50% of sampled transactions:
      options.profilesSampleRate = 0.5;
      // Configure Session Replay
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(SentryWidget(child: RealVisionApp(progress: PersistentTestProgress(loadedProgress)))),
  );
}

class RealVisionApp extends StatelessWidget {
  final PersistentTestProgress progress;
  const RealVisionApp({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TestProgress>.value(
      value: progress,
      child: MaterialApp(
        title: 'RealVision',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [
          SentryNavigatorObserver(),
        ],
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Roboto',
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textDark),
            displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textDark),
            bodyLarge: TextStyle(fontSize: 24, color: AppColors.textDark),
            bodyMedium: TextStyle(fontSize: 20, color: AppColors.textDark),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        routes: {
          '/home': (context) => const HomeScreen(),
        },
        home: const SplashScreen(),
      ),
    );
  }
}