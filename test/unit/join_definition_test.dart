// test/unit/join_definition_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/stateManagement/setState/join_definition.dart';

void main() {
  // ──────────────────────────────────────────────
  // JoinType extension
  // ──────────────────────────────────────────────
  group('JoinType sql / label', () {
    test('inner', () {
      expect(JoinType.inner.sql, 'INNER JOIN');
      expect(JoinType.inner.label, 'INNER');
    });
    test('left', () {
      expect(JoinType.left.sql, 'LEFT JOIN');
      expect(JoinType.left.label, 'LEFT');
    });
    test('right', () {
      expect(JoinType.right.sql, 'RIGHT JOIN');
      expect(JoinType.right.label, 'RIGHT');
    });
    test('full', () {
      expect(JoinType.full.sql, 'FULL OUTER JOIN');
      expect(JoinType.full.label, 'FULL');
    });
  });

  // ──────────────────────────────────────────────
  // JoinClause
  // ──────────────────────────────────────────────
  group('JoinClause', () {
    const clause = JoinClause(
      targetTable: 'orders',
      joinType: JoinType.left,
      leftColumn: 'id',
      leftTable: 'users',
      rightColumn: 'user_id',
    );

    test('toJson / fromJson 왕복', () {
      final json = clause.toJson();
      final restored = JoinClause.fromJson(json);
      expect(restored, equals(clause));
    });

    test('copyWith 특정 필드만 변경', () {
      final updated = clause.copyWith(joinType: JoinType.inner);
      expect(updated.joinType, JoinType.inner);
      expect(updated.targetTable, clause.targetTable);
      expect(updated.leftColumn, clause.leftColumn);
    });

    test('동등 비교 - 같은 값이면 true', () {
      const other = JoinClause(
        targetTable: 'orders',
        joinType: JoinType.left,
        leftColumn: 'id',
        leftTable: 'users',
        rightColumn: 'user_id',
      );
      expect(clause, equals(other));
      expect(clause.hashCode, equals(other.hashCode));
    });

    test('동등 비교 - 다른 joinType이면 false', () {
      final other = clause.copyWith(joinType: JoinType.inner);
      expect(clause, isNot(equals(other)));
    });

    test('fromJson에서 joinType 이름으로 복원', () {
      final json = {'targetTable': 'tbl', 'joinType': 'full', 'leftColumn': 'a', 'leftTable': 'src', 'rightColumn': 'b'};
      final c = JoinClause.fromJson(json);
      expect(c.joinType, JoinType.full);
    });
  });

  // ──────────────────────────────────────────────
  // JoinDefinition
  // ──────────────────────────────────────────────
  group('JoinDefinition', () {
    final def = JoinDefinition(
      name: '주문-사용자',
      mainTable: 'orders',
      joins: [
        const JoinClause(
          targetTable: 'users',
          joinType: JoinType.inner,
          leftColumn: 'user_id',
          leftTable: 'orders',
          rightColumn: 'id',
        ),
        const JoinClause(
          targetTable: 'products',
          joinType: JoinType.left,
          leftColumn: 'product_id',
          leftTable: 'orders',
          rightColumn: 'id',
        ),
      ],
    );

    test('allTables: mainTable + 중복 없는 targetTable 목록', () {
      expect(def.allTables, ['orders', 'users', 'products']);
    });

    test('allTables: 중복된 targetTable은 한 번만 포함', () {
      final dupDef = JoinDefinition(
        name: 'dup',
        mainTable: 'a',
        joins: [
          const JoinClause(targetTable: 'b', joinType: JoinType.inner, leftColumn: 'x', leftTable: 'a', rightColumn: 'y'),
          const JoinClause(targetTable: 'b', joinType: JoinType.left,  leftColumn: 'x', leftTable: 'a', rightColumn: 'y'),
        ],
      );
      expect(dupDef.allTables, ['a', 'b']);
    });

    test('allTables: join 없으면 mainTable만 반환', () {
      final simple = JoinDefinition(name: 'n', mainTable: 'tbl', joins: []);
      expect(simple.allTables, ['tbl']);
    });

    test('toJson / fromJson 왕복', () {
      final json = def.toJson();
      final restored = JoinDefinition.fromJson(json);
      expect(restored, equals(def));
    });

    test('copyWith 이름만 변경', () {
      final updated = def.copyWith(name: '새이름');
      expect(updated.name, '새이름');
      expect(updated.mainTable, def.mainTable);
      expect(updated.joins.length, def.joins.length);
    });

    test('동등 비교 - 같은 값이면 true', () {
      final other = JoinDefinition.fromJson(def.toJson());
      expect(def, equals(other));
      expect(def.hashCode, equals(other.hashCode));
    });

    test('동등 비교 - join 순서가 달라도 false', () {
      final swapped = def.copyWith(joins: [def.joins[1], def.joins[0]]);
      expect(def, isNot(equals(swapped)));
    });

    test('동등 비교 - joins 개수 다르면 false', () {
      final fewer = def.copyWith(joins: [def.joins[0]]);
      expect(def, isNot(equals(fewer)));
    });
  });

  // ──────────────────────────────────────────────
  // JoinDefinition JSON 직렬화 (fromPrefsString / toPrefsString)
  // ──────────────────────────────────────────────
  group('JoinDefinition prefs 직렬화', () {
    final defs = [
      JoinDefinition(
        name: 'v1',
        mainTable: 'a',
        joins: [
          const JoinClause(targetTable: 'b', joinType: JoinType.right, leftColumn: 'c', leftTable: 'a', rightColumn: 'd'),
        ],
      ),
      const JoinDefinition(name: 'v2', mainTable: 'x', joins: []),
    ];

    test('toPrefsString → fromPrefsString 왕복', () {
      final raw = JoinDefinition.toPrefsString(defs);
      final restored = JoinDefinition.fromPrefsString(raw);
      expect(restored.length, defs.length);
      for (int i = 0; i < defs.length; i++) {
        expect(restored[i], equals(defs[i]));
      }
    });

    test('fromPrefsString(null)은 빈 목록 반환', () {
      expect(JoinDefinition.fromPrefsString(null), isEmpty);
    });

    test('fromPrefsString(잘못된 JSON)은 빈 목록 반환', () {
      expect(JoinDefinition.fromPrefsString('not-json'), isEmpty);
    });

    test('prefsKey 형식 확인', () {
      final key = JoinDefinition.prefsKey('localhost:5432', 'mydb');
      expect(key, 'join_definitions|localhost:5432|mydb');
    });
  });
}
