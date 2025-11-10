// lib/stateManagement/setState/data_editing_riverpod.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../db/database_handler.dart';
import '../../db/postgres_handler.dart';

/// 필터 조건 클래스
class FilterCondition {
  final String columnName;
  final String operator; // =, !=, <, >, <=, >=, LIKE, IN, NOT IN, IS NULL, IS NOT NULL
  final dynamic value; // 값 (LIKE의 경우 String, IN의 경우 List)
  final String? logicalOperator; // AND, OR (다음 조건과의 연결)
  final int? groupIndex; // 괄호 그룹 인덱스 (같은 그룹끼리 묶음)
  
  const FilterCondition({
    required this.columnName,
    required this.operator,
    this.value,
    this.logicalOperator,
    this.groupIndex,
  });
  
  FilterCondition copyWith({
    String? columnName,
    String? operator,
    dynamic value,
    String? logicalOperator,
    int? groupIndex,
  }) {
    return FilterCondition(
      columnName: columnName ?? this.columnName,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      logicalOperator: logicalOperator ?? this.logicalOperator,
      groupIndex: groupIndex ?? this.groupIndex,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'column': columnName,
      'operator': operator,
      'value': value,
      'logicalOperator': logicalOperator,
      'groupIndex': groupIndex,
    };
  }
}

/// 정렬 조건 클래스
class SortCondition {
  final String columnName;
  final bool ascending; // true: ASC, false: DESC
  
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
  final Map<String, int>? selectedCell; // { 'rowIndex': int, 'colIndex': int }
  
  // 다중 셀 선택 범위: { 'startRow': int, 'startCol': int, 'endRow': int, 'endCol': int }
  final Map<String, int>? selectedCellRange;
  
  // 버전 관리를 위한 맵 추가: 각 셀의 변경을 추적
  final Map<String, int> cellVersions; // key: "row_col", value: version
  
  // 필터, 정렬, 그룹 상태
  final List<FilterCondition> filters; // 필터 조건 리스트
  final List<SortCondition> sorts; // 정렬 조건 리스트
  final List<String> groupByColumns; // 그룹화할 컬럼들

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
  }) {
    return DataEditingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      primaryKeyColumn: primaryKeyColumn ?? this.primaryKeyColumn,
      columnWidths: columnWidths ?? this.columnWidths,
      minColumnWidths: minColumnWidths ?? this.minColumnWidths,
      selectedColumnIndex: selectedColumnIndex,
      selectedRowIndex: selectedRowIndex,
      selectedCell: selectedCell,
      selectedCellRange: selectedCellRange,
      cellVersions: cellVersions ?? this.cellVersions,
      filters: filters ?? this.filters,
      sorts: sorts ?? this.sorts,
      groupByColumns: groupByColumns ?? this.groupByColumns,
    );
  }
  
  /// 선택된 범위 내의 모든 셀 키를 반환 (row_col 형식)
  Set<String> getSelectedCellKeys() {
    if (selectedCellRange == null) {
      if (selectedCell != null) {
        return {'${selectedCell!['rowIndex']}_${selectedCell!['colIndex']}'};
      }
      return {};
    }
    
    final startRow = selectedCellRange!['startRow']!;
    final startCol = selectedCellRange!['startCol']!;
    final endRow = selectedCellRange!['endRow']!;
    final endCol = selectedCellRange!['endCol']!;
    
    final minRow = min(startRow, endRow);
    final maxRow = max(startRow, endRow);
    final minCol = min(startCol, endCol);
    final maxCol = max(startCol, endCol);
    
    final keys = <String>{};
    for (int row = minRow; row <= maxRow; row++) {
      for (int col = minCol; col <= maxCol; col++) {
        keys.add('${row}_${col}');
      }
    }
    return keys;
  }
  
  /// 특정 셀이 선택 범위 내에 있는지 확인
  bool isCellInRange(int rowIndex, int colIndex) {
    if (selectedCellRange == null) {
      if (selectedCell != null) {
        return selectedCell!['rowIndex'] == rowIndex && selectedCell!['colIndex'] == colIndex;
      }
      return false;
    }
    
    final startRow = selectedCellRange!['startRow']!;
    final startCol = selectedCellRange!['startCol']!;
    final endRow = selectedCellRange!['endRow']!;
    final endCol = selectedCellRange!['endCol']!;
    
    final minRow = min(startRow, endRow);
    final maxRow = max(startRow, endRow);
    final minCol = min(startCol, endCol);
    final maxCol = max(startCol, endCol);
    
    return rowIndex >= minRow && rowIndex <= maxRow && colIndex >= minCol && colIndex <= maxCol;
  }
  
  /// 선택된 셀 중 가장 좌상단 셀의 위치를 반환 (붙여넣기 시작 위치)
  Map<String, int>? getTopLeftSelectedCell() {
    if (selectedCellRange == null) {
      // 범위 선택이 없으면 selectedCell 반환
      return selectedCell;
    }
    
    // 범위 선택이 있으면 가장 좌상단 셀 계산
    final startRow = selectedCellRange!['startRow']!;
    final startCol = selectedCellRange!['startCol']!;
    final endRow = selectedCellRange!['endRow']!;
    final endCol = selectedCellRange!['endCol']!;
    
    final minRow = min(startRow, endRow);
    final minCol = min(startCol, endCol);
    
    return {'rowIndex': minRow, 'colIndex': minCol};
  }
}

/// DataEditing StateNotifier
class DataEditingNotifier extends StateNotifier<DataEditingState> {
  final DatabaseHandler _dbHandler;
  final String _table;

  DataEditingNotifier(this._dbHandler, this._table) : super(const DataEditingState()) {
    loadTableData();
  }

  double _getTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }

  List<double> _calculateColumnWidths(
      List<Map<String, dynamic>> columns, List<Map<String, dynamic>> rows, List<double> minWidths) {
    final List<double> widths = [];
    final columnsAndActions = [...columns, {'name': 'Actions'}];

    for (int i = 0; i < columnsAndActions.length; i++) {
      if (i < columns.length) {
        // Regular column
        double maxWidth = minWidths[i]; // Start with min width (header width + padding)
        final colName = columns[i]['name']!;
        for (var row in rows) {
          final value = row[colName]?.toString() ?? 'NULL';
          final cellWidth = _getTextWidth(value, const TextStyle()) + 34.0; // Increased buffer
          maxWidth = max(maxWidth, cellWidth);
        }
        widths.add(maxWidth);
      } else {
        // Actions column
        widths.add(100.0);
      }
    }
    return widths;
  }

  Future<void> loadTableData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final columns = await _dbHandler.getColumns(_table);
      final primaryKey = await _dbHandler.getPrimaryKey(_table);
      
      // 필터, 정렬, 그룹이 있으면 getDataWithFilters 사용, 없으면 getData 사용
      final List<Map<String, dynamic>> dataRows;
      if (state.filters.isNotEmpty || state.sorts.isNotEmpty || state.groupByColumns.isNotEmpty) {
        // 필터 조건을 Map 형식으로 변환
        final filterMaps = state.filters.map((f) => f.toMap()).toList();
        // 정렬 조건을 Map 형식으로 변환
        final sortMaps = state.sorts.map((s) => s.toMap()).toList();
        
        dataRows = await _dbHandler.getDataWithFilters(
          _table,
          filters: filterMaps,
          sorts: sortMaps,
          groupByColumns: state.groupByColumns.isNotEmpty ? state.groupByColumns : null,
        );
      } else {
        dataRows = await _dbHandler.getData(_table);
      }

      final minWidths = columns.map<double>((col) {
        return _getTextWidth(col['name']!, const TextStyle(fontWeight: FontWeight.bold)) + 34.0;
      }).toList();

      final initialWidths = _calculateColumnWidths(columns, dataRows, minWidths);

      // Add width for the row number column
      initialWidths.insert(0, 60.0);
      minWidths.insert(0, 60.0);

      state = state.copyWith(
        columns: columns.map((c) => {'name': c['name'] as String, 'type': c['type'] as String}).toList(),
        primaryKeyColumn: primaryKey,
        rows: dataRows,
        minColumnWidths: minWidths,
        columnWidths: initialWidths,
        isLoading: false,
        error: null,
        cellVersions: {},
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load table data: $e',
      );
    }
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void selectColumn(int index) {
    state = state.copyWith(
      selectedColumnIndex: state.selectedColumnIndex == index ? null : index,
      selectedRowIndex: null,
      selectedCell: null,
      selectedCellRange: null,
    );
  }

  void selectRow(int index) {
    state = state.copyWith(
      selectedRowIndex: state.selectedRowIndex == index ? null : index,
      selectedColumnIndex: null,
      selectedCell: null,
      selectedCellRange: null,
    );
  }

  void selectCell(int rowIndex, int colIndex) {
    // 셀 클릭 시 선택 해제하지 않고 항상 선택 상태 유지
    state = state.copyWith(
      selectedCell: {'rowIndex': rowIndex, 'colIndex': colIndex},
      selectedCellRange: {
        'startRow': rowIndex,
        'startCol': colIndex,
        'endRow': rowIndex,
        'endCol': colIndex,
      },
      selectedRowIndex: null,
      selectedColumnIndex: null,
    );
  }
  
  /// 드래그 시작: 시작 셀 설정
  void startCellSelection(int rowIndex, int colIndex) {
    state = state.copyWith(
      selectedCell: {'rowIndex': rowIndex, 'colIndex': colIndex},
      selectedCellRange: {
        'startRow': rowIndex,
        'startCol': colIndex,
        'endRow': rowIndex,
        'endCol': colIndex,
      },
      selectedRowIndex: null,
      selectedColumnIndex: null,
    );
  }
  
  /// 드래그 중: 끝 셀 업데이트
  void updateCellSelection(int rowIndex, int colIndex) {
    if (state.selectedCellRange == null) {
      startCellSelection(rowIndex, colIndex);
      return;
    }
    
    state = state.copyWith(
      selectedCellRange: {
        'startRow': state.selectedCellRange!['startRow']!,
        'startCol': state.selectedCellRange!['startCol']!,
        'endRow': rowIndex,
        'endCol': colIndex,
      },
    );
  }
  
  /// 선택 해제
  void clearSelection() {
    state = state.copyWith(
      selectedCell: null,
      selectedCellRange: null,
    );
  }
  
  /// 필터 추가
  void addFilter(FilterCondition filter) {
    final newFilters = List<FilterCondition>.from(state.filters)..add(filter);
    state = state.copyWith(filters: newFilters);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 필터 제거
  void removeFilter(int index) {
    final newFilters = List<FilterCondition>.from(state.filters)..removeAt(index);
    state = state.copyWith(filters: newFilters);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 필터 수정
  void updateFilter(int index, FilterCondition filter) {
    final newFilters = List<FilterCondition>.from(state.filters);
    newFilters[index] = filter;
    state = state.copyWith(filters: newFilters);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 필터 모두 제거
  void clearFilters() {
    state = state.copyWith(filters: []);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 필터 순서 재정렬
  void reorderFilters(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newFilters = List<FilterCondition>.from(state.filters);
    final item = newFilters.removeAt(oldIndex);
    newFilters.insert(newIndex, item);
    state = state.copyWith(filters: newFilters);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 정렬 추가
  void addSort(SortCondition sort) {
    final newSorts = List<SortCondition>.from(state.sorts)..add(sort);
    state = state.copyWith(sorts: newSorts);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 정렬 수정
  void updateSort(int index, SortCondition sort) {
    final newSorts = List<SortCondition>.from(state.sorts);
    newSorts[index] = sort;
    state = state.copyWith(sorts: newSorts);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 정렬 제거
  void removeSort(int index) {
    final newSorts = List<SortCondition>.from(state.sorts)..removeAt(index);
    state = state.copyWith(sorts: newSorts);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 정렬 모두 제거
  void clearSorts() {
    state = state.copyWith(sorts: []);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 정렬 순서 재정렬
  void reorderSorts(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    
    final newSorts = List<SortCondition>.from(state.sorts);
    final item = newSorts.removeAt(oldIndex);
    
    // oldIndex가 newIndex보다 작으면 (아래로 이동) removeAt으로 인해 인덱스가 하나씩 앞당겨짐
    // oldIndex가 newIndex보다 크면 (위로 이동) 인덱스 조정 불필요
    final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    newSorts.insert(adjustedNewIndex, item);
    
    state = state.copyWith(sorts: newSorts);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 그룹화 컬럼 추가
  void addGroupByColumn(String columnName) {
    if (!state.groupByColumns.contains(columnName)) {
      final newGroupByColumns = List<String>.from(state.groupByColumns)..add(columnName);
      state = state.copyWith(groupByColumns: newGroupByColumns);
      // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
      Future.microtask(() => loadTableData());
    }
  }
  
  /// 그룹화 컬럼 제거
  void removeGroupByColumn(String columnName) {
    final newGroupByColumns = List<String>.from(state.groupByColumns)..remove(columnName);
    state = state.copyWith(groupByColumns: newGroupByColumns);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 그룹화 모두 제거
  void clearGroupBy() {
    state = state.copyWith(groupByColumns: []);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }
  
  /// 그룹화 컬럼 순서 재정렬
  void reorderGroupBy(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    
    final newGroupByColumns = List<String>.from(state.groupByColumns);
    final item = newGroupByColumns.removeAt(oldIndex);
    
    // oldIndex가 newIndex보다 작으면 (아래로 이동) removeAt으로 인해 인덱스가 하나씩 앞당겨짐
    // oldIndex가 newIndex보다 크면 (위로 이동) 인덱스 조정 불필요
    final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    newGroupByColumns.insert(adjustedNewIndex, item);
    
    state = state.copyWith(groupByColumns: newGroupByColumns);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    Future.microtask(() => loadTableData());
  }

  void updateColumnWidth(int index, double newWidth) {
    final newWidths = List<double>.from(state.columnWidths);
    newWidths[index] = max(newWidth, state.minColumnWidths[index]);
    state = state.copyWith(columnWidths: newWidths);
  }

  /// 특정 셀만 업데이트 (최소 단위 리빌드)
  Future<void> updateCellValue(int rowIndex, int colIndex, String columnName, dynamic newValue) async {
    if (rowIndex >= state.rows.length || colIndex >= state.columns.length) {
      return;
    }

    // rows 리스트를 새로 복사하되, 해당 행의 Map만 새로 생성
    final newRows = List<Map<String, dynamic>>.from(state.rows);
    final updatedRow = Map<String, dynamic>.from(newRows[rowIndex]);
    updatedRow[columnName] = newValue;
    newRows[rowIndex] = updatedRow;

    // 셀 버전 업데이트 (해당 셀만 리빌드 트리거)
    final cellKey = '${rowIndex}_${colIndex}';
    final newCellVersions = Map<String, int>.from(state.cellVersions);
    newCellVersions[cellKey] = (newCellVersions[cellKey] ?? 0) + 1;

    state = state.copyWith(
      rows: newRows,
      cellVersions: newCellVersions,
      isLoading: false,
    );
  }
  
  /// 여러 셀을 한 번에 업데이트 (배치 업데이트로 최적화)
  /// 각 셀의 변경사항을 모아서 한 번만 state를 업데이트하여 리빌드를 최소화
  /// 같은 행의 여러 셀을 효율적으로 처리하여 불필요한 행 복사를 방지
  /// 실제로 변경된 셀이 있는 경우에만 state를 업데이트
  Future<void> updateMultipleCellValues(List<Map<String, dynamic>> cellUpdates) async {
    if (cellUpdates.isEmpty) return;
    
    final newCellVersions = Map<String, int>.from(state.cellVersions);
    final changedRows = <int, Map<String, dynamic>>{}; // 변경된 행들: rowIndex -> updatedRow
    
    // 행별로 그룹화하여 같은 행의 여러 셀을 한 번에 처리
    final updatesByRow = <int, List<Map<String, dynamic>>>{};
    for (final update in cellUpdates) {
      final rowIndex = update['rowIndex'] as int;
      if (rowIndex >= state.rows.length) continue;
      
      updatesByRow.putIfAbsent(rowIndex, () => []).add(update);
    }
    
    // 각 행에 대해 업데이트 적용 및 변경 여부 확인
    for (final entry in updatesByRow.entries) {
      final rowIndex = entry.key;
      final updates = entry.value;
      final originalRow = state.rows[rowIndex];
      final updatedRow = Map<String, dynamic>.from(originalRow);
      bool rowChanged = false;
      
      for (final update in updates) {
        final colIndex = update['colIndex'] as int;
        final columnName = update['columnName'] as String;
        final newValue = update['newValue'];
        
        if (colIndex >= state.columns.length) continue;
        
        // 기존 값과 비교하여 실제로 변경된 경우에만 업데이트
        final oldValue = originalRow[columnName];
        if (oldValue != newValue) {
          // 셀 값 업데이트
          updatedRow[columnName] = newValue;
          rowChanged = true;
          
          // 셀 버전 업데이트 (해당 셀만 리빌드 트리거)
          final cellKey = '${rowIndex}_${colIndex}';
          newCellVersions[cellKey] = (newCellVersions[cellKey] ?? 0) + 1;
        }
      }
      
      // 행이 실제로 변경된 경우에만 변경된 행 저장
      if (rowChanged) {
        changedRows[rowIndex] = updatedRow;
      }
    }
    
    // 변경된 셀이 하나도 없으면 state 업데이트하지 않음 (중요: setState 최소화)
    if (changedRows.isEmpty) {
      return;
    }
    
    // 변경된 행만 새로 생성하고, 변경되지 않은 행은 기존 참조 유지
    // 이렇게 하면 변경되지 않은 행의 셀들은 리빌드되지 않음
    final newRows = <Map<String, dynamic>>[];
    for (int i = 0; i < state.rows.length; i++) {
      if (changedRows.containsKey(i)) {
        // 변경된 행은 새로 생성된 Map 사용
        newRows.add(changedRows[i]!);
      } else {
        // 변경되지 않은 행은 기존 참조 유지 (리빌드 방지)
        newRows.add(state.rows[i]);
      }
    }
    
    // 변경사항이 있는 경우에만 state 업데이트 (한 번만 setState 호출)
    // Riverpod의 select를 사용하면 변경된 셀만 리빌드됨
    state = state.copyWith(
      rows: newRows,
      cellVersions: newCellVersions,
    );
  }

  /// 특정 행만 업데이트 (부분 리빌드를 위한 최적화)
  Future<void> updateRowData(int rowIndex) async {
    try {
      // 해당 행의 데이터만 가져오기 (Primary Key를 사용하여 특정 행 조회)
      if (state.primaryKeyColumn == null || rowIndex >= state.rows.length) {
        // Primary Key가 없거나 행 인덱스가 범위를 벗어나면 전체 데이터 다시 로드
        await loadTableData();
        return;
      }

      final pkValue = state.rows[rowIndex][state.primaryKeyColumn];
      final dataRows = await _dbHandler.getData(_table);
      
      // 업데이트된 행 찾기
      int? updatedRowIndex;
      for (int i = 0; i < dataRows.length; i++) {
        if (dataRows[i][state.primaryKeyColumn] == pkValue) {
          updatedRowIndex = i;
          break;
        }
      }

      if (updatedRowIndex != null && updatedRowIndex < state.rows.length) {
        // 해당 행만 업데이트
        final newRows = List<Map<String, dynamic>>.from(state.rows);
        newRows[updatedRowIndex] = dataRows[updatedRowIndex];
        
        // 해당 행의 모든 셀 버전 업데이트
        final newCellVersions = Map<String, int>.from(state.cellVersions);
        for (int colIndex = 0; colIndex < state.columns.length; colIndex++) {
          final cellKey = '${updatedRowIndex}_$colIndex';
          newCellVersions[cellKey] = (newCellVersions[cellKey] ?? 0) + 1;
        }
        
        state = state.copyWith(
          rows: newRows,
          cellVersions: newCellVersions,
          isLoading: false,
        );
      } else if (updatedRowIndex != null) {
        // 새 행이 추가된 경우 전체 데이터 다시 로드
        await loadTableData();
      } else {
        // 행이 삭제된 경우 전체 데이터 다시 로드
        await loadTableData();
      }
    } catch (e) {
      // 에러 발생 시 전체 데이터 다시 로드
      await loadTableData();
    }
  }
  

  Future<void> performOperation(
    Future<void> Function() operation, {
    int? updatedRowIndex,
  }) async {
    // isLoading은 설정하지 않음 (불필요한 전체 리빌드 방지)
    
    try {
      await operation();
    } catch (e) {
      rethrow;
    } finally {
      if (updatedRowIndex != null) {
        // 특정 행만 업데이트 (부분 리빌드)
        await updateRowData(updatedRowIndex);
      } else {
        // 전체 데이터 다시 로드
        await loadTableData();
      }
    }
  }
}

/// DatabaseHandler Provider Factory
final databaseHandlerProvider = Provider.family<DatabaseHandler, DatabaseHandlerParams>(
  (ref, params) {
    switch (params.server['type']) {
      case 'PostgreSQL':
        return PostgresHandler(params.server, database: params.database);
      default:
        throw Exception('Unsupported database type: ${params.server['type']}');
    }
  },
);

class DatabaseHandlerParams {
  final Map<String, dynamic> server;
  final String database;

  DatabaseHandlerParams({required this.server, required this.database});
}

/// DataEditing StateNotifier Provider
final dataEditingProvider = StateNotifierProvider.family<DataEditingNotifier, DataEditingState, DataEditingParams>(
  (ref, params) {
    final dbHandler = ref.watch(databaseHandlerProvider(DatabaseHandlerParams(
      server: params.server,
      database: params.database,
    )));
    return DataEditingNotifier(dbHandler, params.table);
  },
);

class DataEditingParams {
  final Map<String, dynamic> server;
  final String database;
  final String table;

  DataEditingParams({
    required this.server,
    required this.database,
    required this.table,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataEditingParams &&
          runtimeType == other.runtimeType &&
          _mapEquals(server, other.server) &&
          database == other.database &&
          table == other.table;

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = database.hashCode ^ table.hashCode;
    for (var key in server.keys) {
      hash ^= key.hashCode ^ (server[key]?.hashCode ?? 0);
    }
    return hash;
  }
}