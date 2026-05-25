import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/services/uci_engine.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/fen.dart';

void main() {
  group('UCI Engine Driver Test', () {
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

        final engine = UCIEngine(enginePath: enginePath, logEnabled: true);
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

        final engine = UCIEngine(enginePath: enginePath, logEnabled: true);
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

        final engine = UCIEngine(enginePath: enginePath, logEnabled: true);
        try {
          final started = await engine.start();
          expect(started, isTrue);

          // Use initial position FEN
          const fen = FenParser.initial;
          print('Analyzing FEN: $fen');

          // Start analysis
          await engine.analyzeByDepth(fen: fen, depth: 10);

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

          // Verify best move format: ICCS algebraic (e.g., "h7e7")
          expect(
            bestMove!.length,
            4,
            reason: 'ICCS move should be 4 chars (e.g., "h7e7")',
          );
          final fromFile = bestMove![0];
          expect(
            fromFile.compareTo('a') >= 0 && fromFile.compareTo('i') <= 0,
            isTrue,
            reason: 'First char should be file letter a-i',
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

        final engine = UCIEngine(enginePath: enginePath, logEnabled: true);
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
        final engine = UCIEngine(enginePath: enginePath, logEnabled: true);
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

        final engine = UCIEngine(enginePath: enginePath, logEnabled: true);
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

    test('should handle ICCS move conversion correctly', () {
      // Test numericToICCS conversion
      // Numeric "8182" → col=8, row=1 to col=8, row=2
      // ICCS: col 8 → file 'i', row 1 → rank 1, so "i1i2"
      final iccs = UCIEngine.numericToICCS('8182');
      expect(iccs, 'i1i2');

      // Test iccsToNumeric conversion
      final numeric = UCIEngine.iccsToNumeric('i1i2');
      expect(numeric, '8182');

      // Test coordsToICCS
      final iccs2 = UCIEngine.coordsToICCS(0, 0, 0, 1);
      expect(iccs2, 'a0a1');

      // Round-trip: coords → ICCS → numeric → ICCS
      final roundTrip = UCIEngine.numericToICCS(
        UCIEngine.iccsToNumeric('h7e7'),
      );
      expect(roundTrip, 'h7e7');
    });

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
  });
}
