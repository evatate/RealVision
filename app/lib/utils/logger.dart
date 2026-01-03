import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class AppLogger {
  static final Logger _logger = Logger('RealVision');

  static void init() {
    Logger.root.level = Level.ALL;

    Logger.root.onRecord.listen((record) {
      if (!kDebugMode) return;

      final message =
          '${record.level.name}: ${record.time}: ${record.message}';

      debugPrint(message);

      if (record.error != null) {
        debugPrint('Error: ${record.error}');
      }

      if (record.stackTrace != null) {
        debugPrint('StackTrace:\n${record.stackTrace}');
      }
    });
  }

  static Logger get logger => _logger;
}
