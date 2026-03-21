// lib/stateManagement/setState/join_definition.dart
import 'dart:convert';

enum JoinType { inner, left, right, full }

extension JoinTypeExtension on JoinType {
  String get sql {
    switch (this) {
      case JoinType.inner: return 'INNER JOIN';
      case JoinType.left: return 'LEFT JOIN';
      case JoinType.right: return 'RIGHT JOIN';
      case JoinType.full: return 'FULL OUTER JOIN';
    }
  }

  String get label {
    switch (this) {
      case JoinType.inner: return 'INNER';
      case JoinType.left: return 'LEFT';
      case JoinType.right: return 'RIGHT';
      case JoinType.full: return 'FULL';
    }
  }
}

/// 하나의 JOIN 절을 나타냄
class JoinClause {
  final String targetTable;
  final JoinType joinType;
  final String leftColumn;   // mainTable 또는 이전 join 테이블의 컬럼
  final String leftTable;    // leftColumn이 속한 테이블
  final String rightColumn;  // targetTable의 컬럼

  const JoinClause({
    required this.targetTable,
    required this.joinType,
    required this.leftColumn,
    required this.leftTable,
    required this.rightColumn,
  });

  Map<String, dynamic> toJson() => {
    'targetTable': targetTable,
    'joinType': joinType.name,
    'leftColumn': leftColumn,
    'leftTable': leftTable,
    'rightColumn': rightColumn,
  };

  factory JoinClause.fromJson(Map<String, dynamic> j) => JoinClause(
    targetTable: j['targetTable'] as String,
    joinType: JoinType.values.firstWhere((e) => e.name == j['joinType']),
    leftColumn: j['leftColumn'] as String,
    leftTable: j['leftTable'] as String,
    rightColumn: j['rightColumn'] as String,
  );

  JoinClause copyWith({
    String? targetTable,
    JoinType? joinType,
    String? leftColumn,
    String? leftTable,
    String? rightColumn,
  }) => JoinClause(
    targetTable: targetTable ?? this.targetTable,
    joinType: joinType ?? this.joinType,
    leftColumn: leftColumn ?? this.leftColumn,
    leftTable: leftTable ?? this.leftTable,
    rightColumn: rightColumn ?? this.rightColumn,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JoinClause &&
          targetTable == other.targetTable &&
          joinType == other.joinType &&
          leftColumn == other.leftColumn &&
          leftTable == other.leftTable &&
          rightColumn == other.rightColumn;

  @override
  int get hashCode => Object.hash(targetTable, joinType, leftColumn, leftTable, rightColumn);
}

/// JOIN 뷰 정의 - 여러 테이블을 결합하는 논리적 테이블
class JoinDefinition {
  final String name;          // 뷰 표시 이름
  final String mainTable;     // FROM 절의 기본 테이블
  final List<JoinClause> joins;

  const JoinDefinition({
    required this.name,
    required this.mainTable,
    required this.joins,
  });

  /// 참여하는 모든 테이블 이름 (중복 제거, 순서 유지)
  List<String> get allTables {
    final result = <String>[mainTable];
    for (final j in joins) {
      if (!result.contains(j.targetTable)) result.add(j.targetTable);
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'mainTable': mainTable,
    'joins': joins.map((j) => j.toJson()).toList(),
  };

  factory JoinDefinition.fromJson(Map<String, dynamic> j) => JoinDefinition(
    name: j['name'] as String,
    mainTable: j['mainTable'] as String,
    joins: (j['joins'] as List<dynamic>)
        .map((e) => JoinClause.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  JoinDefinition copyWith({
    String? name,
    String? mainTable,
    List<JoinClause>? joins,
  }) => JoinDefinition(
    name: name ?? this.name,
    mainTable: mainTable ?? this.mainTable,
    joins: joins ?? this.joins,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JoinDefinition) return false;
    if (name != other.name || mainTable != other.mainTable) return false;
    if (joins.length != other.joins.length) return false;
    for (int i = 0; i < joins.length; i++) {
      if (joins[i] != other.joins[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(name, mainTable, Object.hashAll(joins));

  /// SharedPreferences 저장 키
  static String prefsKey(String serverAddress, String database) =>
      'join_definitions|$serverAddress|$database';

  /// 저장된 JoinDefinition 목록 로드
  static List<JoinDefinition> fromPrefsString(String? raw) {
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => JoinDefinition.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// JoinDefinition 목록을 JSON 문자열로 변환
  static String toPrefsString(List<JoinDefinition> defs) =>
      jsonEncode(defs.map((d) => d.toJson()).toList());
}
