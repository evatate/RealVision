import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'models/test_progress.dart';
import 'utils/colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RealVisionApp());
}

class RealVisionApp extends StatelessWidget {
  const RealVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TestProgress(),
      child: MaterialApp(
        title: 'RealVision',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Roboto',
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            bodyLarge: TextStyle(fontSize: 24),
            bodyMedium: TextStyle(fontSize: 20),
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
        home: const HomeScreen(),
      ),
    );
  }
}