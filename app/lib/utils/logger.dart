import 'package:logging/logging.dart';

class AppLogger {
  static final Logger _logger = Logger('RealVision');

  static void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // Need to replace print with logging framework
      // For now, print to console as development fallback
      final message = '${record.level.name}: ${record.time}: ${record.message}';
      // ignore: avoid_print
      print(message);
      if (record.error != null) {
        // ignore: avoid_print
        print('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('StackTrace: ${record.stackTrace}');
      }
    });
  }

  static Logger get logger => _logger;
}