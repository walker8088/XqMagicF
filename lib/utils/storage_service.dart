import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 统一持久化存储服务
/// 所有数据文件的存储路径由此处集中管理
class StorageService {
  StorageService._();

  static const String _dirName = 'magicf';

  /// 获取 magicf 数据目录
  static Future<Directory> getDataDir() async {
    final dir = await getApplicationSupportDirectory();
    final magicfDir = Directory('${dir.path}/$_dirName');
    if (!await magicfDir.exists()) {
      await magicfDir.create(recursive: true);
    }
    return magicfDir;
  }

  /// 获取指定名称的数据文件
  static Future<File> getFile(String fileName) async {
    final dir = await getDataDir();
    return File('${dir.path}/$fileName');
  }

  /// 读取并解析 JSON 文件，返回 dynamic（若文件不存在则返回 null）
  static Future<dynamic> readJson(String fileName) async {
    try {
      final file = await getFile(fileName);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return content;
    } catch (_) {
      return null;
    }
  }

  /// 写入 JSON 到文件
  static Future<void> writeJson(String fileName, String content) async {
    try {
      final file = await getFile(fileName);
      await file.writeAsString(content);
    } catch (_) {
      // 写入失败静默处理
    }
  }
}
