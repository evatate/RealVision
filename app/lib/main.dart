import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'models/test_progress.dart';
import 'utils/colors.dart';
import '../services/service_locator.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  setupServiceLocator();

  runApp(
    ChangeNotifierProvider(
      create: (context) => TestProgress(),
      child: const RealVisionApp(),
    ),
  );
}

class RealVisionApp extends StatelessWidget {
  const RealVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TestProgress(),
      child: MaterialApp(
        title: 'RealVision',
        debugShowCheckedModeBanner: false,
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
        home: const SplashScreen(),
      ),
    );
  }
}