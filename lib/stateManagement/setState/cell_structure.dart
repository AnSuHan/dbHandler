// lib/stateManagement/setState/cell_structure.dart

// ── 수식 평가기 ────────────────────────────────────────────────
// 산술식 (+ - * / 괄호) + 컬럼명 참조를 지원하는 단순 파서

class _ExprEvaluator {
  final String _expr;
  final Map<String, dynamic> _row;
  int _pos = 0;

  _ExprEvaluator(this._expr, this._row);

  double evaluate() => _addSub();

  double _addSub() {
    var v = _mulDiv();
    while (true) {
      _skip();
      if (_pos >= _expr.length) break;
      if (_expr[_pos] == '+') { _pos++; v += _mulDiv(); }
      else if (_expr[_pos] == '-') { _pos++; v -= _mulDiv(); }
      else break;
    }
    return v;
  }

  double _mulDiv() {
    var v = _unary();
    while (true) {
      _skip();
      if (_pos >= _expr.length) break;
      if (_expr[_pos] == '*') {
        _pos++; v *= _unary();
      } else if (_expr[_pos] == '/') {
        _pos++;
        final d = _unary();
        v = d != 0 ? v / d : double.nan;
      } else break;
    }
    return v;
  }

  double _unary() {
    _skip();
    if (_pos < _expr.length && _expr[_pos] == '-') { _pos++; return -_primary(); }
    if (_pos < _expr.length && _expr[_pos] == '+') { _pos++; }
    return _primary();
  }

  double _primary() {
    _skip();
    if (_pos >= _expr.length) throw FormatException('수식 오류: 예상치 못한 끝');

    // 괄호
    if (_expr[_pos] == '(') {
      _pos++;
      final v = _addSub();
      _skip();
      if (_pos < _expr.length && _expr[_pos] == ')') _pos++;
      return v;
    }

    // 숫자 리터럴
    final c = _expr.codeUnitAt(_pos);
    if ((c >= 48 && c <= 57) || _expr[_pos] == '.') {
      final start = _pos;
      while (_pos < _expr.length) {
        final cc = _expr.codeUnitAt(_pos);
        if ((cc >= 48 && cc <= 57) || _expr[_pos] == '.') {
          _pos++;
        } else break;
      }
      return double.parse(_expr.substring(start, _pos));
    }

    // 식별자 (컬럼명)
    if (_isIdentStart(c)) {
      final start = _pos;
      while (_pos < _expr.length && _isIdent(_expr.codeUnitAt(_pos))) _pos++;
      final name = _expr.substring(start, _pos);
      final val = _row[name];
      if (val == null) return 0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0;
    }

    throw FormatException('수식 오류: 알 수 없는 문자 "${_expr[_pos]}"');
  }

  void _skip() {
    while (_pos < _expr.length && _expr[_pos] == ' ') _pos++;
  }

  bool _isIdentStart(int c) =>
      (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
  bool _isIdent(int c) => _isIdentStart(c) || (c >= 48 && c <= 57);
}

// ── CellStructureLine ──────────────────────────────────────────

/// 구조화된 셀의 한 줄을 나타냄
/// - 일반 줄: prefix + columnName 값
/// - 수식 줄: prefix + evaluate(expression)
class CellStructureLine {
  final String prefix;
  /// 컬럼 직접 참조 시 사용. isExpression이면 '' (빈 문자열).
  final String columnName;
  /// 수식 문자열. 예) "a + b + c", "a * 0.1". null/빈 문자열이면 컬럼 직접 참조.
  final String? expression;

  bool get isExpression => expression != null && expression!.isNotEmpty;

  /// 이 줄이 참조하는 컬럼 이름 집합
  Set<String> get referencedColumns {
    if (isExpression) {
      // 수식에서 식별자(컬럼명) 추출
      final result = <String>{};
      final regex = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*');
      for (final m in regex.allMatches(expression!)) {
        result.add(m.group(0)!);
      }
      return result;
    }
    return columnName.isNotEmpty ? {columnName} : {};
  }

  const CellStructureLine({
    required this.columnName,
    this.prefix = '',
    this.expression,
  });

  Map<String, dynamic> toJson() => {
        'prefix': prefix,
        'columnName': columnName,
        if (expression != null && expression!.isNotEmpty) 'expression': expression,
      };

  factory CellStructureLine.fromJson(Map<String, dynamic> j) => CellStructureLine(
        prefix: j['prefix'] as String? ?? '',
        columnName: j['columnName'] as String? ?? '',
        expression: j['expression'] as String?,
      );

  CellStructureLine copyWith({
    String? prefix,
    String? columnName,
    String? expression,
  }) =>
      CellStructureLine(
        prefix: prefix ?? this.prefix,
        columnName: columnName ?? this.columnName,
        expression: expression ?? this.expression,
      );
}

// ── CellStructure ──────────────────────────────────────────────

/// 셀 하나에 여러 컬럼 값(또는 수식)을 표시하는 구조
class CellStructure {
  final String mainColumnName;
  final List<CellStructureLine> lines;
  final String? displayName;

  const CellStructure({
    required this.mainColumnName,
    required this.lines,
    this.displayName,
  });

  /// 실제 헤더 표시 이름 (displayName 우선, 없으면 mainColumnName)
  String get effectiveDisplayName =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : mainColumnName;

  /// mainColumnName 외에 흡수(숨김)될 컬럼 집합
  /// 수식 줄이 참조하는 컬럼도 포함
  Set<String> get absorbedColumns {
    final set = <String>{};
    for (final line in lines) {
      set.addAll(line.referencedColumns);
    }
    set.remove(mainColumnName);
    return set;
  }

  /// 이 구조에서 편집 가능한 모든 컬럼 (수식 참조 포함, 중복 제거, 등장 순서 유지)
  List<String> get editableColumns {
    final seen = <String>{};
    final result = <String>[];
    for (final line in lines) {
      for (final col in line.referencedColumns) {
        if (seen.add(col)) result.add(col);
      }
    }
    return result;
  }

  /// 행 데이터 → 표시용 문자열 (수식은 계산 결과로 대체)
  String format(Map<String, dynamic> rowData) {
    final sb = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      if (i > 0) sb.write('\n');
      final line = lines[i];
      sb.write(line.prefix);
      if (line.isExpression) {
        try {
          final result = _ExprEvaluator(line.expression!, rowData).evaluate();
          if (result.isNaN || result.isInfinite) {
            sb.write('?');
          } else if (result == result.truncateToDouble()) {
            sb.write(result.truncate());
          } else {
            // 소수점 불필요한 0 제거 (예: 1.50 → 1.5)
            sb.write(double.parse(result.toStringAsFixed(10))
                .toStringAsFixed(10)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), ''));
          }
        } catch (_) {
          sb.write('?');
        }
      } else {
        sb.write(rowData[line.columnName]?.toString() ?? '');
      }
    }
    return sb.toString();
  }

  /// 표시용 텍스트 → 컬럼별 값 Map (수식 줄은 건너뜀)
  Map<String, dynamic> parse(String displayText) {
    final result = <String, dynamic>{};
    final textLines = displayText.split('\n');
    int lineIdx = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isExpression) {
        lineIdx++;
        continue;
      }
      String text = lineIdx < textLines.length ? textLines[lineIdx] : '';
      lineIdx++;
      if (line.prefix.isNotEmpty && text.startsWith(line.prefix)) {
        text = text.substring(line.prefix.length);
      }
      result[line.columnName] = text.isEmpty ? null : text;
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'mainColumnName': mainColumnName,
        'lines': lines.map((l) => l.toJson()).toList(),
        if (displayName != null && displayName!.isNotEmpty)
          'displayName': displayName,
      };

  factory CellStructure.fromJson(Map<String, dynamic> j) => CellStructure(
        mainColumnName: j['mainColumnName'] as String,
        lines: (j['lines'] as List<dynamic>)
            .map((l) => CellStructureLine.fromJson(l as Map<String, dynamic>))
            .toList(),
        displayName: j['displayName'] as String?,
      );

  CellStructure copyWith({
    String? mainColumnName,
    List<CellStructureLine>? lines,
    String? displayName,
  }) =>
      CellStructure(
        mainColumnName: mainColumnName ?? this.mainColumnName,
        lines: lines ?? this.lines,
        displayName: displayName ?? this.displayName,
      );
}
