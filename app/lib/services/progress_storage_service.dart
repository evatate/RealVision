import 'package:shared_preferences/shared_preferences.dart';
import '../models/test_progress.dart';
import 'dart:convert';

class ProgressStorageService {
  static const _key = 'test_progress';

  static Future<void> saveProgress(TestProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(progress.toMap());
    await prefs.setString(_key, json);
  }

  static Future<TestProgress> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      return TestProgress.fromMap(jsonDecode(json));
    } else {
      return TestProgress();
    }
  }
}
