// lib/stateManagement/setState/cell_structure.dart

/// 구조화된 셀의 한 줄을 나타냄 (접두사 + 컬럼명)
class CellStructureLine {
  final String prefix;
  final String columnName;

  const CellStructureLine({required this.columnName, this.prefix = ''});

  Map<String, dynamic> toJson() => {'prefix': prefix, 'columnName': columnName};

  factory CellStructureLine.fromJson(Map<String, dynamic> j) =>
      CellStructureLine(
        prefix: j['prefix'] as String? ?? '',
        columnName: j['columnName'] as String,
      );

  CellStructureLine copyWith({String? prefix, String? columnName}) =>
      CellStructureLine(
        prefix: prefix ?? this.prefix,
        columnName: columnName ?? this.columnName,
      );
}

/// 셀 하나에 여러 컬럼 값을 표시하는 구조
/// mainColumnName: 이 구조가 표시될 컬럼
/// lines: 표시될 줄 목록 (각 줄 = 접두사 + 컬럼값)
class CellStructure {
  final String mainColumnName;
  final List<CellStructureLine> lines;

  const CellStructure({required this.mainColumnName, required this.lines});

  /// mainColumnName 외에 흡수(숨김)될 컬럼 이름 집합
  Set<String> get absorbedColumns {
    final set = lines.map((l) => l.columnName).toSet();
    set.remove(mainColumnName);
    return set;
  }

  /// 행 데이터 → 표시용 문자열
  String format(Map<String, dynamic> rowData) {
    final sb = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      if (i > 0) sb.write('\n');
      final line = lines[i];
      sb.write(line.prefix);
      final val = rowData[line.columnName];
      sb.write(val?.toString() ?? '');
    }
    return sb.toString();
  }

  /// 표시용 문자열 → 컬럼별 값 Map
  Map<String, dynamic> parse(String displayText) {
    final result = <String, dynamic>{};
    final textLines = displayText.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      String text = i < textLines.length ? textLines[i] : '';
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
      };

  factory CellStructure.fromJson(Map<String, dynamic> j) => CellStructure(
        mainColumnName: j['mainColumnName'] as String,
        lines: (j['lines'] as List<dynamic>)
            .map((l) => CellStructureLine.fromJson(l as Map<String, dynamic>))
            .toList(),
      );

  CellStructure copyWith({
    String? mainColumnName,
    List<CellStructureLine>? lines,
  }) =>
      CellStructure(
        mainColumnName: mainColumnName ?? this.mainColumnName,
        lines: lines ?? this.lines,
      );
}
