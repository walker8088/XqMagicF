import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/services/engine.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/fen.dart';

void main() {
  group('Engine Driver Test', () {
    // Find available engine
    String? findEngine() {
      final basePaths = ['', 'D:/01_MyCode/XqMagicF'];
      final candidates = [
        'engine/Pikafish_240917/pikafish-avx2.exe',
        'engine/eleeye/ELEEYE.EXE',
      ];
      for (final base in basePaths) {
        for (final path in candidates) {
          final fullPath = base.isEmpty ? path : '$base/$path';
          final file = File(fullPath);
          if (file.existsSync()) return fullPath;
        }
      }
      return null;
    }

    String? findEleeye() {
      final basePaths = ['', 'D:/01_MyCode/XqMagicF'];
      for (final base in basePaths) {
        final path = base.isEmpty
            ? 'engine/eleeye/ELEEYE.EXE'
            : '$base/engine/eleeye/ELEEYE.EXE';
        if (File(path).existsSync()) return path;
      }
      return null;
    }

    test('engine executable should exist', () {
      final enginePath = findEngine();
      expect(
        enginePath,
        isNotNull,
        reason: 'No engine found in engine/ directory',
      );
      if (enginePath != null) {
        expect(File(enginePath).existsSync(), isTrue);
      }
    });

    test(
      'should start engine and get uci/ucci response',
      () async {
        final enginePath = findEngine();
        if (enginePath == null) {
          print('SKIP: No engine found');
          return;
        }

        final engine = Engine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(started, isTrue, reason: 'Engine should start successfully');
          expect(engine.isReady, isTrue);
          expect(engine.isRunning, isTrue);
          print('Engine name: ${engine.engineName}');
          print('Engine author: ${engine.engineAuthor}');
          print('Options: ${engine.options.keys}');
        } finally {
          await engine.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'should start eleeye engine (UCCI protocol)',
      () async {
        final enginePath = findEleeye();
        if (enginePath == null) {
          print('SKIP: eleeye engine not found');
          return;
        }

        final engine = Engine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(
            started,
            isTrue,
            reason: 'Eleeye engine should start with UCCI fallback',
          );
          expect(engine.isReady, isTrue);
          expect(engine.isRunning, isTrue);
          print('Engine name: ${engine.engineName}');
          print('Engine author: ${engine.engineAuthor}');
        } finally {
          await engine.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'should analyze initial position and return best move',
      () async {
        final enginePath = findEngine();
        if (enginePath == null) {
          print('SKIP: No engine found');
          return;
        }

        final engine = Engine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(started, isTrue);

          // Use initial position FEN
          const fen = FenParser.initial;
          print('Analyzing FEN: $fen');

          // Start analysis
          await engine.analyze(fen: fen, depth: 10);

          // Wait for bestmove event
          String? bestMove;
          engine.events.listen((event) {
            if (event is EngineBestMove) {
              bestMove = event.iccsMove;
            }
          });

          // Poll for best move with timeout
          for (int i = 0; i < 30; i++) {
            await Future.delayed(const Duration(seconds: 1));
            if (bestMove != null) break;
            // Also check engine.bestInfo
            if (engine.bestInfo != null && engine.bestInfo!.pv.isNotEmpty) {
              bestMove = engine.bestInfo!.bestMoveICCS;
              break;
            }
          }

          print('Best move (ICCS): $bestMove');
          expect(
            bestMove,
            isNotNull,
            reason: 'Engine should return a best move',
          );
          expect(bestMove!.isNotEmpty, isTrue);

          expect(
            bestMove!.length,
            4,
            reason: 'ICCS move should be 4 chars (e.g., "h2e2")',
          );
          // 验证格式：只能是字母格式(a-i)
          final firstChar = bestMove![0];
          final isLetterFormat =
              firstChar.compareTo('a') >= 0 && firstChar.compareTo('i') <= 0;
          expect(
            isLetterFormat,
            isTrue,
            reason: 'First char should be letter a-i, got: $firstChar',
          );
        } finally {
          await engine.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'should get best move using blocking call',
      () async {
        final enginePath = findEngine();
        if (enginePath == null) {
          print('SKIP: No engine found');
          return;
        }

        final engine = Engine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(started, isTrue);

          const fen = FenParser.initial;
          final bestMove = await engine.getBestMove(fen: fen, depth: 10);

          print('Best move (ICCS): $bestMove');
          expect(bestMove, isNotNull);
          expect(bestMove!.isNotEmpty, isTrue);
        } finally {
          await engine.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'should eleeye (UCCI) analyze and return best move',
      () async {
        final enginePath = findEleeye();
        if (enginePath == null) {
          print('SKIP: eleeye not found');
          return;
        }
        final engine = Engine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(started, isTrue);
          final bestMove = await engine.getBestMove(
            fen: FenParser.initial,
            depth: 6,
          );
          print('Eleeye best: $bestMove');
          expect(bestMove, isNotNull);
        } finally {
          await engine.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'should analyze custom position from GameEngine',
      () async {
        final enginePath = findEngine();
        if (enginePath == null) {
          print('SKIP: No engine found');
          return;
        }

        final engine = Engine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(started, isTrue);

          // Create a custom position using Board and FenParser
          final board = Board();
          board.initialize();
          final fen = FenParser.generate(board, PieceColor.red);
          print('Custom FEN: $fen');

          final bestMove = await engine.getBestMove(fen: fen, depth: 8);
          print('Best move: $bestMove');
          expect(bestMove, isNotNull);
        } finally {
          await engine.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test('should round-trip FEN generation and parsing', () {
      final board = Board();
      board.initialize();

      final fen = FenParser.generate(board, PieceColor.red);
      print('Generated FEN: $fen');

      final board2 = Board();
      final activeColor = FenParser.parse(fen, board2);

      // Verify all pieces match
      expect(activeColor, PieceColor.red);
      expect(board2.pieces.length, board.pieces.length);

      for (final entry in board.pieces.entries) {
        final piece2 = board2.getPiece(entry.key);
        expect(piece2, isNotNull, reason: 'Piece at ${entry.key} should exist');
        expect(piece2!.type, entry.value.type);
        expect(piece2.color, entry.value.color);
      }
    });

    test('FEN should match expected initial position', () {
      final board = Board();
      board.initialize();
      final fen = FenParser.generate(board, PieceColor.red);

      // Standard Xiangqi FEN
      const expected =
          'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR r';
      expect(fen, expected);
    });

    test(
      'should parse info lines with score, pv, and bestmove correctly',
      () async {
        final enginePath = findEngine();
        if (enginePath == null) {
          print('SKIP: No engine found');
          return;
        }

        final engine = Engine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(started, isTrue);
          expect(engine.isReady, isTrue);

          // Collect all events for analysis
          final infoEvents = <EngineAnalysisUpdate>[];
          EngineBestMove? bestMoveEvent;
          final allRawLines = <String>[];

          engine.events.listen((event) {
            if (event is EngineAnalysisUpdate) {
              infoEvents.add(event);
              print(
                'INFO: depth=${event.info.depth} '
                'score=${event.info.isMate ? "M${event.info.score}" : event.info.score} '
                'pv=${event.info.pv} '
                'multipv=${event.info.multipv}',
              );
            } else if (event is EngineBestMove) {
              bestMoveEvent = event;
              print('BESTMOVE: ${event.iccsMove}');
            } else if (event is EngineRawLine) {
              allRawLines.add(event.line);
            }
          });

          // Analyze initial position
          const fen = FenParser.initial;
          await engine.analyze(fen: fen, depth: 8);

          // Wait for bestmove with timeout
          for (int i = 0; i < 60; i++) {
            await Future.delayed(const Duration(seconds: 1));
            if (bestMoveEvent != null) break;
          }

          print('Total info events: ${infoEvents.length}');
          print('Total raw lines: ${allRawLines.length}');

          // Verify bestmove was received
          expect(
            bestMoveEvent,
            isNotNull,
            reason: 'Should receive bestmove after analysis',
          );
          expect(bestMoveEvent!.iccsMove.isNotEmpty, isTrue);

          // Verify info events were received
          expect(
            infoEvents.isNotEmpty,
            isTrue,
            reason: 'Should receive info events during analysis',
          );

          // Verify at least one info has score and pv
          final scoredInfos = infoEvents.where(
            (e) => e.info.pv.isNotEmpty && (e.info.score != 0 || e.info.isMate),
          );
          expect(
            scoredInfos.isNotEmpty,
            isTrue,
            reason: 'At least one info should have non-zero score and pv',
          );
        } finally {
          await engine.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    test(
      'should handle multiPV with multiple principal variations',
      () async {
        // 只使用 UCI 引擎测试 multiPV（UCCI 协议不支持 MultiPV）
        final enginePath = findEngine();
        if (enginePath == null) {
          print('SKIP: No engine found');
          return;
        }

        // 跳过 UCCI 引擎（UCCI 不支持 MultiPV）
        if (enginePath.toLowerCase().contains('eleeye')) {
          print('SKIP: UCCI engine does not support MultiPV');
          return;
        }

        final engine = Engine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(started, isTrue, reason: 'Engine should start successfully');

          // Collect multipv values and currentInfos from events
          final allInfos = <int>[];
          final collectedPVs = <EngineInfo>[];

          engine.events.listen((event) {
            if (event is EngineAnalysisUpdate) {
              collectedPVs.add(event.info);
              if (!allInfos.contains(event.info.multipv)) {
                allInfos.add(event.info.multipv);
              }
            }
          });

          // Analyze with multiPV=3
          const fen = FenParser.initial;
          await engine.analyze(fen: fen, depth: 8, multiPV: 3);

          // Wait for analysis to complete
          for (int i = 0; i < 60; i++) {
            await Future.delayed(const Duration(seconds: 1));
            if (allInfos.length >= 2) break;
            if (engine.bestMove != null && allInfos.isNotEmpty) break;
          }

          // --- 详细断言，便于定位失败原因 ---
          final pvCount = engine.currentInfos.length;
          print('MultiPV values seen: $allInfos');
          print('Engine bestMove: ${engine.bestMove}');
          print('Engine bestInfo: ${engine.bestInfo}');
          print('Collected PVs from events: ${collectedPVs.length}');
          print('currentInfos count: $pvCount');

          // 断言1：currentInfos 不应为空
          expect(
            pvCount,
            greaterThan(0),
            reason: 'currentInfos should not be empty after analysis',
          );

          // 断言2：如果引擎支持 multiPV，应该看到多个不同的 multipv 值
          expect(
            allInfos.length,
            greaterThan(1),
            reason: 'Should see multiple multipv values, got: $allInfos',
          );

          // 断言3：currentInfos 数量应与 multipv 值数量一致
          expect(
            pvCount,
            allInfos.length,
            reason:
                'currentInfos count ($pvCount) should match multipv values ($allInfos)',
          );

          // 断言4：bestInfo 不应为空
          expect(
            engine.bestInfo,
            isNotNull,
            reason: 'bestInfo should not be null',
          );
        } finally {
          await engine.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
