// 云库查询测试脚本
// 运行: dart test_cloud_db.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const baseUrl = 'https://www.chessdb.cn/chessdb.php';

  // 初始局面 FEN
  const initialFen =
      'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR r';

  print('=== 云库查询测试 ===');
  print('');

  // 测试1: 直接拼接 URL (有 Bug 的方式)
  print('【测试1】直接拼接 URL（旧方式，可能有空格问题）');
  final badUrl = '$baseUrl?action=queryall&board=$initialFen';
  print('URL: ${badUrl.substring(0, 80)}...');
  try {
    final response = await http
        .get(Uri.parse(badUrl))
        .timeout(const Duration(seconds: 10));
    print('状态码: ${response.statusCode}');
    print('响应: ${response.body.substring(0, 200)}');
  } catch (e) {
    print('错误: $e');
  }
  print('');

  // 测试2: 正确编码的 URL (修复后的方式)
  print('【测试2】正确编码 URL（新方式）');
  final goodUrl = Uri.parse(
    baseUrl,
  ).replace(queryParameters: {'action': 'queryall', 'board': initialFen});
  print('URL: ${goodUrl.toString().substring(0, 100)}...');
  try {
    final response = await http
        .get(goodUrl)
        .timeout(const Duration(seconds: 10));
    print('状态码: ${response.statusCode}');
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      print('code: ${json['code']}');
      final moves = json['moves'] as List?;
      if (moves != null && moves.isNotEmpty) {
        print('着法数: ${moves.length}');
        print('');
        print('前5步推荐着法:');
        for (int i = 0; i < moves.length && i < 5; i++) {
          final move = moves[i] as Map<String, dynamic>;
          print(
            '  ${i + 1}. ${move['move']}  score=${move['score']}  winrate=${move['winrate']}  number=${move['number']}',
          );
        }
      } else {
        print('无着法数据');
      }
    } else {
      print('响应: ${response.body.substring(0, 200)}');
    }
  } catch (e) {
    print('错误: $e');
  }
  print('');

  // 测试3: 中局局面
  print('【测试3】中局局面查询');
  const midFen =
      'r1bakabr1/9/1cn1c2n1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C2N1/9/R1BAKABR1 w';
  final midUrl = Uri.parse(
    baseUrl,
  ).replace(queryParameters: {'action': 'queryall', 'board': midFen});
  try {
    final response = await http
        .get(midUrl)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      print('code: ${json['code']}');
      final moves = json['moves'] as List?;
      if (moves != null && moves.isNotEmpty) {
        print('着法数: ${moves.length}');
        for (int i = 0; i < moves.length && i < 3; i++) {
          final move = moves[i] as Map<String, dynamic>;
          print('  ${i + 1}. ${move['move']}  score=${move['score']}');
        }
      } else {
        print('云库无此局面数据');
      }
    } else {
      print('请求失败: ${response.statusCode}');
    }
  } catch (e) {
    print('错误: $e');
  }

  print('');
  print('=== 测试完成 ===');
}
