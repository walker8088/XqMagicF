import 'dart:io';

import 'package:magicf/models/chess_piece.dart';
import 'package:magicf/models/game_tree.dart';
import 'package:magicf/models/move.dart';
import 'package:magicf/utils/constants.dart';
import 'package:magicf/utils/fen.dart';
import 'package:magicf/utils/move_notation.dart';
import 'package:magicf/utils/position.dart';

/// Result of a Chinese Chess game
enum GameResult {
  redWin('1-0'),
  blackWin('0-1'),
  draw('1/2-1/2'),
  ongoing('*');

  const GameResult(this.symbol);
  final String symbol;

  static GameResult fromSymbol(String symbol) {
    switch (symbol.trim()) {
      case '1-0':
        return GameResult.redWin;
      case '0-1':
        return GameResult.blackWin;
      case '1/2-1/2':
        return GameResult.draw;
      default:
        return GameResult.ongoing;
    }
  }
}

/// Metadata for a single game record
class GameRecord {
  GameRecord({
    this.event = '',
    this.site = '',
    this.date = '',
    this.round = '',
    this.redPlayer = '',
    this.blackPlayer = '',
    this.result = GameResult.ongoing,
    this.fen,
    GameTree? gameTree,
  }) : gameTree = gameTree ?? GameTree();

  String event;
  String site;
  String date;
  String round;
  String redPlayer;
  String blackPlayer;
  GameResult result;
  String? fen;
  GameTree gameTree;

  /// Check if this game uses a non-standard starting position
  bool get hasSetUp =>
      fen != null && fen != FenParser.initial && fen!.trim().isNotEmpty;

  @override
  String toString() {
    final parts = <String>[];
    if (event.isNotEmpty) parts.add('Event: $event');
    if (site.isNotEmpty) parts.add('Site: $site');
    if (date.isNotEmpty) parts.add('Date: $date');
    if (redPlayer.isNotEmpty) parts.add('Red: $redPlayer');
    if (blackPlayer.isNotEmpty) parts.add('Black: $blackPlayer');
    parts.add('Result: ${result.symbol}');
    return parts.join(', ');
  }
}

/// Error information from PGN parsing
class PGNParseError {
  PGNParseError({
    required this.message,
    this.lineNumber,
    this.column,
    this.context,
  });

  final String message;
  final int? lineNumber;
  final int? column;
  final String? context;

  @override
  String toString() {
    final parts = <String>[];
    if (lineNumber != null) parts.add('Line $lineNumber');
    if (column != null) parts.add('Col $column');
    parts.add(message);
    if (context != null) parts.add('Context: "$context"');
    return parts.join(': ');
  }
}

/// Result of parsing a PGN file
class PGNParseResult {
  PGNParseResult({required this.games, this.errors = const []});

  final List<GameRecord> games;
  final List<PGNParseError> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// Internal representation of a parsed move during parsing
class _ParsedMove {
  _ParsedMove({
    required this.from,
    required this.to,
    this.color = PieceColor.red,
  });

  final Position from;
  final Position to;
  PieceColor color;
  String comment = '';
  final List<String> nags = [];
  final List<List<_ParsedMove>> variations = [];
}

/// PGN (Portable Game Notation) service for Chinese Chess (Xiangqi)
///
/// Supports reading and writing PGN files with ICCS coordinate notation.
/// ICCS format: 4-digit string (col1row1col2row2) where:
///   - col: 1-9 from right to left (red's perspective), maps to 9-ourCol
///   - row: 1-10 top to bottom, maps to ourRow+1
class PGNService {
  PGNService();

  // ─────────────────────────────────────────────
  // File I/O
  // ─────────────────────────────────────────────

  /// Read and parse a PGN file, returning all games found
  PGNParseResult readFromFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return PGNParseResult(
        games: [],
        errors: [PGNParseError(message: 'File not found: $filePath')],
      );
    }
    try {
      final content = file.readAsStringSync();
      return parse(content);
    } on Exception catch (e) {
      return PGNParseResult(
        games: [],
        errors: [PGNParseError(message: 'Failed to read file: $e')],
      );
    }
  }

  /// Write a list of game records to a PGN file
  bool writeToFile(String filePath, List<GameRecord> games) {
    try {
      final content = write(games);
      final file = File(filePath);
      file.writeAsStringSync(content);
      return true;
    } on Exception {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Parsing
  // ─────────────────────────────────────────────

  /// Parse PGN text content and return all games found
  PGNParseResult parse(String content) {
    final games = <GameRecord>[];
    final errors = <PGNParseError>[];

    // Split into individual game blocks
    final gameBlocks = _splitGames(content, errors);

    for (final block in gameBlocks) {
      try {
        final game = _parseSingleGame(block, errors);
        if (game != null) {
          games.add(game);
        }
      } on Exception catch (e) {
        errors.add(PGNParseError(message: 'Failed to parse game: $e'));
      }
    }

    return PGNParseResult(games: games, errors: errors);
  }

  /// Split PGN content into individual game blocks
  List<String> _splitGames(String content, List<PGNParseError> errors) {
    final blocks = <String>[];
    final lines = content.split('\n');

    List<String> currentBlock = [];
    bool inMoveText = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        if (inMoveText) {
          // Blank line after move text might end a game
          if (currentBlock.isNotEmpty) {
            blocks.add(currentBlock.join('\n'));
            currentBlock = [];
            inMoveText = false;
          }
        }
        continue;
      }

      if (line.startsWith('[')) {
        // Header tag
        if (inMoveText && currentBlock.isNotEmpty) {
          // New game starting - save previous
          blocks.add(currentBlock.join('\n'));
          currentBlock = [];
        }
        currentBlock.add(line);
      } else {
        // Move text or other content
        inMoveText = true;
        currentBlock.add(line);
      }
    }

    // Don't forget the last block
    if (currentBlock.isNotEmpty) {
      blocks.add(currentBlock.join('\n'));
    }

    return blocks;
  }

  /// Parse a single game block (headers + move text)
  GameRecord? _parseSingleGame(String block, List<PGNParseError> errors) {
    final headers = <String, String>{};
    String moveText = '';
    bool foundMoveText = false;

    final lines = block.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('[') && !foundMoveText) {
        // Parse header tag
        final headerMatch = RegExp(r'^\[(\w+)\s+"(.*)"\]').firstMatch(trimmed);
        if (headerMatch != null) {
          final tag = headerMatch.group(1)!;
          var value = headerMatch.group(2)!;
          // Handle escaped quotes
          value = value.replaceAll('\\"', '"');
          headers[tag] = value;
        } else {
          errors.add(
            PGNParseError(
              message: 'Malformed header: $trimmed',
              context: trimmed,
            ),
          );
        }
      } else {
        foundMoveText = true;
        moveText += '$trimmed ';
      }
    }

    // Extract metadata from headers
    final result = GameResult.fromSymbol(headers['Result'] ?? '*');
    final fen = headers['FEN'];
    final setUp = headers['SetUp'] == '1';

    final game = GameRecord(
      event: headers['Event'] ?? '',
      site: headers['Site'] ?? '',
      date: headers['Date'] ?? '',
      round: headers['Round'] ?? '',
      redPlayer: headers['Red'] ?? '',
      blackPlayer: headers['Black'] ?? '',
      result: result,
      fen: (setUp && fen != null && fen.isNotEmpty) ? fen : null,
    );

    // Parse move text
    if (moveText.trim().isNotEmpty) {
      try {
        _applyMovesToGame(game, moveText, errors);
      } on Exception catch (e) {
        errors.add(
          PGNParseError(
            message: 'Failed to parse move text: $e',
            context: moveText.substring(0, moveText.length.clamp(0, 100)),
          ),
        );
      }
    }

    return game;
  }

  /// Parse move text and apply to game tree
  void _applyMovesToGame(
    GameRecord game,
    String moveText,
    List<PGNParseError> errors,
  ) {
    final startingFen = game.fen ?? FenParser.initial;
    game.gameTree.initFromFen(startingFen);

    final parsed = _parseMoveText(moveText, errors);
    if (parsed.isEmpty) return;

    // Build game tree from parsed moves
    _buildGameTree(game.gameTree, parsed, startingFen, errors);
  }

  /// Parse move text into a list of moves with variations
  List<_ParsedMove> _parseMoveText(String text, List<PGNParseError> errors) {
    final moves = <_ParsedMove>[];
    final tokenizer = _MoveTextTokenizer(text);

    try {
      _parseMoveList(tokenizer, moves, PieceColor.red, errors);
    } on Exception catch (e) {
      errors.add(
        PGNParseError(
          message: 'Error during move text parsing: $e',
          context: text.substring(0, text.length.clamp(0, 100)),
        ),
      );
    }

    return moves;
  }

  /// Recursive move list parser that handles variations
  void _parseMoveList(
    _MoveTextTokenizer tokenizer,
    List<_ParsedMove> moves,
    PieceColor currentColor,
    List<PGNParseError> errors,
  ) {
    while (!tokenizer.isAtEnd()) {
      final token = tokenizer.peek();

      // Skip move numbers (e.g., "1.", "2.", "123.")
      if (_isMoveNumber(tokenizer)) {
        tokenizer.consume(); // consume the number
        if (!tokenizer.isAtEnd() && tokenizer.peek() == '.') {
          tokenizer.consume(); // consume the dot
        }
        continue;
      }

      // Result at end
      if (_isResult(token)) {
        tokenizer.consume();
        return;
      }

      // Comment in braces
      if (token == '{') {
        tokenizer.consume();
        final comment = tokenizer.readUntil('}');
        tokenizer.consume(); // consume closing brace
        // Attach comment to last move if any
        if (moves.isNotEmpty) {
          final lastMove = moves.last;
          if (lastMove.comment.isNotEmpty) {
            lastMove.comment += ' $comment';
          } else {
            lastMove.comment = comment.trim();
          }
        }
        continue;
      }

      // Variation in parentheses
      if (token == '(') {
        tokenizer.consume(); // consume opening paren
        final variation = <_ParsedMove>[];
        // Determine color for variation: it starts from the current position
        // The variation color depends on the last move made
        final variationColor = moves.isEmpty
            ? currentColor
            : (moves.last.color == PieceColor.red
                  ? PieceColor.black
                  : PieceColor.red);
        _parseMoveList(tokenizer, variation, variationColor, errors);

        // consume closing paren
        if (!tokenizer.isAtEnd() && tokenizer.peek() == ')') {
          tokenizer.consume();
        }

        // Attach variation to last move
        if (moves.isNotEmpty) {
          moves.last.variations.add(variation);
        } else {
          errors.add(
            PGNParseError(
              message: 'Variation without preceding move',
              context: '(...)',
            ),
          );
        }
        continue;
      }

      // Closing paren - end of variation
      if (token == ')') {
        return;
      }

      // NAG annotation ($1, $2, etc.)
      if (_isNAG(token)) {
        tokenizer.consume();
        if (moves.isNotEmpty) {
          moves.last.nags.add(token);
        }
        continue;
      }

      // Try to parse as a move (ICCS notation)
      final moveResult = _tryParseMove(token, currentColor);
      if (moveResult != null) {
        tokenizer.consume();
        moves.add(moveResult);
        // Toggle color
        currentColor = currentColor == PieceColor.red
            ? PieceColor.black
            : PieceColor.red;
      } else {
        // Unknown token, skip
        tokenizer.consume();
      }
    }
  }

  bool _isMoveNumber(_MoveTextTokenizer tokenizer) {
    final token = tokenizer.peek();
    // Match patterns like "1.", "12.", "123." or just the number before a dot
    if (RegExp(r'^\d+$').hasMatch(token)) {
      final next = tokenizer.peekNext();
      return next == '.';
    }
    // Also handle "1." as a single token
    if (RegExp(r'^\d+\.$').hasMatch(token)) {
      return true;
    }
    return false;
  }

  bool _isResult(String token) {
    return token == '1-0' ||
        token == '0-1' ||
        token == '1/2-1/2' ||
        token == '*';
  }

  bool _isNAG(String token) {
    return RegExp(r'^\$\d+$').hasMatch(token);
  }

  _ParsedMove? _tryParseMove(String token, PieceColor color) {
    // ICCS format: exactly 4 digits
    if (RegExp(r'^\d{4}$').hasMatch(token)) {
      try {
        final (from, to) = MoveNotation.fromICCS(token);
        return _ParsedMove(from: from, to: to, color: color);
      } on Exception {
        return null;
      }
    }

    // Some PGN files might use lowercase or have spaces
    final cleaned = token.replaceAll(' ', '');
    if (RegExp(r'^\d{4}$').hasMatch(cleaned)) {
      return _tryParseMove(cleaned, color);
    }

    return null;
  }

  /// Build the GameTree from parsed moves, including variations
  void _buildGameTree(
    GameTree gameTree,
    List<_ParsedMove> moves,
    String startingFen,
    List<PGNParseError> errors,
  ) {
    final board = _SimpleBoard();
    _SimpleBoard.parseBoard(startingFen, board);

    var currentNode = gameTree.root;

    for (final move in moves) {
      // Compute FEN before the move
      final fenBefore = _SimpleBoard.generateBoard(board, move.color);

      // Apply move to board
      final moveRecord = _applyMoveToBoard(board, move, errors);
      if (moveRecord == null) {
        errors.add(
          PGNParseError(
            message:
                'Could not apply move ${MoveNotation.toICCS(MoveRecord(from: move.from, to: move.to, capturedPiece: null, color: move.color))}',
          ),
        );
        continue;
      }

      // Compute FEN after the move
      final nextColor = move.color == PieceColor.red
          ? PieceColor.black
          : PieceColor.red;
      final fenAfter = _SimpleBoard.generateBoard(board, nextColor);

      // Add to game tree
      currentNode = currentNode.addMainLine(fenAfter, moveRecord);

      // Attach metadata
      if (move.comment.isNotEmpty) {
        currentNode.comment = move.comment;
      }
      if (move.nags.isNotEmpty) {
        currentNode.moveAnnotation = move.nags.join(' ');
      }

      // Process variations
      for (final variation in move.variations) {
        _addVariation(currentNode.parent!, move, variation, fenBefore, errors);
      }
    }

    // Navigate to the last node
    while (gameTree.goForward()) {}
  }

  /// Add a variation branch to the tree
  void _addVariation(
    GameTreeNode parentNode,
    _ParsedMove mainMove,
    List<_ParsedMove> variationMoves,
    String fenBefore,
    List<PGNParseError> errors,
  ) {
    final board = _SimpleBoard();
    _SimpleBoard.parseBoard(fenBefore, board);

    var currentNode = parentNode;

    for (final move in variationMoves) {
      final moveRecord = _applyMoveToBoard(board, move, errors);
      if (moveRecord == null) continue;

      final nextColor = move.color == PieceColor.red
          ? PieceColor.black
          : PieceColor.red;
      final fenAfter = _SimpleBoard.generateBoard(board, nextColor);

      currentNode = currentNode.addVariation(fenAfter, moveRecord);

      if (move.comment.isNotEmpty) {
        currentNode.comment = move.comment;
      }
      if (move.nags.isNotEmpty) {
        currentNode.moveAnnotation = move.nags.join(' ');
      }
    }
  }

  MoveRecord? _applyMoveToBoard(
    _SimpleBoard board,
    _ParsedMove move,
    List<PGNParseError> errors,
  ) {
    final piece = board.getPiece(move.from);
    if (piece == null) {
      errors.add(
        PGNParseError(
          message:
              'No piece at ${move.from} to move (ICCS: ${MoveNotation.toICCS(MoveRecord(from: move.from, to: move.to, capturedPiece: null, color: move.color))})',
        ),
      );
      return null;
    }

    if (piece.color != move.color) {
      errors.add(
        PGNParseError(
          message:
              'Piece at ${move.from} is ${piece.color} but move color is ${move.color}',
        ),
      );
      return null;
    }

    final captured = board.getPiece(move.to);
    board.removePiece(move.from);

    final movedPiece = ChessPiece(
      type: piece.type,
      color: piece.color,
      position: move.to,
    );
    board.putPiece(movedPiece);

    return MoveRecord(
      from: move.from,
      to: move.to,
      capturedPiece: captured,
      color: move.color,
    );
  }

  // ─────────────────────────────────────────────
  // Writing
  // ─────────────────────────────────────────────

  /// Write a list of game records to PGN text
  String write(List<GameRecord> games) {
    final buffer = StringBuffer();

    for (int i = 0; i < games.length; i++) {
      if (i > 0) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(_writeGame(games[i]));
    }

    return buffer.toString();
  }

  /// Write a single game record to PGN text
  String writeSingle(GameRecord game) {
    return _writeGame(game);
  }

  String _writeGame(GameRecord game) {
    final buffer = StringBuffer();

    // Standard Seven Tag Roster + FEN/SetUp
    _writeTag(buffer, 'Event', game.event);
    _writeTag(buffer, 'Site', game.site);
    _writeTag(buffer, 'Date', game.date);
    _writeTag(buffer, 'Round', game.round);
    _writeTag(buffer, 'Red', game.redPlayer);
    _writeTag(buffer, 'Black', game.blackPlayer);
    _writeTag(buffer, 'Result', game.result.symbol);

    // FEN and SetUp tags for non-standard starting positions
    if (game.hasSetUp && game.fen != null) {
      _writeTag(buffer, 'SetUp', '1');
      _writeTag(buffer, 'FEN', game.fen!);
    }

    buffer.writeln();

    // Move text
    final moveText = _generateMoveText(game.gameTree, game.result);
    buffer.write(moveText);
    buffer.writeln();

    return buffer.toString();
  }

  void _writeTag(StringBuffer buffer, String tag, String value) {
    if (value.isEmpty) return;
    final escaped = value.replaceAll('"', '\\"');
    buffer.writeln('[$tag "$escaped"]');
  }

  /// Generate move text from a GameTree
  String _generateMoveText(GameTree gameTree, GameResult result) {
    if (gameTree.root.children.isEmpty) {
      return gameTree.root.move != null ? gameTree.root.comment : '';
    }

    final buffer = StringBuffer();
    final state = _MoveTextWriterState();

    // Remember current path to restore position later
    final savedPath = gameTree.current?.getPathFromRoot() ?? [];

    // Go to start
    gameTree.goToStart();

    _writeVariation(buffer, gameTree, state, result, 0);

    // Restore current position by navigating back
    gameTree.goToStart();
    for (final index in savedPath) {
      if (!gameTree.goForward(variationIndex: index)) break;
    }

    return buffer.toString();
  }

  void _writeVariation(
    StringBuffer buffer,
    GameTree gameTree,
    _MoveTextWriterState state,
    GameResult result,
    int depth,
  ) {
    while (gameTree.current?.hasChildren == true) {
      final node = gameTree.current!;

      final child = node.mainLineChild!;
      final move = child.move;
      if (move == null) break;

      // Write move number
      if (move.color == PieceColor.red) {
        state.halfMoveCount++;
        final moveNum = (state.halfMoveCount + 1) ~/ 2;
        buffer.write('$moveNum. ');
      } else {
        buffer.write('${_moveNumber(state.halfMoveCount)}... ');
      }
      state.halfMoveCount++;

      // Write move in ICCS
      final iccs = MoveNotation.toICCS(move);
      buffer.write('$iccs');

      // Write NAG annotations
      if (child.moveAnnotation?.isNotEmpty == true) {
        for (final nag in _parseNags(child.moveAnnotation!)) {
          buffer.write(' $nag');
        }
      }

      // Write comment
      if (child.comment.isNotEmpty) {
        buffer.write(' {${child.comment}}');
      }

      buffer.write(' ');

      // Write variations (children beyond the first)
      for (int i = 1; i < node.children.length; i++) {
        buffer.write('(');
        final variationChild = node.children[i];
        final variationMove = variationChild.move;
        if (variationMove != null) {
          final variationState = _MoveTextWriterState(
            halfMoveCount: state.halfMoveCount - 1,
          );

          // Navigate to variation
          gameTree.goForward(variationIndex: i);

          _writeVariationLine(buffer, gameTree, variationState, 0);

          // Go back
          gameTree.goBack();
        }
        buffer.write(') ');
      }

      // Go forward to main line child
      gameTree.goForward();
    }

    // Write result at end
    buffer.write(result.symbol);
  }

  void _writeVariationLine(
    StringBuffer buffer,
    GameTree gameTree,
    _MoveTextWriterState state,
    int depth,
  ) {
    while (gameTree.current?.hasChildren == true) {
      final node = gameTree.current!;
      final child = node.mainLineChild!;
      final move = child.move;
      if (move == null) break;

      // Write move number
      if (move.color == PieceColor.red) {
        state.halfMoveCount++;
        final moveNum = (state.halfMoveCount + 1) ~/ 2;
        buffer.write('$moveNum. ');
      } else {
        buffer.write('${_moveNumber(state.halfMoveCount)}... ');
      }
      state.halfMoveCount++;

      // Write move in ICCS
      buffer.write('${MoveNotation.toICCS(move)}');

      // Write annotations
      if (child.moveAnnotation?.isNotEmpty == true) {
        for (final nag in _parseNags(child.moveAnnotation!)) {
          buffer.write(' $nag');
        }
      }

      if (child.comment.isNotEmpty) {
        buffer.write(' {${child.comment}}');
      }

      buffer.write(' ');

      // Write sub-variations
      for (int i = 1; i < node.children.length; i++) {
        buffer.write('(');
        gameTree.goForward(variationIndex: i);

        final subState = _MoveTextWriterState(
          halfMoveCount: state.halfMoveCount - 1,
        );
        _writeVariationLine(buffer, gameTree, subState, depth + 1);

        gameTree.goBack();
        buffer.write(') ');
      }

      gameTree.goForward();
    }
  }

  int _moveNumber(int halfMoveCount) {
    return (halfMoveCount + 1) ~/ 2;
  }

  List<String> _parseNags(String annotation) {
    final nags = <String>[];
    final regex = RegExp(r'\$\d+');
    for (final match in regex.allMatches(annotation)) {
      nags.add(match.group(0)!);
    }
    return nags;
  }
}

/// Helper state for move text writing
class _MoveTextWriterState {
  _MoveTextWriterState({this.halfMoveCount = 0});
  int halfMoveCount;
}

/// Simple board implementation for move application during PGN parsing.
/// Mirrors the Board API needed by FenParser.parse/generate without
/// requiring the full Board model, keeping the PGN service self-contained.
class _SimpleBoard {
  _SimpleBoard();

  static const int boardCols = 9;
  static const int boardRows = 10;

  final Map<Position, ChessPiece> _pieces = {};

  ChessPiece? getPiece(Position pos) => _pieces[pos];

  void putPiece(ChessPiece piece) {
    _pieces[piece.position] = piece;
  }

  void removePiece(Position pos) {
    _pieces.remove(pos);
  }

  void clear() {
    _pieces.clear();
  }

  /// Convert piece type and color to FEN character
  static String _pieceToFenChar(PieceType type, PieceColor color) {
    final char = switch (type) {
      PieceType.general => 'k',
      PieceType.advisor => 'a',
      PieceType.elephant => 'b',
      PieceType.horse => 'n',
      PieceType.chariot => 'r',
      PieceType.cannon => 'c',
      PieceType.soldier => 'p',
    };
    return color == PieceColor.red ? char.toUpperCase() : char;
  }

  /// Convert FEN character to piece type and color
  static (PieceType, PieceColor)? _fenCharToPiece(String char) {
    if (char.isEmpty) return null;
    final lower = char.toLowerCase();
    final color = char == lower ? PieceColor.black : PieceColor.red;
    final type = switch (lower) {
      'k' => PieceType.general,
      'a' => PieceType.advisor,
      'b' => PieceType.elephant,
      'n' => PieceType.horse,
      'r' => PieceType.chariot,
      'c' => PieceType.cannon,
      'p' => PieceType.soldier,
      _ => null,
    };
    if (type == null) return null;
    return (type, color);
  }

  /// Generate FEN string from board state
  static String generateBoard(_SimpleBoard board, PieceColor activeColor) {
    final rows = <String>[];
    for (int row = 0; row < boardRows; row++) {
      int emptyCount = 0;
      String rowStr = '';
      for (int col = 0; col < boardCols; col++) {
        final piece = board.getPiece(Position(col, row));
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rowStr += emptyCount.toString();
            emptyCount = 0;
          }
          rowStr += _pieceToFenChar(piece.type, piece.color);
        }
      }
      if (emptyCount > 0) rowStr += emptyCount.toString();
      rows.add(rowStr);
    }
    final boardStr = rows.join('/');
    return '$boardStr ${activeColor == PieceColor.red ? "r" : "b"}';
  }

  /// Parse FEN string and populate the board
  static void parseBoard(String fen, _SimpleBoard board) {
    board.clear();

    final parts = fen.trim().split(' ');
    final boardStr = parts[0];

    final fenRows = boardStr.split('/');
    for (int row = 0; row < fenRows.length && row < boardRows; row++) {
      int col = 0;
      for (final char in fenRows[row].split('')) {
        final emptyCount = int.tryParse(char);
        if (emptyCount != null) {
          col += emptyCount;
        } else {
          final result = _fenCharToPiece(char);
          if (result != null) {
            final (type, color) = result;
            board.putPiece(
              ChessPiece(
                type: type,
                color: color,
                position: Position(col, row),
              ),
            );
          }
          col++;
        }
      }
    }
  }
}

/// Tokenizer for PGN move text
class _MoveTextTokenizer {
  _MoveTextTokenizer(String text) {
    _tokens = _tokenize(text);
  }

  late final List<String> _tokens;
  int _index = 0;

  static List<String> _tokenize(String text) {
    final tokens = <String>[];
    int i = 0;

    while (i < text.length) {
      final char = text[i];

      // Skip whitespace
      if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
        i++;
        continue;
      }

      // Braces for comments
      if (char == '{' || char == '}') {
        tokens.add(char);
        i++;
        continue;
      }

      // Parentheses for variations
      if (char == '(' || char == ')') {
        tokens.add(char);
        i++;
        continue;
      }

      // NAG annotations ($1, $2, etc.)
      if (char == '\$') {
        final start = i;
        i++;
        while (i < text.length && RegExp(r'\d').hasMatch(text[i])) {
          i++;
        }
        tokens.add(text.substring(start, i));
        continue;
      }

      // Move numbers and dots (e.g., "1.", "12.", or standalone "1")
      if (RegExp(r'\d').hasMatch(char)) {
        final start = i;
        while (i < text.length && RegExp(r'\d').hasMatch(text[i])) {
          i++;
        }
        if (i < text.length && text[i] == '.') {
          i++;
        }
        tokens.add(text.substring(start, i));
        continue;
      }

      // Results: 1-0, 0-1, 1/2-1/2, *
      if (char == '*' || char == '1' || char == '0') {
        // Check for result patterns
        if (i + 2 < text.length &&
            text.substring(i, i + 3) == '1/2' &&
            i + 6 < text.length &&
            text.substring(i, i + 7) == '1/2-1/2') {
          tokens.add('1/2-1/2');
          i += 7;
          continue;
        }
        if (i + 2 < text.length && text.substring(i, i + 3) == '1-0') {
          tokens.add('1-0');
          i += 3;
          continue;
        }
        if (i + 2 < text.length && text.substring(i, i + 3) == '0-1') {
          tokens.add('0-1');
          i += 3;
          continue;
        }
      }

      // Generic token (move notation, usually 4 digits for ICCS)
      final start = i;
      while (i < text.length &&
          text[i] != ' ' &&
          text[i] != '\t' &&
          text[i] != '\n' &&
          text[i] != '\r' &&
          text[i] != '{' &&
          text[i] != '}' &&
          text[i] != '(' &&
          text[i] != ')' &&
          text[i] != '\$' &&
          text[i] != '*') {
        i++;
      }
      if (i > start) {
        tokens.add(text.substring(start, i));
      }
    }

    return tokens;
  }

  bool isAtEnd() => _index >= _tokens.length;

  String peek() {
    if (isAtEnd()) return '';
    return _tokens[_index];
  }

  String? peekNext() {
    if (_index + 1 >= _tokens.length) return null;
    return _tokens[_index + 1];
  }

  String consume() {
    if (isAtEnd()) return '';
    return _tokens[_index++];
  }

  /// Read content until the specified delimiter is found
  String readUntil(String delimiter) {
    final buffer = StringBuffer();
    while (!isAtEnd()) {
      final token = consume();
      if (token == delimiter) {
        return buffer.toString();
      }
      buffer.write(token);
    }
    return buffer.toString();
  }
}
