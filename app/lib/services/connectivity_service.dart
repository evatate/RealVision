import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/colors.dart';

class ConnectivityService {
  static const String _testUrl = 'http://example.com';

  /// Check if device has internet connectivity by attempting to reach example.com
  static Future<bool> hasInternetConnection() async {
    try {
      final response = await http.get(Uri.parse(_testUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Show a dialog informing user they need internet connection
  static void showNoInternetDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red[700], size: 40),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'No Internet Connection',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'This app requires an internet connection to function properly. Please check your WiFi or cellular connection and try again.',
            style: TextStyle(fontSize: 18, color: AppColors.textDark),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  // Optionally retry the connection check here
                },
                child: const Text('OK', style: TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Check connectivity and show dialog if no connection
  static Future<bool> checkConnectivityAndShowDialog(BuildContext context) async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      showNoInternetDialog(context);
    }
    return hasConnection;
  }
}