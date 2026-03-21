// lib/views/unit/join_table_dialog.dart
import 'package:flutter/material.dart';
import '../../db/database_handler.dart';
import '../../stateManagement/setState/join_definition.dart';

/// JOIN 뷰 생성/편집 다이얼로그
Future<JoinDefinition?> showJoinTableDialog({
  required BuildContext context,
  required DatabaseHandler dbHandler,
  required String database,
  required List<String> availableTables,
  JoinDefinition? existingDefinition,
}) {
  return showDialog<JoinDefinition>(
    context: context,
    builder: (ctx) => _JoinTableDialog(
      dbHandler: dbHandler,
      database: database,
      availableTables: availableTables,
      existingDefinition: existingDefinition,
    ),
  );
}

class _JoinTableDialog extends StatefulWidget {
  final DatabaseHandler dbHandler;
  final String database;
  final List<String> availableTables;
  final JoinDefinition? existingDefinition;

  const _JoinTableDialog({
    required this.dbHandler,
    required this.database,
    required this.availableTables,
    this.existingDefinition,
  });

  @override
  State<_JoinTableDialog> createState() => _JoinTableDialogState();
}

class _JoinTableDialogState extends State<_JoinTableDialog> {
  late final TextEditingController _nameController;
  String? _mainTable;
  final List<_JoinClauseState> _joinClauses = [];

  // 테이블별 컬럼 캐시: {name, type}
  final Map<String, List<Map<String, String>>> _columnCache = {};
  bool _isLoadingColumns = false;

  @override
  void initState() {
    super.initState();
    final def = widget.existingDefinition;
    _nameController = TextEditingController(text: def?.name ?? '');
    _mainTable = def?.mainTable;

    if (def != null) {
      for (final j in def.joins) {
        _joinClauses.add(_JoinClauseState(
          targetTable: j.targetTable,
          joinType: j.joinType,
          leftTable: j.leftTable,
          leftColumn: j.leftColumn,
          rightColumn: j.rightColumn,
        ));
      }
    }

    if (_mainTable != null) {
      _loadColumnsForTable(_mainTable!);
    }
    for (final jc in _joinClauses) {
      if (jc.targetTable != null) _loadColumnsForTable(jc.targetTable!);
      _loadColumnsForTable(jc.leftTable ?? _mainTable ?? '');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadColumnsForTable(String tableName) async {
    if (tableName.isEmpty || _columnCache.containsKey(tableName)) return;
    setState(() => _isLoadingColumns = true);
    try {
      final columns = await widget.dbHandler.getColumns(tableName);
      _columnCache[tableName] = columns
          .map((c) => {'name': c['name'] as String, 'type': c['type'] as String})
          .toList();
    } catch (_) {
      _columnCache[tableName] = [];
    }
    if (mounted) setState(() => _isLoadingColumns = false);
  }

  /// 두 컬럼의 타입이 호환 가능한지 확인
  bool _areTypesCompatible(String? table1, String? col1, String? table2, String? col2) {
    if (table1 == null || col1 == null || table2 == null || col2 == null) return true;
    final cols1 = _columnCache[table1] ?? [];
    final cols2 = _columnCache[table2] ?? [];
    final type1 = cols1.firstWhere((c) => c['name'] == col1, orElse: () => {})['type'];
    final type2 = cols2.firstWhere((c) => c['name'] == col2, orElse: () => {})['type'];
    if (type1 == null || type2 == null) return true;
    return _typeGroup(type1) == _typeGroup(type2);
  }

  /// 타입을 대분류로 묶기
  String _typeGroup(String type) {
    final t = type.toLowerCase();
    if (t.contains('int') || t.contains('serial') || t.contains('numeric') ||
        t.contains('decimal') || t.contains('float') || t.contains('double') ||
        t.contains('real') || t.contains('number')) return 'numeric';
    if (t.contains('char') || t.contains('text') || t.contains('string') ||
        t.contains('varchar') || t.contains('enum')) return 'text';
    if (t.contains('bool')) return 'bool';
    if (t.contains('date') || t.contains('time') || t.contains('timestamp')) return 'datetime';
    return t;
  }

  List<String> _columnNames(String? tableName) {
    if (tableName == null) return [];
    return (_columnCache[tableName] ?? []).map((c) => c['name']!).toList();
  }

  String _columnType(String? tableName, String? colName) {
    if (tableName == null || colName == null) return '';
    final col = (_columnCache[tableName] ?? [])
        .firstWhere((c) => c['name'] == colName, orElse: () => {});
    return col['type'] ?? '';
  }

  /// 현재까지 참여하는 모든 테이블 이름
  List<String> get _participatingTables {
    final tables = <String>[];
    if (_mainTable != null) tables.add(_mainTable!);
    for (final jc in _joinClauses) {
      if (jc.targetTable != null && !tables.contains(jc.targetTable)) {
        tables.add(jc.targetTable!);
      }
    }
    return tables;
  }

  /// 특정 join 절의 왼쪽(ON 좌측)에 올 수 있는 테이블 목록
  List<String> _leftTableOptions(int joinIndex) {
    final tables = <String>[];
    if (_mainTable != null) tables.add(_mainTable!);
    for (int i = 0; i < joinIndex; i++) {
      if (_joinClauses[i].targetTable != null &&
          !tables.contains(_joinClauses[i].targetTable)) {
        tables.add(_joinClauses[i].targetTable!);
      }
    }
    return tables;
  }

  void _addJoinClause() {
    setState(() {
      _joinClauses.add(_JoinClauseState(joinType: JoinType.inner));
    });
  }

  void _removeJoinClause(int index) {
    setState(() {
      _joinClauses.removeAt(index);
    });
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_mainTable == null) return false;
    if (_joinClauses.isEmpty) return false;
    for (final jc in _joinClauses) {
      if (jc.targetTable == null || jc.leftTable == null ||
          jc.leftColumn == null || jc.rightColumn == null) {
        return false;
      }
    }
    return true;
  }

  void _save() {
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 필드를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final joinDef = JoinDefinition(
      name: _nameController.text.trim(),
      mainTable: _mainTable!,
      joins: _joinClauses.map((jc) => JoinClause(
        targetTable: jc.targetTable!,
        joinType: jc.joinType,
        leftTable: jc.leftTable!,
        leftColumn: jc.leftColumn!,
        rightColumn: jc.rightColumn!,
      )).toList(),
    );

    Navigator.of(context).pop(joinDef);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingDefinition != null;

    return AlertDialog(
      title: Text(isEditing ? 'JOIN 뷰 수정' : 'JOIN 뷰 생성'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 뷰 이름
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '뷰 이름',
                  border: OutlineInputBorder(),
                  hintText: '표시할 이름을 입력하세요',
                ),
              ),
              const SizedBox(height: 16),

              // 기본 테이블 선택
              DropdownButtonFormField<String>(
                value: _mainTable,
                decoration: const InputDecoration(
                  labelText: '기본 테이블 (FROM)',
                  border: OutlineInputBorder(),
                ),
                items: widget.availableTables
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _mainTable = v;
                    // 기본 테이블 변경 시 join 절의 leftTable 초기화
                    for (final jc in _joinClauses) {
                      jc.leftTable = null;
                      jc.leftColumn = null;
                    }
                  });
                  if (v != null) _loadColumnsForTable(v);
                },
              ),
              const SizedBox(height: 24),

              // JOIN 절 목록
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('JOIN 조건',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    onPressed: _mainTable != null ? _addJoinClause : null,
                    icon: const Icon(Icons.add),
                    label: const Text('JOIN 추가'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_joinClauses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'JOIN 조건을 추가해주세요.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),

              ..._joinClauses.asMap().entries.map((entry) {
                final index = entry.key;
                final jc = entry.value;
                return _buildJoinClauseCard(index, jc);
              }),

              if (_isLoadingColumns)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? '수정' : '생성'),
        ),
      ],
    );
  }

  Widget _buildJoinClauseCard(int index, _JoinClauseState jc) {
    final leftTables = _leftTableOptions(index);
    // 사용 가능한 target 테이블: 아직 join에 사용되지 않은 테이블
    final usedTargets = <String>{if (_mainTable != null) _mainTable!};
    for (int i = 0; i < _joinClauses.length; i++) {
      if (i != index && _joinClauses[i].targetTable != null) {
        usedTargets.add(_joinClauses[i].targetTable!);
      }
    }
    final availableTargets = widget.availableTables
        .where((t) => !usedTargets.contains(t) || t == jc.targetTable)
        .toList();

    final leftColumns = _columnNames(jc.leftTable);
    final rightColumns = _columnNames(jc.targetTable);
    final typeMismatch = !_areTypesCompatible(
        jc.leftTable, jc.leftColumn, jc.targetTable, jc.rightColumn);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('JOIN #${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                // JOIN 타입 선택
                DropdownButton<JoinType>(
                  value: jc.joinType,
                  items: JoinType.values.map((t) {
                    final supported = widget.dbHandler.supportedJoinTypes.contains(t);
                    return DropdownMenuItem(
                      value: t,
                      enabled: supported,
                      child: Text(
                        supported ? t.label : '${t.label} (미지원)',
                        style: TextStyle(
                          color: supported ? null : Colors.grey,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => jc.joinType = v);
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _removeJoinClause(index),
                  tooltip: '삭제',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Target 테이블 선택
            DropdownButtonFormField<String>(
              value: jc.targetTable,
              decoration: const InputDecoration(
                labelText: 'JOIN 대상 테이블',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: availableTargets
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  jc.targetTable = v;
                  jc.rightColumn = null;
                });
                if (v != null) _loadColumnsForTable(v);
              },
            ),
            const SizedBox(height: 12),

            // ON 조건: left.column = right.column
            const Text('ON 조건', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                // 왼쪽 테이블
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: jc.leftTable,
                    decoration: const InputDecoration(
                      labelText: '왼쪽 테이블',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: leftTables
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        jc.leftTable = v;
                        jc.leftColumn = null;
                      });
                      if (v != null) _loadColumnsForTable(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 왼쪽 컬럼
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: jc.leftColumn,
                    decoration: const InputDecoration(
                      labelText: '왼쪽 컬럼',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: leftColumns.map((c) {
                      final t = _columnType(jc.leftTable, c);
                      return DropdownMenuItem(
                        value: c,
                        child: Text(t.isNotEmpty ? '$c ($t)' : c,
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => jc.leftColumn = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(child: Text('=', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Row(
              children: [
                // 오른쪽 테이블 (target, 고정)
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '오른쪽 테이블',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(jc.targetTable ?? '-'),
                  ),
                ),
                const SizedBox(width: 8),
                // 오른쪽 컬럼
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: jc.rightColumn,
                    decoration: const InputDecoration(
                      labelText: '오른쪽 컬럼',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: rightColumns.map((c) {
                      final t = _columnType(jc.targetTable, c);
                      return DropdownMenuItem(
                        value: c,
                        child: Text(t.isNotEmpty ? '$c ($t)' : c,
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => jc.rightColumn = v),
                  ),
                ),
              ],
            ),
            if (typeMismatch) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '타입 불일치: ${_columnType(jc.leftTable, jc.leftColumn)} ≠ ${_columnType(jc.targetTable, jc.rightColumn)}\n'
                        'JOIN 결과가 비어있거나 오류가 발생할 수 있습니다.',
                        style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// JOIN 절 편집 상태
class _JoinClauseState {
  String? targetTable;
  JoinType joinType;
  String? leftTable;
  String? leftColumn;
  String? rightColumn;

  _JoinClauseState({
    this.targetTable,
    this.joinType = JoinType.inner,
    this.leftTable,
    this.leftColumn,
    this.rightColumn,
  });
}
