// lib/stateManagement/setState/data_editing_riverpod.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_handler.dart';
import '../../db/postgres_handler.dart';
import '../../sqflite/models/server_model.dart';
import 'cell_structure.dart';

/// 필터 조건 클래스
class FilterCondition {
  String columnName;
  String operator;
  dynamic value;
  String? logicalOperator;
  int? openGroupCount;
  int? closeGroupCount;
  bool isNegated;
  
  FilterCondition({
    required this.columnName,
    required this.operator,
    this.value,
    this.logicalOperator,
    this.openGroupCount,
    this.closeGroupCount,
    this.isNegated = false,
  });
  
  // logicalOperator를 명시적으로 null로 설정할 수 있도록 sentinel 패턴 사용
  static const Object _unset = Object();

  FilterCondition copyWith({
    String? columnName,
    String? operator,
    dynamic value,
    Object? logicalOperator = _unset,
    int? openGroupCount,
    int? closeGroupCount,
    bool? isNegated,
  }) {
    return FilterCondition(
      columnName: columnName ?? this.columnName,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      logicalOperator: identical(logicalOperator, _unset)
          ? this.logicalOperator
          : logicalOperator as String?,
      openGroupCount: openGroupCount ?? this.openGroupCount,
      closeGroupCount: closeGroupCount ?? this.closeGroupCount,
      isNegated: isNegated ?? this.isNegated,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'column': columnName,
      'operator': operator,
      'value': value,
      'logicalOperator': logicalOperator,
      'openGroupCount': openGroupCount,
      'closeGroupCount': closeGroupCount,
      'isNegated': isNegated,
    };
  }
}

/// 정렬 조건 클래스
class SortCondition {
  final String columnName;
  final bool ascending;
  
  const SortCondition({
    required this.columnName,
    this.ascending = true,
  });
  
  SortCondition copyWith({
    String? columnName,
    bool? ascending,
  }) {
    return SortCondition(
      columnName: columnName ?? this.columnName,
      ascending: ascending ?? this.ascending,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'column': columnName,
      'ascending': ascending,
    };
  }
}

/// DataEditing 상태 클래스
class DataEditingState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, String>> columns;
  final String? primaryKeyColumn;
  final List<double> columnWidths;
  final List<double> minColumnWidths;
  final int? selectedColumnIndex;
  final int? selectedRowIndex;
  final Map<String, int>? selectedCell;
  final Map<String, int>? selectedCellRange;
  final Map<String, int> cellVersions;
  final List<FilterCondition> filters;
  final List<SortCondition> sorts;
  final List<String> groupByColumns;
  final Map<String, CellStructure> cellStructures;
  final bool isDisplayMode;

  // UI 호환성을 위한 게터들 (기존 코드에서 참조됨)
  final List<Map<String, dynamic>>? filterBlocks;
  final List<bool>? filterParenthesis;
  final List<String>? filterOperators;

  const DataEditingState({
    this.isLoading = true,
    this.error,
    this.rows = const [],
    this.columns = const [],
    this.primaryKeyColumn,
    this.columnWidths = const [],
    this.minColumnWidths = const [],
    this.selectedColumnIndex,
    this.selectedRowIndex,
    this.selectedCell,
    this.selectedCellRange,
    this.cellVersions = const {},
    this.filters = const [],
    this.sorts = const [],
    this.groupByColumns = const [],
    this.cellStructures = const {},
    this.isDisplayMode = false,
    this.filterBlocks,
    this.filterParenthesis,
    this.filterOperators,
  });

  DataEditingState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? rows,
    List<Map<String, String>>? columns,
    String? primaryKeyColumn,
    List<double>? columnWidths,
    List<double>? minColumnWidths,
    int? selectedColumnIndex,
    int? selectedRowIndex,
    Map<String, int>? selectedCell,
    Map<String, int>? selectedCellRange,
    Map<String, int>? cellVersions,
    List<FilterCondition>? filters,
    List<SortCondition>? sorts,
    List<String>? groupByColumns,
    Map<String, CellStructure>? cellStructures,
    bool? isDisplayMode,
    List<Map<String, dynamic>>? filterBlocks,
    List<bool>? filterParenthesis,
    List<String>? filterOperators,
  }) {
    return DataEditingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      primaryKeyColumn: primaryKeyColumn ?? this.primaryKeyColumn,
      columnWidths: columnWidths ?? this.columnWidths,
      minColumnWidths: minColumnWidths ?? this.minColumnWidths,
      selectedColumnIndex: selectedColumnIndex ?? this.selectedColumnIndex,
      selectedRowIndex: selectedRowIndex ?? this.selectedRowIndex,
      selectedCell: selectedCell ?? this.selectedCell,
      selectedCellRange: selectedCellRange ?? this.selectedCellRange,
      cellVersions: cellVersions ?? this.cellVersions,
      filters: filters ?? this.filters,
      sorts: sorts ?? this.sorts,
      groupByColumns: groupByColumns ?? this.groupByColumns,
      cellStructures: cellStructures ?? this.cellStructures,
      isDisplayMode: isDisplayMode ?? this.isDisplayMode,
      filterBlocks: filterBlocks ?? this.filterBlocks,
      filterParenthesis: filterParenthesis ?? this.filterParenthesis,
      filterOperators: filterOperators ?? this.filterOperators,
    );
  }

  Set<String> getSelectedCellKeys() {
    if (selectedCellRange == null) {
      if (selectedCell != null) return {'${selectedCell!['rowIndex']}_${selectedCell!['colIndex']}'};
      return {};
    }
    final minRow = math.min(selectedCellRange!['startRow']!, selectedCellRange!['endRow']!);
    final maxRow = math.max(selectedCellRange!['startRow']!, selectedCellRange!['endRow']!);
    final minCol = math.min(selectedCellRange!['startCol']!, selectedCellRange!['endCol']!);
    final maxCol = math.max(selectedCellRange!['startCol']!, selectedCellRange!['endCol']!);
    final keys = <String>{};
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) keys.add('${r}_$c');
    }
    return keys;
  }

  bool isCellInRange(int rowIndex, int colIndex) {
    if (selectedCellRange == null) {
      if (selectedCell != null) return selectedCell!['rowIndex'] == rowIndex && selectedCell!['colIndex'] == colIndex;
      return false;
    }
    final minRow = math.min(selectedCellRange!['startRow']!, selectedCellRange!['endRow']!);
    final maxRow = math.max(selectedCellRange!['startRow']!, selectedCellRange!['endRow']!);
    final minCol = math.min(selectedCellRange!['startCol']!, selectedCellRange!['endCol']!);
    final maxCol = math.max(selectedCellRange!['startCol']!, selectedCellRange!['endCol']!);
    return rowIndex >= minRow && rowIndex <= maxRow && colIndex >= minCol && colIndex <= maxCol;
  }
  
  Map<String, int>? getTopLeftSelectedCell() {
    if (selectedCellRange == null) return selectedCell;
    return {
      'rowIndex': math.min(selectedCellRange!['startRow']!, selectedCellRange!['endRow']!),
      'colIndex': math.min(selectedCellRange!['startCol']!, selectedCellRange!['endCol']!)
    };
  }
}

class DataEditingNotifier extends StateNotifier<DataEditingState> {
  final DatabaseHandler _dbHandler;
  final String _table;
  final String _serverAddress;
  final String _database;

  DataEditingNotifier(this._dbHandler, this._table, this._serverAddress, this._database)
      : super(const DataEditingState()) {
    _loadCellStructures().then((_) => loadTableData());
  }

  String get _prefsKey => 'cell_structures|$_serverAddress|$_database|$_table';

  Future<void> _loadCellStructures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final structures = decoded.map((k, v) =>
          MapEntry(k, CellStructure.fromJson(v as Map<String, dynamic>)));
      state = state.copyWith(cellStructures: structures);
    } catch (_) {}
  }

  Future<void> _persistCellStructures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
          state.cellStructures.map((k, v) => MapEntry(k, v.toJson())));
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }

  void setCellStructure(String columnName, CellStructure structure) {
    final next = Map<String, CellStructure>.from(state.cellStructures);
    next[columnName] = structure;
    state = state.copyWith(cellStructures: next);
    _persistCellStructures();
    // 흡수 컬럼 너비를 0으로 처리
    _applyAbsorbedColumnWidths(next);
  }

  void removeCellStructure(String columnName) {
    final next = Map<String, CellStructure>.from(state.cellStructures);
    next.remove(columnName);
    state = state.copyWith(cellStructures: next);
    _persistCellStructures();
    _applyAbsorbedColumnWidths(next);
  }

  void toggleDisplayMode() {
    state = state.copyWith(isDisplayMode: !state.isDisplayMode);
  }

  void importCellStructures(Map<String, CellStructure> structures) {
    final next = Map<String, CellStructure>.from(state.cellStructures)
      ..addAll(structures);
    state = state.copyWith(cellStructures: next);
    _persistCellStructures();
    _applyAbsorbedColumnWidths(next);
  }

  void _applyAbsorbedColumnWidths(Map<String, CellStructure> structures) {
    if (state.columnWidths.isEmpty) return;
    final absorbed = <String>{};
    for (final s in structures.values) {
      absorbed.addAll(s.absorbedColumns);
    }
    final next = List<double>.from(state.columnWidths);
    for (int i = 0; i < state.columns.length; i++) {
      final colName = state.columns[i]['name']!;
      // columnWidths[0] = row number, [i+1] = column i, last = actions
      if (absorbed.contains(colName)) {
        next[i + 1] = 0.0;
      } else {
        // 흡수 해제 시 minWidth 복원
        if (next[i + 1] == 0.0) {
          next[i + 1] = state.minColumnWidths[i + 1];
        }
      }
    }
    state = state.copyWith(columnWidths: next);
  }

  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);

  double _getTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }

  List<double> _calculateColumnWidths(List<Map<String, dynamic>> columns, List<Map<String, dynamic>> rows, List<double> minWidths) {
    final widths = <double>[];
    for (int i = 0; i <= columns.length; i++) {
      if (i < columns.length) {
        double maxWidth = minWidths[i];
        final colName = columns[i]['name']!;
        for (var row in rows) {
          final val = row[colName]?.toString() ?? 'NULL';
          maxWidth = math.max(maxWidth, _getTextWidth(val, const TextStyle()) + 34.0);
        }
        widths.add(maxWidth);
      } else widths.add(100.0);
    }
    return widths;
  }

  Future<void> loadTableData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final columns = await _dbHandler.getColumns(_table);
      final primaryKey = await _dbHandler.getPrimaryKey(_table);
      final List<Map<String, dynamic>> dataRows;
      if (state.filters.isNotEmpty || state.sorts.isNotEmpty || state.groupByColumns.isNotEmpty) {
        dataRows = await _dbHandler.getDataWithFilters(_table, filters: state.filters.map((f) => f.toMap()).toList(), sorts: state.sorts.map((s) => s.toMap()).toList(), groupByColumns: state.groupByColumns.isNotEmpty ? state.groupByColumns : null);
      } else dataRows = await _dbHandler.getData(_table);
      
      final mWidths = columns.map<double>((c) => _getTextWidth(c['name']!, const TextStyle(fontWeight: FontWeight.bold)) + 34.0).toList();
      final initialWidths = _calculateColumnWidths(columns, dataRows, mWidths);
      initialWidths.insert(0, 60.0);
      mWidths.insert(0, 60.0);
      
      state = state.copyWith(
        columns: columns.map((c) => {'name': c['name'] as String, 'type': c['type'] as String}).toList(),
        primaryKeyColumn: primaryKey, rows: dataRows, minColumnWidths: mWidths, columnWidths: initialWidths, isLoading: false, cellVersions: {},
      );
      // 로드 후 흡수된 컬럼 너비 적용
      _applyAbsorbedColumnWidths(state.cellStructures);
    } catch (e) { state = state.copyWith(isLoading: false, error: e.toString()); }
  }

  void selectColumn(int index) => state = state.copyWith(selectedColumnIndex: state.selectedColumnIndex == index ? null : index, selectedRowIndex: null, selectedCell: null, selectedCellRange: null);
  void selectRow(int index) => state = state.copyWith(selectedRowIndex: state.selectedRowIndex == index ? null : index, selectedColumnIndex: null, selectedCell: null, selectedCellRange: null);
  void selectCell(int r, int c) => state = state.copyWith(selectedCell: {'rowIndex': r, 'colIndex': c}, selectedCellRange: {'startRow': r, 'startCol': c, 'endRow': r, 'endCol': c}, selectedRowIndex: null, selectedColumnIndex: null);
  
  void startCellSelection(int r, int c) => selectCell(r, c);
  
  void updateCellSelection(int r, int c) {
    if (state.selectedCellRange == null) { selectCell(r, c); return; }
    state = state.copyWith(selectedCellRange: {'startRow': state.selectedCellRange!['startRow']!, 'startCol': state.selectedCellRange!['startCol']!, 'endRow': r, 'endCol': c});
  }
  void clearSelection() => state = state.copyWith(selectedCell: null, selectedCellRange: null, selectedRowIndex: null, selectedColumnIndex: null);

  bool isValidSyntax() => getValidationError() == null;
  String? getValidationError() {
    final fs = state.filters; if (fs.isEmpty) return null;
    int bal = 0; for (final f in fs) { bal += (f.openGroupCount ?? 0); bal -= (f.closeGroupCount ?? 0); if (bal < 0) return '괄호 순서 오류'; }
    if (bal != 0) return '괄호 불균형';
    for (int i=0; i<fs.length; i++) {
      final f = fs[i]; if (f.columnName.isEmpty) return '필터 ${i+1}번: 컬럼명 필요';
      final op = f.operator.toUpperCase();
      if (op != 'IS NULL' && op != 'IS NOT NULL' && (f.value == null || f.value.toString().isEmpty)) return '필터 ${i+1}번: 값 필요';
    }
    return null;
  }

  void refreshData({DataEditingState? overwriteState}) {
    if(overwriteState != null) state = overwriteState;
    else Future.microtask(() => loadTableData());
  }

  void updateFilters(List<FilterCondition> filters) => state = state.copyWith(filters: filters);

  void addFilter(FilterCondition filter) {
    final newFilters = List<FilterCondition>.from(state.filters)..add(filter);
    state = state.copyWith(filters: newFilters);
  }

  void updateFilter(int index, FilterCondition filter) {
    if (index >= state.filters.length) return;
    final newFilters = List<FilterCondition>.from(state.filters);
    newFilters[index] = filter;
    state = state.copyWith(filters: newFilters);
  }

  void clearFilters() => state = state.copyWith(filters: [], sorts: [], groupByColumns: []);

  List<Map<String, dynamic>> _buildFilterBlockList() {
    final blocks = <Map<String, dynamic>>[];
    for (int i = 0; i < state.filters.length; i++) {
      final f = state.filters[i];
      for (int j = 0; j < (f.openGroupCount ?? 0); j++) blocks.add({'type': 'openparen'});
      blocks.add({'type': 'filter', 'index': i});
      for (int j = 0; j < (f.closeGroupCount ?? 0); j++) blocks.add({'type': 'closeparen'});
      if (i < state.filters.length - 1) blocks.add({'type': 'operator', 'value': f.logicalOperator ?? 'AND'});
    }
    return blocks;
  }

  void toggleFilterOperatorAtBlock(int blockIndex) {
    final blocks = _buildFilterBlockList();
    if (blockIndex >= blocks.length || blocks[blockIndex]['type'] != 'operator') return;
    int? fIdx; for (int i = blockIndex - 1; i >= 0; i--) { if (blocks[i]['type'] == 'filter') { fIdx = blocks[i]['index']; break; } }
    if (fIdx == null) return;
    final next = [...state.filters];
    next[fIdx] = next[fIdx].copyWith(logicalOperator: next[fIdx].logicalOperator == 'AND' ? 'OR' : 'AND');
    state = state.copyWith(filters: next);
  }

  void reorderFilterBlock(int oldIdx, int newIdx, Map<int, TextEditingController>? controllers) {
    if (oldIdx == newIdx) return;
    final blocks = _buildFilterBlockList();
    if (oldIdx >= blocks.length || newIdx > blocks.length) return;
    final moving = blocks.removeAt(oldIdx);
    blocks.insert(oldIdx < newIdx ? newIdx - 1 : newIdx, moving);

    // 재배열 후 블록에서 연산자를 순서대로 수집 → 순차 할당으로 OR/AND 보존
    final operatorsInOrder = blocks
        .where((b) => b['type'] == 'operator')
        .map((b) => b['value'] as String)
        .toList();

    final List<FilterCondition> nextFilters = [];
    final Map<int, TextEditingController> nextControllers = {};
    int count = 0;
    int opIdx = 0;
    for (int i = 0; i < blocks.length; i++) {
      if (blocks[i]['type'] == 'filter') {
        // 바로 앞의 연속된 openparen만 카운트 (다른 블록 만나면 즉시 중단)
        int open = 0;
        for (int j = i - 1; j >= 0; j--) {
          if (blocks[j]['type'] == 'openparen') open++;
          else break;
        }
        // 바로 뒤의 연속된 closeparen만 카운트 (다른 블록 만나면 즉시 중단)
        int close = 0;
        for (int j = i + 1; j < blocks.length; j++) {
          if (blocks[j]['type'] == 'closeparen') close++;
          else break;
        }
        // 다음 필터 존재 여부 확인 후 연산자 순차 할당 (블록 내 위치 무관하게 순서 보존)
        final hasNextFilter = blocks.skip(i + 1).any((b) => b['type'] == 'filter');
        String? op;
        if (hasNextFilter) {
          op = opIdx < operatorsInOrder.length ? operatorsInOrder[opIdx++] : 'AND';
        }
        final oldFIdx = blocks[i]['index'] as int;
        if (controllers != null && controllers.containsKey(oldFIdx)) nextControllers[count] = controllers[oldFIdx]!;
        nextFilters.add(state.filters[oldFIdx].copyWith(openGroupCount: open, closeGroupCount: close, logicalOperator: op));
        count++;
      }
    }
    if (controllers != null) { controllers.clear(); controllers.addAll(nextControllers); }
    state = state.copyWith(filters: _cleanupFiltersAfterReorder(nextFilters));
  }

  void finalizeFilters() {
    if (state.filters.isEmpty) return;
    final blocks = _buildFilterBlockList();
    final List<FilterCondition> next = [];
    for (int i = 0; i < blocks.length; i++) {
      if (blocks[i]['type'] == 'filter') {
        int open = 0; for (int j = i - 1; j >= 0; j--) { if (blocks[j]['type'] == 'openparen') open++; else if (blocks[j]['type'] == 'filter') break; }
        int close = 0; String? op; for (int j = i + 1; j < blocks.length; j++) { if (blocks[j]['type'] == 'closeparen') close++; else if (blocks[j]['type'] == 'operator') op = blocks[j]['value']; else if (blocks[j]['type'] == 'filter') break; }
        next.add(state.filters[blocks[i]['index'] as int].copyWith(openGroupCount: open, closeGroupCount: close, logicalOperator: op));
      }
    }
    state = state.copyWith(filters: _cleanupFiltersAfterReorder(next));
  }

  void removeMultipleBlocks(List<int> indices) {
    final blocks = _buildFilterBlockList();
    final toRemF = <int>{}; final toRemO = <int, int>{}; final toRemC = <int, int>{};
    for (final idx in (List<int>.from(indices)..sort((a, b) => b.compareTo(a)))) {
      if (idx < 0 || idx >= blocks.length) continue;
      final b = blocks[idx];
      if (b['type'] == 'filter') toRemF.add(b['index'] as int);
      else if (b['type'] == 'openparen') { for (int i = idx; i < blocks.length; i++) { if (blocks[i]['type'] == 'filter') { toRemO[blocks[i]['index']] = (toRemO[blocks[i]['index']] ?? 0) + 1; break; } } }
      else if (b['type'] == 'closeparen') { for (int i = idx; i >= 0; i--) { if (blocks[i]['type'] == 'filter') { toRemC[blocks[i]['index']] = (toRemC[blocks[i]['index']] ?? 0) + 1; break; } } }
    }
    final next = <FilterCondition>[];
    for (int i = 0; i < state.filters.length; i++) {
      if (toRemF.contains(i)) continue;
      var f = state.filters[i];
      if (toRemO.containsKey(i)) f = f.copyWith(openGroupCount: math.max(0, (f.openGroupCount ?? 0) - toRemO[i]!));
      if (toRemC.containsKey(i)) f = f.copyWith(closeGroupCount: math.max(0, (f.closeGroupCount ?? 0) - toRemC[i]!));
      next.add(f);
    }
    state = state.copyWith(filters: _removeEmptyParenthesisFilters(_cleanupFiltersAfterReorder(next)));
  }

  void removeFilter(int index) {
    final blocks = _buildFilterBlockList();
    int? bIdx; for(int i=0; i<blocks.length; i++) { if(blocks[i]['type'] == 'filter' && blocks[i]['index'] == index) { bIdx = i; break; } }
    if(bIdx != null) removeMultipleBlocks([bIdx]);
  }

  List<FilterCondition> _cleanupFiltersAfterReorder(List<FilterCondition> filters) {
    final next = <FilterCondition>[];
    for (int i = 0; i < filters.length; i++) {
      next.add(filters[i].copyWith(openGroupCount: filters[i].openGroupCount ?? 0, closeGroupCount: filters[i].closeGroupCount ?? 0, logicalOperator: i < filters.length - 1 ? (filters[i].logicalOperator ?? 'AND') : null));
    }
    return _balanceParentheses(next);
  }

  List<FilterCondition> _balanceParentheses(List<FilterCondition> filters) {
    int bal = 0; final res = <FilterCondition>[];
    for (int i = 0; i < filters.length; i++) {
      int open = filters[i].openGroupCount ?? 0, close = filters[i].closeGroupCount ?? 0;
      if (bal + open - close < 0) close = bal + open; bal += open - close;
      res.add(filters[i].copyWith(openGroupCount: open, closeGroupCount: close));
    }
    if (bal > 0) { for (int i = res.length - 1; i >= 0 && bal > 0; i--) { int o = res[i].openGroupCount ?? 0; if (o > 0) { int r = math.min(o, bal); res[i] = res[i].copyWith(openGroupCount: o - r); bal -= r; } } }
    return res;
  }

  List<FilterCondition> _removeEmptyParenthesisFilters(List<FilterCondition> filters) {
    final next = <FilterCondition>[];
    for (int i = 0; i < filters.length; i++) {
      int o = filters[i].openGroupCount ?? 0, c = filters[i].closeGroupCount ?? 0;
      if (i == filters.length - 1 && o > 0 && c == 0) o = 0;
      if (i == 0 && c > 0 && o == 0) c = 0;
      next.add(filters[i].copyWith(openGroupCount: o, closeGroupCount: c));
    }
    return next;
  }

  Future<void> updateCellValue(int r, int c, String col, dynamic v) async {
    if (r >= state.rows.length || c >= state.columns.length) return;
    final nextRows = [...state.rows]; nextRows[r] = {...nextRows[r], col: v};
    final nextVers = {...state.cellVersions, '${r}_$c': (state.cellVersions['${r}_$c'] ?? 0) + 1};
    state = state.copyWith(rows: nextRows, cellVersions: nextVers, isLoading: false);
  }

  Future<void> updateMultipleCellValues(List<Map<String, dynamic>> updates) async {
    if (updates.isEmpty) return;
    final nextRows = [...state.rows]; final nextVers = {...state.cellVersions};
    for (final u in updates) {
      int r = u['rowIndex'], c = u['colIndex']; String col = u['columnName']; dynamic v = u['newValue'];
      if (r < nextRows.length && c < state.columns.length) {
        nextRows[r] = {...nextRows[r], col: v};
        nextVers['${r}_$c'] = (nextVers['${r}_$c'] ?? 0) + 1;
      }
    }
    state = state.copyWith(rows: nextRows, cellVersions: nextVers);
  }

  Future<void> updateRowData(int r) async { try { await loadTableData(); } catch(_) {} }
  Future<void> performOperation(Future<void> Function() op, {int? updatedRowIndex}) async { try { await op(); } finally { await loadTableData(); } }

  void updateFilterColumn(int i, String c) { final next = [...state.filters]; next[i] = next[i].copyWith(columnName: c); state = state.copyWith(filters: next); }
  void updateFilterOperator(int i, String o) { final next = [...state.filters]; next[i] = next[i].copyWith(operator: o); state = state.copyWith(filters: next); }
  void updateFilterValue(int i, dynamic v) { final next = [...state.filters]; next[i] = next[i].copyWith(value: v); state = state.copyWith(filters: next); }
  void addSort(SortCondition s) => state = state.copyWith(sorts: [...state.sorts, s]);
  void updateSort(int i, SortCondition s) { final next = [...state.sorts]; next[i] = s; state = state.copyWith(sorts: next); }
  void removeSort(int i) => state = state.copyWith(sorts: [...state.sorts]..removeAt(i));
  void clearSorts() => state = state.copyWith(sorts: []);
  void reorderSorts(int o, int n) { if (o == n) return; final next = [...state.sorts]; final item = next.removeAt(o); next.insert(n, item); state = state.copyWith(sorts: next); }
  void addGroupByColumn(String c) { if (!state.groupByColumns.contains(c)) state = state.copyWith(groupByColumns: [...state.groupByColumns, c]); }
  void removeGroupByColumn(String c) => state = state.copyWith(groupByColumns: [...state.groupByColumns]..remove(c));
  void clearGroupBy() => state = state.copyWith(groupByColumns: []);
  void reorderGroupBy(int o, int n) { if (o == n) return; final next = [...state.groupByColumns]; final item = next.removeAt(o); next.insert(n, item); state = state.copyWith(groupByColumns: next); }
  void updateColumnWidth(int i, double w) { final next = [...state.columnWidths]; next[i] = math.max(w, state.minColumnWidths[i]); state = state.copyWith(columnWidths: next); }
  List<Map<String, dynamic>> _createBlocksFromFilters() => _buildFilterBlockList();
}

final databaseHandlerProvider = Provider.family<DatabaseHandler, DatabaseHandlerParams>((ref, p) {
  if (p.server.type == 'PostgreSQL') return PostgresHandler(p.server, databaseName: p.database);
  throw Exception('Unsupported database type');
});

class DatabaseHandlerParams { final ServerModel server; final String database; DatabaseHandlerParams({required this.server, required this.database}); }

final dataEditingProvider = StateNotifierProvider.family<DataEditingNotifier, DataEditingState, DataEditingParams>((ref, p) {
  final db = ref.watch(databaseHandlerProvider(DatabaseHandlerParams(server: p.server, database: p.database)));
  return DataEditingNotifier(db, p.table, p.server.address, p.database);
});

class DataEditingParams {
  final ServerModel server; final String database; final String table;
  DataEditingParams({required this.server, required this.database, required this.table});
  @override bool operator ==(Object other) => identical(this, other) || other is DataEditingParams && runtimeType == other.runtimeType && server == other.server && database == other.database && table == other.table;
  @override int get hashCode => server.hashCode ^ database.hashCode ^ table.hashCode;
}
