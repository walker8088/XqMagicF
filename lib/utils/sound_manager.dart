import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 音效管理器：走子、吃子、将军等音效
class SoundManager {
  SoundManager._();

  static SoundManager? _instance;
  static SoundManager get instance => _instance ??= SoundManager._();

  bool _enabled = true;
  double _volume = 0.7;
  bool _initialized = false;

  // 音效文件路径
  String? _moveSoundPath;
  String? _captureSoundPath;
  String? _checkSoundPath;
  String? _winSoundPath;
  String? _loseSoundPath;

  // 音频播放器（简化版：使用 Platform API）
  bool get enabled => _enabled;
  double get volume => _volume;

  /// 初始化音效
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 尝试从 assets 加载音效文件
      final dir = await getApplicationSupportDirectory();
      final soundsDir = Directory('${dir.path}/sounds');
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      // 默认音效路径
      _moveSoundPath = '${soundsDir.path}/move.wav';
      _captureSoundPath = '${soundsDir.path}/capture.wav';
      _checkSoundPath = '${soundsDir.path}/check.wav';
      _winSoundPath = '${soundsDir.path}/win.wav';
      _loseSoundPath = '${soundsDir.path}/lose.wav';

      // 如果音效文件不存在，创建默认音效（蜂鸣）
      await _createDefaultSounds(soundsDir);

      _initialized = true;
    } catch (_) {
      // 音效初始化失败，静默处理
      _initialized = true;
    }
  }

  /// 创建默认音效文件（简单的 WAV 蜂鸣）
  Future<void> _createDefaultSounds(Directory soundsDir) async {
    // 如果 move.wav 不存在，创建一个简单的蜂鸣
    final moveFile = File('${soundsDir.path}/move.wav');
    if (!await moveFile.exists()) {
      await moveFile.writeAsBytes(_generateBeep(440, 100)); // A4, 100ms
    }

    final captureFile = File('${soundsDir.path}/capture.wav');
    if (!await captureFile.exists()) {
      await captureFile.writeAsBytes(_generateBeep(660, 150)); // E5, 150ms
    }

    final checkFile = File('${soundsDir.path}/check.wav');
    if (!await checkFile.exists()) {
      await checkFile.writeAsBytes(_generateBeep(880, 200)); // A5, 200ms
    }
  }

  /// 生成简单 WAV 蜂鸣（44.1kHz, 16-bit, mono）
  List<int> _generateBeep(int frequency, int durationMs) {
    const sampleRate = 44100;
    const bitsPerSample = 16;
    const numChannels = 1;

    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    final fileSize = 44 + dataSize;

    final bytes = BytesBuilder();

    // WAV header
    bytes.addByte(0x52); // 'R'
    bytes.addByte(0x49); // 'I'
    bytes.addByte(0x46); // 'F'
    bytes.addByte(0x46); // 'F'
    _writeInt32(bytes, fileSize - 8); // File size - 8
    bytes.addByte(0x57); // 'W'
    bytes.addByte(0x41); // 'A'
    bytes.addByte(0x56); // 'V'
    bytes.addByte(0x45); // 'E'
    bytes.addByte(0x66); // 'f'
    bytes.addByte(0x6D); // 'm'
    bytes.addByte(0x74); // 't'
    bytes.addByte(0x20); // ' '
    _writeInt32(bytes, 16); // Subchunk1 size (PCM)
    _writeInt16(bytes, 1); // Audio format (PCM)
    _writeInt16(bytes, numChannels);
    _writeInt32(bytes, sampleRate);
    _writeInt32(
      bytes,
      sampleRate * numChannels * bitsPerSample ~/ 8,
    ); // Byte rate
    _writeInt16(bytes, numChannels * bitsPerSample ~/ 8); // Block align
    _writeInt16(bytes, bitsPerSample);
    bytes.addByte(0x64); // 'd'
    bytes.addByte(0x61); // 'a'
    bytes.addByte(0x74); // 't'
    bytes.addByte(0x61); // 'a'
    _writeInt32(bytes, dataSize);

    // Audio data (sine wave with fade out)
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final fadeOut = 1.0 - (i / numSamples);
      final sample =
          (32767 * 0.5 * fadeOut * (1 + _sin(2 * 3.14159265 * frequency * t)))
              .round()
              .clamp(-32768, 32767);
      _writeInt16(bytes, sample);
    }

    return bytes.toBytes();
  }

  // Simple sin approximation
  double _sin(double x) {
    // Use Dart's built-in
    return x.sin();
  }

  void _writeInt16(BytesBuilder bytes, int value) {
    bytes.addByte(value & 0xFF);
    bytes.addByte((value >> 8) & 0xFF);
  }

  void _writeInt32(BytesBuilder bytes, int value) {
    bytes.addByte(value & 0xFF);
    bytes.addByte((value >> 8) & 0xFF);
    bytes.addByte((value >> 16) & 0xFF);
    bytes.addByte((value >> 24) & 0xFF);
  }

  /// 播放走子音效
  Future<void> playMove() async {
    if (!_enabled || !_initialized) return;
    await _playSound(_moveSoundPath);
  }

  /// 播放吃子音效
  Future<void> playCapture() async {
    if (!_enabled || !_initialized) return;
    await _playSound(_captureSoundPath);
  }

  /// 播放将军音效
  Future<void> playCheck() async {
    if (!_enabled || !_initialized) return;
    await _playSound(_checkSoundPath);
  }

  /// 播放胜利音效
  Future<void> playWin() async {
    if (!_enabled || !_initialized) return;
    await _playSound(_winSoundPath);
  }

  /// 播放失败音效
  Future<void> playLose() async {
    if (!_enabled || !_initialized) return;
    await _playSound(_loseSoundPath);
  }

  /// 播放音效文件
  Future<void> _playSound(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    try {
      // 使用系统默认方式播放
      // 在 Windows 上可以使用 Process.run 调用 powershell
      await Process.run('powershell', [
        '-c',
        '(New-Object Media.SoundPlayer "$path").PlaySync();',
      ]).timeout(const Duration(seconds: 2));
    } catch (_) {
      // 播放失败，静默处理
    }
  }

  /// 启用/禁用音效
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// 设置音量
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  /// 释放资源
  void dispose() {
    _initialized = false;
  }
}

/// Extension for sin on double
extension _DoubleExtension on double {
  double sin() {
    // Simple Taylor series approximation
    double x = this;
    // Normalize to -pi to pi
    while (x > 3.14159265) x -= 2 * 3.14159265;
    while (x < -3.14159265) x += 2 * 3.14159265;
    return x - x * x * x / 6 + x * x * x * x * x / 120;
  }
}
