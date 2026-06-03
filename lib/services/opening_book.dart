/// 着法来源
enum OpeningSource {
  master('master'), // 大师对局
  classic('classic'), // 经典对局
  personal('personal'); // 用户对局

  const OpeningSource(this.value);
  final String value;
}

/// 开局着法信息
class OpeningMove {
  const OpeningMove({
    required this.iccs,
    required this.chineseName,
    required this.frequency,
    required this.winRate,
    required this.source,
    this.eccoCode,
  });

  /// ICCS 数字记法 (4位数字, 非标准 ICCS)
  ///
  /// 注意：此字段使用 4 位数字编码（如 '2153'），与标准 ICCS 格式（如 'h2e2'）不同。
  /// 标准 ICCS 使用字母 a-i 表示纵线（col），数字 0-9 表示横线（row）。
  /// 如需标准 ICCS 转换，请使用 MoveNotation.toICCS/fromICCS。
  final String iccs;

  /// 中文着法描述 (如 "炮二平五")
  final String chineseName;

  /// 出现频率 (基于统计数据)
  final int frequency;

  /// 该着法的胜率 (0.0-1.0)
  final double winRate;

  /// 着法来源
  final OpeningSource source;

  /// ECCO 开局分类代码
  final String? eccoCode;
}

/// 开局信息 (某一步的局面及可选着法)
class OpeningInfo {
  const OpeningInfo({
    required this.positionFen,
    required this.moves,
    this.eccoCode,
    this.eccoName,
  });

  /// 局面 FEN (不含轮到哪方)
  final String positionFen;

  /// 推荐的后续着法 (按推荐度排序)
  final List<OpeningMove> moves;

  /// ECCO 开局分类代码
  final String? eccoCode;

  /// 开局中文名称
  final String? eccoName;
}

/// 开局库服务 (单例)
/// 提供中国象棋常见开局的查询功能
class OpeningBookService {
  OpeningBookService._();

  static OpeningBookService? _instance;
  static OpeningBookService get instance =>
      _instance ??= OpeningBookService._();

  /// 内置开局库 (FEN → OpeningInfo)
  ///
  /// FEN 格式: 布局 + 走子方(r=红方, b=黑方)
  /// 任何局面都依赖走子方，同一布局红走和黑走是完全不同的局面
  ///
  /// FEN 格式: 10行棋盘, 从上(黑方, row 9)到下(红方, row 0), 每行9列 (col 0-8)
  /// 棋子: 大写=红方, 小写=黑方
  /// r/R=车, n/N=马, b/B=象/相, a/A=士, k/K=将/帅, c/C=炮, p/P=卒/兵
  ///
  /// 红方棋子初始位置:
  ///   车: (0,0) (8,0)  马: (1,0) (7,0)  相: (2,0) (6,0)
  ///   仕: (3,0) (5,0)  帅: (4,0)        炮: (1,2) (7,2)
  ///   兵: (0,3) (2,3) (4,3) (6,3) (8,3)
  ///
  /// 黑方棋子初始位置:
  ///   车: (0,9) (8,9)  马: (1,9) (7,9)  象: (2,9) (6,9)
  ///   士: (3,9) (5,9)  将: (4,9)        炮: (1,7) (7,7)
  ///   卒: (0,6) (2,6) (4,6) (6,6) (8,6)
  ///
  /// 注意：本开局库使用 4 位数字记法，与标准 ICCS（字母+数字）不同。
  /// 如需标准 ICCS 格式，请使用 MoveNotation.toICCS/fromICCS。
  static const Map<String, OpeningInfo> _openingBook = {
    // ============================================================
    // 初始局面
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w',
          eccoCode: null,
          eccoName: null,
          moves: [
            OpeningMove(
              iccs: '2153',
              chineseName: '炮二平五',
              frequency: 4500,
              winRate: 0.52,
              source: OpeningSource.master,
              eccoCode: 'B00',
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '兵七进一',
              frequency: 2200,
              winRate: 0.50,
              source: OpeningSource.master,
              eccoCode: 'A01',
            ),
            OpeningMove(
              iccs: '8143',
              chineseName: '相三进五',
              frequency: 1800,
              winRate: 0.49,
              source: OpeningSource.master,
              eccoCode: 'C00',
            ),
            OpeningMove(
              iccs: '2163',
              chineseName: '炮二平六',
              frequency: 800,
              winRate: 0.48,
              source: OpeningSource.master,
              eccoCode: 'E00',
            ),
            OpeningMove(
              iccs: '8183',
              chineseName: '炮八平六',
              frequency: 700,
              winRate: 0.48,
              source: OpeningSource.master,
              eccoCode: 'D00',
            ),
            OpeningMove(
              iccs: '8163',
              chineseName: '马八进七',
              frequency: 600,
              winRate: 0.48,
              source: OpeningSource.master,
              eccoCode: 'F00',
            ),
            OpeningMove(
              iccs: '2133',
              chineseName: '炮二平七',
              frequency: 300,
              winRate: 0.47,
              source: OpeningSource.classic,
              eccoCode: 'G00',
            ),
            OpeningMove(
              iccs: '1617',
              chineseName: '兵一进一',
              frequency: 150,
              winRate: 0.46,
              source: OpeningSource.classic,
              eccoCode: 'H00',
            ),
          ],
        ),

    // ============================================================
    // 中炮局 (Central Cannon) - 红炮二平五后
    // 炮从 (7,7)→(4,7), row7: 1C5C1→1C2C4
    // ECCO: B00
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w',
          eccoCode: 'B00',
          eccoName: '中炮局',
          moves: [
            OpeningMove(
              iccs: '2747',
              chineseName: '炮8平5',
              frequency: 3200,
              winRate: 0.48,
              source: OpeningSource.master,
              eccoCode: 'B01',
            ),
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 2800,
              winRate: 0.47,
              source: OpeningSource.master,
              eccoCode: 'B03',
            ),
            OpeningMove(
              iccs: '7959',
              chineseName: '炮2平5',
              frequency: 1500,
              winRate: 0.47,
              source: OpeningSource.master,
              eccoCode: 'B02',
            ),
            OpeningMove(
              iccs: '8967',
              chineseName: '马8进6',
              frequency: 400,
              winRate: 0.46,
              source: OpeningSource.classic,
              eccoCode: 'B06',
            ),
          ],
        ),

    // ============================================================
    // 中炮对顺手炮 - 黑炮8平5后
    // 黑炮从 (1,2)→(4,2), row2: 1c5c1→4c2c1
    // ECCO: B01
    // ============================================================
    'rnbakabnr/9/4c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/4c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w',
          eccoCode: 'B01',
          eccoName: '中炮对顺手炮',
          moves: [
            OpeningMove(
              iccs: '8163',
              chineseName: '马八进七',
              frequency: 2500,
              winRate: 0.51,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '8183',
              chineseName: '炮八平六',
              frequency: 800,
              winRate: 0.49,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2123',
              chineseName: '马二进三',
              frequency: 600,
              winRate: 0.48,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 中炮对顺手炮 - 红马八进七后
    // 红马从 (1,9)→(2,7), row9: RNBAKABNR→R1BAKABNR, row7: 1C2C4→1CN1C4
    // ============================================================
    'rnbakabnr/9/4c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/4c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w',
          eccoCode: 'B01',
          eccoName: '中炮对顺手炮',
          moves: [
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 2000,
              winRate: 0.48,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2939',
              chineseName: '车1进1',
              frequency: 600,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '7978',
              chineseName: '炮2进1',
              frequency: 400,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 中炮对顺手炮 - 黑马8进7后
    // 黑马从 (1,0)→(2,2), row0: rnbakabnr→r1bakabnr, row2: 4c2c1→2n1c2c1
    // ============================================================
    'r1bakabnr/9/2n1c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w':
        OpeningInfo(
          positionFen:
              'r1bakabnr/9/2n1c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w',
          eccoCode: 'B01',
          eccoName: '中炮对顺手炮',
          moves: [
            OpeningMove(
              iccs: '2153',
              chineseName: '马二进三',
              frequency: 1800,
              winRate: 0.51,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '兵七进一',
              frequency: 500,
              winRate: 0.49,
              source: OpeningSource.master,
            ),
          ],
        ),

    // ============================================================
    // 中炮对屏风马 - 黑马8进7后 (从初始中炮局分支)
    // 黑马从 (1,0)→(2,2), row0: rnbakabnr→r1bakabnr, row2: 1c5c1→1cn4c1
    // ECCO: B03
    // ============================================================
    'r1bakabnr/9/1cn4c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'r1bakabnr/9/1cn4c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w',
          eccoCode: 'B03',
          eccoName: '中炮对屏风马',
          moves: [
            OpeningMove(
              iccs: '8163',
              chineseName: '马八进七',
              frequency: 2200,
              winRate: 0.51,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '兵七进一',
              frequency: 800,
              winRate: 0.49,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2123',
              chineseName: '马二进三',
              frequency: 500,
              winRate: 0.48,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 中炮对屏风马 - 红马八进七后
    // 红马从 (1,9)→(2,7), row9: RNBAKABNR→R1BAKABNR, row7: 1C2C4→1CN1C4
    // ============================================================
    'r1bakabnr/9/1cn4c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w':
        OpeningInfo(
          positionFen:
              'r1bakabnr/9/1cn4c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w',
          eccoCode: 'B03',
          eccoName: '中炮对屏风马',
          moves: [
            OpeningMove(
              iccs: '7967',
              chineseName: '马2进3',
              frequency: 1800,
              winRate: 0.48,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2939',
              chineseName: '车1进1',
              frequency: 500,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '卒7进1',
              frequency: 300,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 中炮对屏风马 - 黑马2进3后 (完成屏风马阵型)
    // 黑马从 (7,0)→(6,2), row0: r1bakabnr→r1bakab1r, row2: 1cn4c1→1cn3nc1
    // ============================================================
    'r1bakab1r/9/1cn3nc1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w':
        OpeningInfo(
          positionFen:
              'r1bakab1r/9/1cn3nc1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w',
          eccoCode: 'B03',
          eccoName: '屏风马',
          moves: [
            OpeningMove(
              iccs: '2153',
              chineseName: '马二进三',
              frequency: 1500,
              winRate: 0.51,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '兵七进一',
              frequency: 600,
              winRate: 0.49,
              source: OpeningSource.master,
            ),
          ],
        ),

    // ============================================================
    // 中炮对屏风马 - 红马二进三后 (双正马对屏风马)
    // 红马从 (7,9)→(6,7), row9: R1BAKABNR→R1BAKAB1R, row7: 1CN1C4→1CN1C1N2
    // ============================================================
    'r1bakab1r/9/1cn3nc1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C1N2/9/R1BAKAB1R w':
        OpeningInfo(
          positionFen:
              'r1bakab1r/9/1cn3nc1/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C1N2/9/R1BAKAB1R w',
          eccoCode: 'B03',
          eccoName: '屏风马',
          moves: [
            OpeningMove(
              iccs: '3637',
              chineseName: '卒7进1',
              frequency: 1200,
              winRate: 0.48,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2939',
              chineseName: '车1进1',
              frequency: 500,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '1929',
              chineseName: '车9进1',
              frequency: 300,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 中炮对列手炮 - 黑炮2平5后
    // 黑炮从 (7,2)→(4,2), row2: 1c5c1→1c2c4
    // ECCO: B02
    // ============================================================
    'rnbakabnr/9/1c2c4/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c2c4/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w',
          eccoCode: 'B02',
          eccoName: '中炮对列手炮',
          moves: [
            OpeningMove(
              iccs: '8163',
              chineseName: '马八进七',
              frequency: 1200,
              winRate: 0.51,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2123',
              chineseName: '马二进三',
              frequency: 600,
              winRate: 0.49,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '兵七进一',
              frequency: 300,
              winRate: 0.48,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 中炮对列手炮 - 红马八进七后
    // 红马从 (1,9)→(2,7), row9: RNBAKABNR→R1BAKABNR, row7: 1C2C4→1CN1C4
    // ============================================================
    'rnbakabnr/9/1c2c4/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c2c4/p1p1p1p1p/9/9/P1P1P1P1P/1CN1C4/9/R1BAKABNR w',
          eccoCode: 'B02',
          eccoName: '中炮对列手炮',
          moves: [
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 800,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2939',
              chineseName: '车1进1',
              frequency: 400,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 中炮对反宫马 - 黑炮2平6后 (反宫马阵型)
    // 黑炮从 (7,2)→(5,2), row2: 1c5c1→1c3c1c1
    // ECCO: B04
    // ============================================================
    'rnbakabnr/9/1c3c3/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c3c3/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w',
          eccoCode: 'B04',
          eccoName: '中炮对反宫马',
          moves: [
            OpeningMove(
              iccs: '8163',
              chineseName: '马八进七',
              frequency: 800,
              winRate: 0.51,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '兵七进一',
              frequency: 400,
              winRate: 0.49,
              source: OpeningSource.master,
            ),
          ],
        ),

    // ============================================================
    // 中炮对单提马 - 黑马8进9后
    // 黑马从 (1,0)→(0,2), row0: rnbakabnr→_nbakabnr, row2: 1c5c1→n6c1
    // ECCO: B05
    // ============================================================
    '1nbakabnr/9/n6c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w': OpeningInfo(
      positionFen:
          '1nbakabnr/9/n6c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2C4/9/RNBAKABNR w',
      eccoCode: 'B05',
      eccoName: '中炮对单提马',
      moves: [
        OpeningMove(
          iccs: '8163',
          chineseName: '马八进七',
          frequency: 500,
          winRate: 0.51,
          source: OpeningSource.master,
        ),
        OpeningMove(
          iccs: '3637',
          chineseName: '兵七进一',
          frequency: 200,
          winRate: 0.49,
          source: OpeningSource.classic,
        ),
      ],
    ),

    // ============================================================
    // 仙人指路 (Fairy Points the Way) - 红兵七进一后
    // 红兵从 (2,6)→(2,5), row5: 9→2P6, row6: P1P1P1P1P→P3P1P1P
    // ECCO: A01
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/2P6/P3P1P1P/1C5C1/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p1p1p1p1p/9/2P6/P3P1P1P/1C5C1/9/RNBAKABNR w',
          eccoCode: 'A01',
          eccoName: '仙人指路',
          moves: [
            OpeningMove(
              iccs: '3635',
              chineseName: '卒7进1',
              frequency: 1200,
              winRate: 0.48,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2747',
              chineseName: '炮8平5',
              frequency: 800,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 600,
              winRate: 0.47,
              source: OpeningSource.classic,
            ),
            OpeningMove(
              iccs: '8143',
              chineseName: '象3进5',
              frequency: 300,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 仙人指路对卒底炮 - 黑卒7进1后
    // 黑卒从 (2,3)→(2,4), row3: p1p1p1p1p→p3p1p1p, row4: 9→2p6
    // ECCO: A02
    // ============================================================
    'rnbakabnr/9/1c5c1/p3p1p1p/2p6/2P6/P3P1P1P/1C5C1/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p3p1p1p/2p6/2P6/P3P1P1P/1C5C1/9/RNBAKABNR w',
          eccoCode: 'A02',
          eccoName: '仙人指路对卒底炮',
          moves: [
            OpeningMove(
              iccs: '2153',
              chineseName: '炮二平五',
              frequency: 800,
              winRate: 0.51,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '8163',
              chineseName: '马八进七',
              frequency: 500,
              winRate: 0.49,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '8143',
              chineseName: '相三进五',
              frequency: 300,
              winRate: 0.48,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 仙人指路转中炮 - 红炮二平五后
    // 红炮从 (7,7)→(4,7), row7: 1C5C1→1C2C4
    // ============================================================
    'rnbakabnr/9/1c5c1/p3p1p1p/2p6/2P6/P3P1P1P/1C2C4/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p3p1p1p/2p6/2P6/P3P1P1P/1C2C4/9/RNBAKABNR w',
          eccoCode: 'A01',
          eccoName: '仙人指路转中炮',
          moves: [
            OpeningMove(
              iccs: '2747',
              chineseName: '炮8平5',
              frequency: 600,
              winRate: 0.48,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 400,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '3938',
              chineseName: '车9进1',
              frequency: 200,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 飞相局 (Elephant Opening) - 红相三进五后
    // 相从 (6,9)→(4,7), row9: RNBAKABNR→RNBAKA1NR, row7: 1C5C1→1C2B2C1
    // ECCO: C00
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2B2C1/9/RNBAKA1NR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2B2C1/9/RNBAKA1NR w',
          eccoCode: 'C00',
          eccoName: '飞相局',
          moves: [
            OpeningMove(
              iccs: '2747',
              chineseName: '炮8平5',
              frequency: 1000,
              winRate: 0.48,
              source: OpeningSource.master,
              eccoCode: 'C01',
            ),
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 800,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '7957',
              chineseName: '炮2平4',
              frequency: 400,
              winRate: 0.47,
              source: OpeningSource.master,
              eccoCode: 'C03',
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '卒7进1',
              frequency: 300,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 飞相对左中炮 - 黑炮8平5后
    // 黑炮从 (1,2)→(4,2), row2: 1c5c1→4c2c1
    // ECCO: C01
    // ============================================================
    'rnbakabnr/9/4c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2B2C1/9/RNBAKA1NR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/4c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1C2B2C1/9/RNBAKA1NR w',
          eccoCode: 'C01',
          eccoName: '飞相对左中炮',
          moves: [
            OpeningMove(
              iccs: '8163',
              chineseName: '马八进七',
              frequency: 800,
              winRate: 0.50,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2123',
              chineseName: '马二进三',
              frequency: 500,
              winRate: 0.49,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2143',
              chineseName: '炮二平四',
              frequency: 300,
              winRate: 0.48,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 士角炮 (Advisor Corner Cannon) - 红炮八平六后
    // 炮从 (1,7)→(3,7), row7: 1C5C1→3C3C1
    // ECCO: D00
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/3C3C1/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/3C3C1/9/RNBAKABNR w',
          eccoCode: 'D00',
          eccoName: '士角炮',
          moves: [
            OpeningMove(
              iccs: '8143',
              chineseName: '象3进5',
              frequency: 600,
              winRate: 0.48,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 400,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2747',
              chineseName: '炮8平5',
              frequency: 300,
              winRate: 0.47,
              source: OpeningSource.classic,
              eccoCode: 'D01',
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '卒7进1',
              frequency: 200,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 过宫炮 (Cross-Palace Cannon) - 红炮二平六后
    // 炮从 (7,7)→(3,7), row7: 1C5C1→1C1C5
    // ECCO: E00
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C1C5/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C1C5/9/RNBAKABNR w',
          eccoCode: 'E00',
          eccoName: '过宫炮',
          moves: [
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 600,
              winRate: 0.47,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '2747',
              chineseName: '炮8平5',
              frequency: 400,
              winRate: 0.47,
              source: OpeningSource.master,
              eccoCode: 'E01',
            ),
            OpeningMove(
              iccs: '8143',
              chineseName: '象3进5',
              frequency: 300,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '卒7进1',
              frequency: 200,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 起马局 (Horse Opening) - 红马八进七后
    // 马从 (1,9)→(2,7), row9: RNBAKABNR→R1BAKABNR, row7: 1C5C1→1CN4C1
    // ECCO: F00
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN4C1/9/R1BAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN4C1/9/R1BAKABNR w',
          eccoCode: 'F00',
          eccoName: '起马局',
          moves: [
            OpeningMove(
              iccs: '2747',
              chineseName: '炮8平5',
              frequency: 500,
              winRate: 0.48,
              source: OpeningSource.master,
              eccoCode: 'F01',
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '卒7进1',
              frequency: 400,
              winRate: 0.47,
              source: OpeningSource.master,
              eccoCode: 'F02',
            ),
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 300,
              winRate: 0.47,
              source: OpeningSource.classic,
            ),
            OpeningMove(
              iccs: '8143',
              chineseName: '象3进5',
              frequency: 200,
              winRate: 0.46,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 起马对中炮 - 黑炮8平5后
    // 黑炮从 (1,2)→(4,2), row2: 1c5c1→4c2c1
    // ECCO: F01
    // ============================================================
    'rnbakabnr/9/4c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN4C1/9/R1BAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/4c2c1/p1p1p1p1p/9/9/P1P1P1P1P/1CN4C1/9/R1BAKABNR w',
          eccoCode: 'F01',
          eccoName: '起马对中炮',
          moves: [
            OpeningMove(
              iccs: '2153',
              chineseName: '炮二平五',
              frequency: 400,
              winRate: 0.50,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '兵七进一',
              frequency: 200,
              winRate: 0.48,
              source: OpeningSource.master,
            ),
            OpeningMove(
              iccs: '8143',
              chineseName: '相三进五',
              frequency: 150,
              winRate: 0.47,
              source: OpeningSource.classic,
            ),
          ],
        ),

    // ============================================================
    // 金钩炮 (Golden Hook Cannon) - 红炮二平七后
    // 炮从 (7,7)→(2,7), row7: 1C5C1→1CC6
    // ECCO: G00
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1CC6/9/RNBAKABNR w': OpeningInfo(
      positionFen:
          'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1CC6/9/RNBAKABNR w',
      eccoCode: 'G00',
      eccoName: '金钩炮',
      moves: [
        OpeningMove(
          iccs: '2747',
          chineseName: '炮8平5',
          frequency: 300,
          winRate: 0.48,
          source: OpeningSource.master,
          eccoCode: 'G01',
        ),
        OpeningMove(
          iccs: '8977',
          chineseName: '马8进7',
          frequency: 200,
          winRate: 0.47,
          source: OpeningSource.classic,
        ),
        OpeningMove(
          iccs: '3637',
          chineseName: '卒7进1',
          frequency: 150,
          winRate: 0.46,
          source: OpeningSource.classic,
        ),
      ],
    ),

    // ============================================================
    // 边兵局 (Edge Pawn) - 红兵一进一后
    // 兵从 (8,6)→(8,5), row5: 9→8P, row6: P1P1P1P1P→P1P1P1P2
    // ECCO: H00
    // ============================================================
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/8P/P1P1P1P2/1C5C1/9/RNBAKABNR w':
        OpeningInfo(
          positionFen:
              'rnbakabnr/9/1c5c1/p1p1p1p1p/9/8P/P1P1P1P2/1C5C1/9/RNBAKABNR w',
          eccoCode: 'H00',
          eccoName: '边兵局',
          moves: [
            OpeningMove(
              iccs: '2747',
              chineseName: '炮8平5',
              frequency: 200,
              winRate: 0.48,
              source: OpeningSource.classic,
            ),
            OpeningMove(
              iccs: '8977',
              chineseName: '马8进7',
              frequency: 150,
              winRate: 0.47,
              source: OpeningSource.classic,
            ),
            OpeningMove(
              iccs: '3637',
              chineseName: '卒7进1',
              frequency: 100,
              winRate: 0.46,
              source: OpeningSource.personal,
            ),
          ],
        ),
  };

  /// 根据局面 FEN 查询开局信息
  ///
  /// [positionFen] 完整 FEN（必须包含走子方 r/b）
  /// 返回该局面下的推荐着法列表
  OpeningInfo? lookup(String positionFen) {
    return _openingBook[_normalizeFen(positionFen)];
  }

  /// 获取所有开局信息列表（按 eccoCode 去重，按 ECCO 代码排序）
  List<OpeningInfo> getAllOpenings() =>
      _uniqueOpenings().toList()..sort((a, b) {
        final codeA = a.eccoCode ?? 'ZZZ';
        final codeB = b.eccoCode ?? 'ZZZ';
        return codeA.compareTo(codeB);
      });

  /// 按名称搜索开局。空关键字返回全部。
  List<OpeningInfo> searchByName(String keyword) {
    if (keyword.isEmpty) return getAllOpenings();
    return _uniqueOpenings()
        .where(
          (info) =>
              info.eccoName?.contains(keyword) == true ||
              info.eccoCode?.contains(keyword.toUpperCase()) == true,
        )
        .toList();
  }

  /// 按 eccoCode 去重遍历。空字符串/空 ECCO 走 positionFen。
  Iterable<OpeningInfo> _uniqueOpenings() sync* {
    final seen = <String>{};
    for (final entry in _openingBook.entries) {
      final key = entry.value.eccoCode ?? entry.key;
      if (seen.add(key)) yield entry.value;
    }
  }

  /// 开局库大小
  int get size => _openingBook.length;

  /// 确保 FEN 包含走子方（w/b），若缺失则默认补 'w'
  ///
  /// 正确处理多字段 FEN：只取第一个 token（走子方）来判断，保留原始 FEN
  /// 的所有后续字段（半回合计数、全回合计数等）。
  ///
  /// 将 'r'（旧式非标准表示红方走子）归一化为 UCI 标准的 'w'，
  /// 与 [FenParser.generate] 产出的格式保持一致。
  static String _normalizeFen(String fen) {
    final trimmed = fen.trim();
    final firstSpace = trimmed.indexOf(' ');
    if (firstSpace < 0) return '$trimmed w';
    // splitOnce：仅在第一个空格处切分
    final activeColor = trimmed.substring(firstSpace + 1, firstSpace + 2);
    if (activeColor == 'w' || activeColor == 'b') return trimmed;
    if (activeColor == 'r') {
      // 将旧式的 'r' 替换为 UCI 标准的 'w'，保留其他 token。
      return '${trimmed.substring(0, firstSpace + 1)}w'
          '${trimmed.substring(firstSpace + 2)}';
    }
    // 走子方缺失或未知：默认补 'w'
    return '${trimmed.substring(0, firstSpace + 1)}w'
        '${trimmed.substring(firstSpace + 1)}';
  }
}
