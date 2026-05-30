import 'dart:io';
import 'package:flutter/foundation.dart';

/// Log levels following standard logging conventions.
enum LogLevel { debug, info, warn, error }

/// Centralized logging utility for the application.
///
/// All modules should use this instead of raw `debugPrint` to ensure
/// consistent log output and optional file persistence.
class AppLogger {
  AppLogger._();

  static LogLevel _minLevel = LogLevel.debug;
  static bool _logToFile = false;
  static String? _logFilePath;
  static DateTime? _logDate;

  /// Initialize the logger with optional file output.
  /// Call this once at app startup.
  static void init({
    LogLevel minLevel = LogLevel.debug,
    bool logToFile = false,
    String? logDirectory,
  }) {
    _minLevel = minLevel;
    _logToFile = logToFile;
    _logDate = DateTime.now();

    if (_logToFile && logDirectory != null) {
      final timestamp = _logDate!
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final dir = Directory(logDirectory);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _logFilePath = '$logDirectory/app_$timestamp.log';
    }
  }

  /// Set a custom log file path (must be called before init if using file logging).
  static void setLogFile(String path) {
    _logFilePath = path;
    _logToFile = true;
  }

  static String _levelTag(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warn:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  static void _write(String tag, String module, String message) {
    final line = '[$tag] [$_timestamp()] [$module] $message';

    // Always print to console in debug mode
    if (kDebugMode) {
      // ignore: avoid_print
      print('[$tag] [${_timestamp()}] [$module] $message');
    }

    // Write to file if enabled
    if (_logToFile && _logFilePath != null) {
      try {
        final file = File(_logFilePath!);
        file.writeAsStringSync('$line\n', mode: FileMode.append);
      } catch (_) {
        // Silently ignore file write errors to avoid recursive exceptions
      }
    }
  }

  /// Log a debug message.
  static void debug(String module, String message) {
    if (LogLevel.debug.index >= _minLevel.index) {
      _write('D', module, message);
    }
  }

  /// Log an info message.
  static void info(String module, String message) {
    if (LogLevel.info.index >= _minLevel.index) {
      _write('I', module, message);
    }
  }

  /// Log a warning message.
  static void warn(String module, String message) {
    if (LogLevel.warn.index >= _minLevel.index) {
      _write('W', module, message);
    }
  }

  /// Log an error message.
  static void error(String module, String message) {
    if (LogLevel.error.index >= _minLevel.index) {
      _write('E', module, message);
    }
  }
}
