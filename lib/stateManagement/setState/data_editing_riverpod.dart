// lib/stateManagement/setState/data_editing_riverpod.dart
import 'dart:math';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../db/database_handler.dart';
import '../../db/postgres_handler.dart';
import '../../sqflite/models/server_model.dart';

/// 필터 조건 클래스
class FilterCondition {
  String columnName;
  String operator; // =, !=, <, >, <=, >=, LIKE, IN, NOT IN, IS NULL, IS NOT NULL
  dynamic value; // 값 (LIKE의 경우 String, IN의 경우 List)
  String? logicalOperator; // AND, OR (다음 조건과의 연결)
  int? openGroupCount; // 괄호 열기 수
  int? closeGroupCount; // 괄호 닫기 수
  bool isNegated; // NOT 연산자 적용 여부
  
  FilterCondition({
    required this.columnName,
    required this.operator,
    this.value,
    this.logicalOperator,
    this.openGroupCount,
    this.closeGroupCount,
    this.isNegated = false,
  });
  
  FilterCondition copyWith({
    String? columnName,
    String? operator,
    dynamic value,
    String? logicalOperator,
    int? openGroupCount,
    int? closeGroupCount,
    bool? isNegated,
  }) {
    return FilterCondition(
      columnName: columnName ?? this.columnName,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      logicalOperator: logicalOperator ?? this.logicalOperator,
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
  final List<String>? filterOperators; // AND/OR 연산자 저장
  final List<bool>? filterParenthesis; // 각 필터의 괄호 여부
  final List<Map<String, dynamic>>? filterBlocks; // 필터 블럭 순서 관리
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
    this.filterBlocks = const [],
    this.filterOperators,
    this.filterParenthesis,
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
    List<Map<String, dynamic>>? filterBlocks,
    List<String>? filterOperators,
    List<bool>? filterParenthesis,
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
      filterBlocks: filterBlocks ?? this.filterBlocks,
      filterOperators: filterOperators ?? this.filterOperators,
      filterParenthesis: filterParenthesis ?? this.filterParenthesis,
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
        keys.add('${row}_$col');
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
    } finally {
      debugPrint("[loadTableData] filter state: ${state.filters.map((f) => f.toMap()).toList()}");
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

  /// state 문법 오류 확인
  bool isValidSyntax() {
    final filters = state.filters;

    // 빈 필터와 필터 하나는 유효함
    if (filters.isEmpty || filters.length == 1) {
      return true;
    }

    // 1. 첫 번째 필터는 logicalOperator가 null이 아니어야 함
    if (filters.first.logicalOperator == null) {
      return false;
    }

    // 2. 마지막 필터를 제외한 모든 필터는 logicalOperator가 있어야 함
    for (int i = 0; i < filters.length - 1; i++) {
      final logicalOp = filters[i].logicalOperator;
      if (logicalOp == null || (logicalOp != 'AND' && logicalOp != 'OR')) {
        return false;
      }
    }

    // 3. 마지막 필터의 logicalOperator는 null이어야 함
    if (filters.last.logicalOperator != null) {
      return false;
    }

    // 4. 괄호 균형 검증
    int openCount = 0;
    for (final filter in filters) {
      openCount += filter.openGroupCount ?? 0;
      openCount -= filter.closeGroupCount ?? 0;

      // 중간에 닫는 괄호가 여는 괄호보다 많으면 안됨
      if (openCount < 0) {
        return false;
      }
    }

    // 최종적으로 괄호가 모두 닫혀야 함
    if (openCount != 0) {
      return false;
    }

    // 5. 각 필터의 연산자와 값 검증
    for (final filter in filters) {
      final operator = filter.operator;
      final value = filter.value;

      // IS NULL, IS NOT NULL은 value가 null이어야 함
      if (operator == 'IS NULL' || operator == 'IS NOT NULL') {
        if (value != null) {
          return false;
        }
      }
      // IN, NOT IN은 value가 List여야 함
      else if (operator == 'IN' || operator == 'NOT IN') {
        if (value is! List) {
          return false;
        }
        // 빈 리스트는 허용하지 않음
        if ((value).isEmpty) {
          return false;
        }
      }
      // LIKE는 value가 String이어야 함
      else if (operator == 'LIKE') {
        if (value is! String) {
          return false;
        }
      }
      // 그 외 연산자는 value가 있어야 함
      else if (operator == '=' || operator == '!=' ||
          operator == '<' || operator == '>' ||
          operator == '<=' || operator == '>=') {
        if (value == null) {
          return false;
        }
      }
      // 알 수 없는 연산자
      else {
        // 향후 추가될 연산자를 위해 경고만 하고 통과시킬 수도 있음
        // 여기서는 엄격하게 검증
        return false;
      }

      // 6. columnName이 비어있으면 안됨
      if (filter.columnName.trim().isEmpty) {
        return false;
      }
    }

    return true;
  }

  /// 상세한 검증 오류 메시지 반환 (디버깅용)
  String? getValidationError() {
    final filters = state.filters;

    if (filters.isEmpty || filters.length == 1) {
      return null;
    }

    // 1. 첫 번째 필터 검증
    if (filters.first.logicalOperator == null) {
      return '두 개 이상의 조건이 존재하는 경우, 첫 번째 필터는 논리 연산자가 있어야 합니다.';
    }

    // 2. 중간 필터들의 논리 연산자 검증
    for (int i = 0; i < filters.length - 1; i++) {
      final logicalOp = filters[i].logicalOperator;
      if (logicalOp == null) {
        return '필터 ${i + 1}번은 논리 연산자(AND/OR)가 필요합니다.';
      }
      if (logicalOp != 'AND' && logicalOp != 'OR') {
        return '필터 ${i + 1}번의 논리 연산자가 유효하지 않습니다: $logicalOp';
      }
    }

    // 3. 마지막 필터 검증
    if (filters.last.logicalOperator != null) {
      return '마지막 필터는 논리 연산자가 없어야 합니다.';
    }

    // 4. 괄호 균형 검증
    int openCount = 0;
    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];
      openCount += filter.openGroupCount ?? 0;
      openCount -= filter.closeGroupCount ?? 0;

      if (openCount < 0) {
        return '필터 ${i + 1}번에서 닫는 괄호가 여는 괄호보다 많습니다.';
      }
    }

    if (openCount > 0) {
      return '닫히지 않은 괄호가 ${openCount}개 있습니다.';
    } else if (openCount < 0) {
      return '여는 괄호보다 닫는 괄호가 ${-openCount}개 더 많습니다.';
    }

    // 5. 각 필터의 연산자와 값 검증
    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];
      final operator = filter.operator;
      final value = filter.value;

      if (filter.columnName.trim().isEmpty) {
        return '필터 ${i + 1}번의 컬럼명이 비어있습니다.';
      }

      if (operator == 'IS NULL' || operator == 'IS NOT NULL') {
        if (value != null) {
          return '필터 ${i + 1}번: $operator 연산자는 값이 없어야 합니다.';
        }
      } else if (operator == 'IN' || operator == 'NOT IN') {
        if (value is! List) {
          return '필터 ${i + 1}번: $operator 연산자는 리스트 값이 필요합니다.';
        }
        if (value.isEmpty) {
          return '필터 ${i + 1}번: $operator 연산자의 리스트가 비어있습니다.';
        }
      } else if (operator == 'LIKE') {
        if (value is! String) {
          return '필터 ${i + 1}번: LIKE 연산자는 문자열 값이 필요합니다.';
        }
      } else if (operator == '=' || operator == '!=' ||
          operator == '<' || operator == '>' ||
          operator == '<=' || operator == '>=') {
        if (value == null) {
          return '필터 ${i + 1}번: $operator 연산자는 값이 필요합니다.';
        }
      } else {
        return '필터 ${i + 1}번: 알 수 없는 연산자입니다: $operator';
      }
    }

    return null;
  }

  /// 데이터 로드 (빌드 중 상태 변경 방지)
  void refreshData({DataEditingState? overwriteState}) {
    if(overwriteState != null) {
      state = overwriteState;
    } else {
      // 덮어쓰지 않고 필요한 경우 무시
      // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
      Future.microtask(() => loadTableData());
    }
  }
  
  /// 필터 추가
  void addFilter(FilterCondition filter) {
    final newFilters = List<FilterCondition>.from(state.filters)..add(filter);
    state = state.copyWith(filters: newFilters);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    // Future.microtask(() => loadTableData());
  }
  
  /// 필터 제거
  // void removeFilter(int index) {
  //   final newFilters = List<FilterCondition>.from(state.filters)..removeAt(index);
  //   state = state.copyWith(filters: newFilters);
  //   // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
  //   Future.microtask(() => loadTableData());
  // }
  
  /// 필터 수정
  void updateFilter(int index, FilterCondition filter) {
    final newFilters = List<FilterCondition>.from(state.filters);
    newFilters[index] = filter;
    state = state.copyWith(filters: newFilters);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    // Future.microtask(() => loadTableData());
  }

  /// 필터 리스트 전체 업데이트 (괄호 조작용)
  void updateFilters(List<FilterCondition> filters) {
    state = state.copyWith(filters: filters);
  }
  
  // /// 필터 모두 제거
  // void clearFilters() {
  //   state = state.copyWith(filters: []);
  //   // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
  //   Future.microtask(() => loadTableData());
  // }
  
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
    // Future.microtask(() => loadTableData());
  }
  
  /// 정렬 추가
  void addSort(SortCondition sort) {
    final newSorts = List<SortCondition>.from(state.sorts)..add(sort);
    state = state.copyWith(sorts: newSorts);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    // Future.microtask(() => loadTableData());
  }
  
  /// 정렬 수정
  void updateSort(int index, SortCondition sort) {
    final newSorts = List<SortCondition>.from(state.sorts);
    newSorts[index] = sort;
    state = state.copyWith(sorts: newSorts);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    // Future.microtask(() => loadTableData());
  }
  
  /// 정렬 제거
  void removeSort(int index) {
    final newSorts = List<SortCondition>.from(state.sorts)..removeAt(index);
    state = state.copyWith(sorts: newSorts);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    // Future.microtask(() => loadTableData());
  }
  
  /// 정렬 모두 제거
  void clearSorts() {
    state = state.copyWith(sorts: []);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    // Future.microtask(() => loadTableData());
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
    // Future.microtask(() => loadTableData());
  }
  
  /// 그룹화 컬럼 추가
  void addGroupByColumn(String columnName) {
    if (!state.groupByColumns.contains(columnName)) {
      final newGroupByColumns = List<String>.from(state.groupByColumns)..add(columnName);
      state = state.copyWith(groupByColumns: newGroupByColumns);
      // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
      // Future.microtask(() => loadTableData());
    }
  }
  
  /// 그룹화 컬럼 제거
  void removeGroupByColumn(String columnName) {
    final newGroupByColumns = List<String>.from(state.groupByColumns)..remove(columnName);
    state = state.copyWith(groupByColumns: newGroupByColumns);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    // Future.microtask(() => loadTableData());
  }
  
  /// 그룹화 모두 제거
  void clearGroupBy() {
    state = state.copyWith(groupByColumns: []);
    // 상태 변경 후 다음 프레임에서 데이터 로드 (빌드 중 상태 변경 방지)
    // Future.microtask(() => loadTableData());
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
    // Future.microtask(() => loadTableData());
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
    final cellKey = '${rowIndex}_$colIndex';
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
          final cellKey = '${rowIndex}_$colIndex';
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

  // 필터 순서 변경
  void reorderFilter(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final filters = List<FilterCondition>.from(state.filters);
    final filter = filters.removeAt(oldIndex);
    filters.insert(newIndex, filter);

    // 연산자와 괄호 정보도 함께 재정렬
    final operators = state.filterOperators != null ? List<String>.from(state.filterOperators!) : <String>[];
    final parenthesis = state.filterParenthesis != null ? List<bool>.from(state.filterParenthesis!) : <bool>[];

    if (operators.isNotEmpty && oldIndex < operators.length) {
      // 연산자는 필터 사이에 있으므로 인덱스 조정 필요
      if (oldIndex > 0 && operators.isNotEmpty) {
        final op = oldIndex - 1 < operators.length ? operators[oldIndex - 1] : 'AND';
        if (newIndex > 0 && newIndex - 1 < operators.length) {
          operators[newIndex - 1] = op;
        }
      }
    }

    if (parenthesis.isNotEmpty && oldIndex < parenthesis.length) {
      final paren = parenthesis.removeAt(oldIndex);
      parenthesis.insert(newIndex, paren);
    }

    state = state.copyWith(
      filters: filters,
      filterOperators: operators.isNotEmpty ? operators : null,
      filterParenthesis: parenthesis.isNotEmpty ? parenthesis : null,
    );
  }

  // AND/OR 연산자 토글
  void toggleFilterOperator(int operatorIndex) {
    final operators = state.filterOperators != null
        ? List<String>.from(state.filterOperators!)
        : List.generate(state.filters.length - 1, (_) => 'AND');

    if (operatorIndex < operators.length) {
      operators[operatorIndex] = operators[operatorIndex] == 'AND' ? 'OR' : 'AND';
      state = state.copyWith(filterOperators: operators);
    }
  }

  // 괄호 토글
  void toggleFilterParenthesis(int filterIndex) {
    final parenthesis = state.filterParenthesis != null
        ? List<bool>.from(state.filterParenthesis!)
        : List.generate(state.filters.length, (_) => false);

    // 리스트 크기 조정
    while (parenthesis.length < state.filters.length) {
      parenthesis.add(false);
    }

    if (filterIndex < parenthesis.length) {
      parenthesis[filterIndex] = !parenthesis[filterIndex];
      state = state.copyWith(filterParenthesis: parenthesis);
    }
  }

  // 필터 컬럼 업데이트
  void updateFilterColumn(int index, String column) {
    if (index >= state.filters.length) return;

    final filters = List<FilterCondition>.from(state.filters);
    final filter = filters[index];

    filters[index] = filter.copyWith(columnName: column);

    state = state.copyWith(filters: filters);
  }

  // 필터 연산자 업데이트
  void updateFilterOperator(int index, String operator) {
    if (index >= state.filters.length) return;

    final filters = List<FilterCondition>.from(state.filters);
    final filter = filters[index];

    filters[index] = filter.copyWith(operator: operator);

    state = state.copyWith(filters: filters);
  }

  // 필터 값 업데이트
  void updateFilterValue(int index, String value) {
    if (index >= state.filters.length) return;

    final filters = List<FilterCondition>.from(state.filters);
    final filter = filters[index];

    filters[index] = filter.copyWith(value: value);

    state = state.copyWith(filters: filters);
  }

  /// 필터 제거
  void removeFilter(int index) {
    debugPrint("========== removeFilter() 호출 ==========");
    debugPrint("제거 요청 index = $index");

    final currentFilters = List<FilterCondition>.from(state.filters);
    debugPrint("초기 filters = $currentFilters");

    if (index >= currentFilters.length) {
      debugPrint("index 오류: 필터 개수보다 큼 → 함수 종료");
      return;
    }

    //------------------------------------------------------
    // 1) 필터 제거
    //------------------------------------------------------
    currentFilters.removeAt(index);
    debugPrint("필터 제거 후 filters = $currentFilters");

    //------------------------------------------------------
    // 2) cleanupFiltersAfterReorder() 적용
    //------------------------------------------------------
    final cleanedFilters = _cleanupFiltersAfterReorder(currentFilters);
    debugPrint("cleanup 적용 후 filters = $cleanedFilters");

    //------------------------------------------------------
    // 3) 빈 괄호로 인한 불필요한 필터가 생겼는지 재귀 체크
    //------------------------------------------------------
    final finalFilters = _removeEmptyParenthesisFilters(cleanedFilters);
    debugPrint("빈 괄호 제거 후 filters = $finalFilters");

    //------------------------------------------------------
    // 4) 최종 state 반영 (operators, parenthesis 제거!)
    //------------------------------------------------------
    state = state.copyWith(
      filters: finalFilters,
      filterOperators: null,      // ← cleanup에서 논리연산자 관리
      filterParenthesis: null,    // ← cleanup에서 괄호 관리
    );

    debugPrint("=== removeFilter() 종료 ===");
    debugPrint("state.filters = ${state.filters}");
    debugPrint("======================================");
  }

  // 모든 필터 제거
  void clearFilters() {
    state = state.copyWith(
      filters: [],
      filterOperators: null,
      filterParenthesis: null,
    );
  }

  void addOpenParenthesis() {
    final blocks = state.filterBlocks != null
        ? List<Map<String, dynamic>>.from(state.filterBlocks!)
        : _createBlocksFromFilters();

    // 조건이 1개 이상일 때만 괄호 추가
    if (state.filters.length > 1) {
      blocks.add({'type': 'open_paren'});
      blocks.add({'type': 'close_paren'});
      state = state.copyWith(filterBlocks: blocks);
    }
  }

  // void addCloseParenthesis() {
  //   final blocks = state.filterBlocks != null
  //       ? List<Map<String, dynamic>>.from(state.filterBlocks!)
  //       : _createBlocksFromFilters();
  //
  //   blocks.add({'type': 'close_paren'});
  //   state = state.copyWith(filterBlocks: blocks);
  // }

  /// 빈 괄호만 있는 필터를 재귀적으로 제거
  List<FilterCondition> _removeEmptyParenthesisFilters(List<FilterCondition> filters) {
    if (filters.isEmpty) return filters;

    bool hasEmptyParenthesis = false;

    // 빈 괄호만 있는 필터 찾기
    // 예: openGroupCount만 있고 실제 조건은 다음 필터에 있는 경우
    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];
      final openCount = filter.openGroupCount ?? 0;
      final closeCount = filter.closeGroupCount ?? 0;

      // 여는 괄호만 있고 다음 필터가 없거나
      // 닫는 괄호만 있고 이전 필터가 없는 경우
      if (openCount > 0 && closeCount == 0 && i == filters.length - 1) {
        hasEmptyParenthesis = true;
        break;
      }

      // 불균형한 괄호 감지
      if (openCount > 0 && i > 0) {
        // 이전 필터들의 괄호 균형 확인
        int balance = 0;
        for (int j = 0; j < i; j++) {
          balance += (filters[j].openGroupCount ?? 0);
          balance -= (filters[j].closeGroupCount ?? 0);
        }
        // 현재 여는 괄호 추가
        balance += openCount;

        // 닫히지 않은 괄호가 필터 개수보다 많으면 불필요한 괄호
        if (balance > filters.length - i) {
          hasEmptyParenthesis = true;
          break;
        }
      }
    }

    if (!hasEmptyParenthesis) {
      return filters;
    }

    // 괄호 재정리
    final result = <FilterCondition>[];

    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];
      int openCount = filter.openGroupCount ?? 0;
      int closeCount = filter.closeGroupCount ?? 0;

      // 마지막 필터에 여는 괄호만 있으면 제거
      if (i == filters.length - 1 && openCount > 0 && closeCount == 0) {
        openCount = 0;
      }

      // 첫 번째 필터에 닫는 괄호만 있으면 제거
      if (i == 0 && closeCount > 0 && openCount == 0) {
        closeCount = 0;
      }

      // 괄호 균형 체크 후 과도한 괄호 제거
      int currentBalance = 0;
      for (int j = 0; j <= i; j++) {
        currentBalance += (result.length > j ? result[j].openGroupCount ?? 0 :
        (j == i ? openCount : filters[j].openGroupCount ?? 0));
        currentBalance -= (result.length > j ? result[j].closeGroupCount ?? 0 :
        (j == i ? closeCount : filters[j].closeGroupCount ?? 0));
      }

      // 균형이 음수가 되면 닫는 괄호가 너무 많음
      if (currentBalance < 0) {
        closeCount = Math.max(0, closeCount + currentBalance);
      }

      result.add(filter.copyWith(
        openGroupCount: openCount > 0 ? openCount : 0,
        closeGroupCount: closeCount > 0 ? closeCount : 0,
      ));
    }

    // 변경사항이 있으면 재귀 호출
    bool changed = false;
    for (int i = 0; i < filters.length; i++) {
      if ((filters[i].openGroupCount ?? 0) != (result[i].openGroupCount ?? 0) ||
          (filters[i].closeGroupCount ?? 0) != (result[i].closeGroupCount ?? 0)) {
        changed = true;
        break;
      }
    }

    if (changed) {
      debugPrint("괄호 정리 후 재귀 호출");
      return _removeEmptyParenthesisFilters(result);
    }

    return result;
  }

  /// 블록 재정렬 (드래그 앤 드롭)
  void reorderFilterBlock(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final blocks = _buildFilterBlockList();
    if (oldIndex >= blocks.length || newIndex > blocks.length) return;

    // 이동할 블록
    final movingBlock = blocks[oldIndex];

    // 필터 블록인 경우: 필터 자체를 이동 (괄호 포함)
    if (movingBlock['type'] == 'filter') {
      final filterIndex = movingBlock['index'] as int;

      // 새로운 필터 인덱스 계산 (블록 인덱스를 필터 인덱스로 변환)
      int newFilterIndex = 0;
      for (int i = 0; i < newIndex && i < blocks.length; i++) {
        if (blocks[i]['type'] == 'filter') {
          newFilterIndex++;
        }
      }

      // 필터 재정렬
      final newFilters = List<FilterCondition>.from(state.filters);
      final filter = newFilters.removeAt(filterIndex);

      // oldIndex > newIndex인 경우 인덱스 조정
      final adjustedNewIndex = filterIndex < newFilterIndex ? newFilterIndex - 1 : newFilterIndex;

      // adjustedNewIndex가 범위를 벗어나지 않도록 보정
      final finalNewIndex = adjustedNewIndex.clamp(0, newFilters.length);
      newFilters.insert(finalNewIndex, filter);

      // 빈 괄호 제거 및 연산자 재배치
      final cleanedFilters = _cleanupFiltersAfterReorder(newFilters);

      state = state.copyWith(filters: cleanedFilters);
    }
    // 괄호 블록인 경우: 괄호만 이동
    else if (movingBlock['type'] == 'openparen' || movingBlock['type'] == 'closeparen') {
      _moveParenthesis(oldIndex, newIndex, blocks);
    }
    // 연산자 블록인 경우: 연산자 토글로 처리하므로 이동 불가
    else {
      return;
    }
  }

  /// 필터 재정렬 후 정리: 빈 괄호 제거 및 연산자 재배치
  List<FilterCondition> _cleanupFiltersAfterReorder(List<FilterCondition> filters) {
    // Step 0: 제거 과정에서 생긴 고아 괄호 제거
    for (int i = 0; i < filters.length; i++) {
      final f = filters[i];
      // open/closeGroupCount가 1이더라도 필터 제거 후 의미 없을 수 있음
      if ((f.openGroupCount ?? 0) > 0 || (f.closeGroupCount ?? 0) > 0) {
        // 남아있는 필터 개수 대비 괄호 개수가 성립하지 않으면 제거
        if (filters.length == 1) {
          // 필터가 1개 남았는데 괄호가 있으면 무의미하므로 제거
          filters[i] = f.copyWith(openGroupCount: 0, closeGroupCount: 0);
        }
      }
    }

    if (filters.isEmpty) return filters;

    final cleanedFilters = <FilterCondition>[];

    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];

      // 빈 괄호 쌍 제거 체크
      int openCount = filter.openGroupCount ?? 0;
      int closeCount = filter.closeGroupCount ?? 0;

      // 여는 괄호와 닫는 괄호가 같은 필터에 있고,
      // 이것이 유일한 필터이거나 괄호 사이에 다른 필터가 없는 경우 괄호 제거
      if (openCount > 0 && closeCount > 0) {
        // 같은 필터에 여는 괄호와 닫는 괄호가 있으면 하나씩 제거
        final pairsToRemove = openCount < closeCount ? openCount : closeCount;
        openCount -= pairsToRemove;
        closeCount -= pairsToRemove;
      }

      // 연산자 재배치: 마지막 필터가 아니면 연산자 유지, 마지막이면 제거
      String? logicalOperator;
      if (i < filters.length - 1) {
        // 마지막이 아닌 경우: 기존 연산자 유지 또는 기본값 'AND'
        logicalOperator = filter.logicalOperator ?? 'AND';
      } else {
        // 마지막 필터는 연산자가 없어야 함
        logicalOperator = null;
      }

      cleanedFilters.add(filter.copyWith(
        openGroupCount: openCount > 0 ? openCount : 0,
        closeGroupCount: closeCount > 0 ? closeCount : 0,
        logicalOperator: logicalOperator,
      ));
    }
    debugPrint("======================================");
    final debugBlocks = _buildFilterBlockListFromFilters(cleanedFilters);
    debugPrint("[_cleanupFiltersAfterReorder] blocks.asMap().entries: ${debugBlocks.asMap().entries}");

    // 괄호 균형 검증 및 추가 정리
    return _balanceParentheses(cleanedFilters);
  }

  List<Map<String, dynamic>> _buildFilterBlockListFromFilters(List<FilterCondition> filters) {
    final List<Map<String, dynamic>> blocks = [];

    for (int i = 0; i < filters.length; i++) {
      final f = filters[i];

      // 여는 괄호
      if ((f.openGroupCount ?? 0) > 0) {
        blocks.add({"type": "openparen"});
      }

      // 필터 자체
      blocks.add({
        "type": "filter",
        "index": i,
      });

      // 연산자
      if (f.logicalOperator != null) {
        blocks.add({
          "type": "operator",
          "value": f.logicalOperator,
        });
      }

      // 닫는 괄호
      if ((f.closeGroupCount ?? 0) > 0) {
        blocks.add({"type": "closeparen"});
      }
    }

    return blocks;
  }

  /// 괄호 균형 맞추기 및 빈 괄호 제거
  List<FilterCondition> _balanceParentheses(List<FilterCondition> filters) {
    if (filters.isEmpty) return filters;

    // 1단계: 괄호 균형 확인 및 조정
    int balance = 0;
    final balancedFilters = <FilterCondition>[];

    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];
      int openCount = filter.openGroupCount ?? 0;
      int closeCount = filter.closeGroupCount ?? 0;

      // 닫는 괄호가 너무 많은 경우 조정
      if (balance + openCount - closeCount < 0) {
        closeCount = balance + openCount;
      }

      balance += openCount - closeCount;

      balancedFilters.add(filter.copyWith(
        openGroupCount: openCount > 0 ? openCount : 0,
        closeGroupCount: closeCount > 0 ? closeCount : 0,
      ));
    }

    // 여는 괄호가 남아있는 경우 (balance > 0), 마지막부터 제거
    if (balance > 0) {
      debugPrint("[_balanceParentheses] 닫히지 않은 여는 괄호 ${balance}개 감지 - 제거 시작");

      for (int i = balancedFilters.length - 1; i >= 0 && balance > 0; i--) {
        final filter = balancedFilters[i];
        int openCount = filter.openGroupCount ?? 0;

        if (openCount > 0) {
          // 제거할 여는 괄호 개수 계산
          final removeCount = Math.min(openCount, balance);
          final newOpenCount = openCount - removeCount;
          balance -= removeCount;

          balancedFilters[i] = filter.copyWith(
            openGroupCount: newOpenCount > 0 ? newOpenCount : 0,
          );

          debugPrint("[_balanceParentheses] 필터 $i의 여는 괄호 $removeCount개 제거 (남은 불균형: $balance)");
        }
      }
    }

    // 닫는 괄호가 남아있는 경우 (balance < 0), 처음부터 제거
    if (balance < 0) {
      debugPrint("[_balanceParentheses] 열리지 않은 닫는 괄호 ${-balance}개 감지 - 제거 시작");

      for (int i = 0; i < balancedFilters.length && balance < 0; i++) {
        final filter = balancedFilters[i];
        int closeCount = filter.closeGroupCount ?? 0;

        if (closeCount > 0) {
          // 제거할 닫는 괄호 개수 계산
          final removeCount = Math.min(closeCount, -balance);
          final newCloseCount = closeCount - removeCount;
          balance += removeCount;

          balancedFilters[i] = filter.copyWith(
            closeGroupCount: newCloseCount > 0 ? newCloseCount : 0,
          );

          debugPrint("[_balanceParentheses] 필터 $i의 닫는 괄호 $removeCount개 제거 (남은 불균형: $balance)");
        }
      }
    }

    // 2단계: 빈 괄호 쌍 제거
    final result = <FilterCondition>[];

    for (int i = 0; i < balancedFilters.length; i++) {
      final filter = balancedFilters[i];
      int openCount = filter.openGroupCount ?? 0;
      int closeCount = filter.closeGroupCount ?? 0;

      // 같은 필터에 여는/닫는 괄호가 있는 경우 (빈 괄호)
      if (openCount > 0 && closeCount > 0) {
        // 괄호 안에 다른 필터가 있는지 확인
        // 단, 연속된 여는/닫는 괄호는 빈 괄호로 간주하여 제거
        if (openCount == closeCount) {
          // 모든 괄호 쌍 제거 (빈 괄호)
          debugPrint("[_balanceParentheses] 필터 $i의 빈 괄호 쌍 ${openCount}개 제거");
          openCount = 0;
          closeCount = 0;
        }
      }

      result.add(filter.copyWith(
        openGroupCount: openCount > 0 ? openCount : 0,
        closeGroupCount: closeCount > 0 ? closeCount : 0,
      ));
    }

    return result;
  }

  /// 필터 블록 리스트 생성 (내부용)
  List<Map<String, dynamic>> _buildFilterBlockList() {
    final blocks = <Map<String, dynamic>>[];
    final filters = state.filters;

    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];

      // openGroupCount 만큼 여는 괄호 추가
      final openCount = filter.openGroupCount ?? 0;
      for (int j = 0; j < openCount; j++) {
        blocks.add({'type': 'openparen'});
      }

      blocks.add({'type': 'filter', 'index': i});

      // closeGroupCount 만큼 닫는 괄호 추가
      final closeCount = filter.closeGroupCount ?? 0;
      for (int j = 0; j < closeCount; j++) {
        blocks.add({'type': 'closeparen'});
      }

      if (i < filters.length - 1) {
        blocks.add({
          'type': 'operator',
          'value': filter.logicalOperator ?? 'AND',
        });
      }
    }

    return blocks;
  }

  /// 괄호 이동 처리
  void _moveParenthesis(int oldBlockIndex, int newBlockIndex, List<Map<String, dynamic>> blocks) {
    if (oldBlockIndex >= blocks.length || newBlockIndex >= blocks.length) return;

    final movingBlock = blocks[oldBlockIndex];
    final isOpenParen = movingBlock['type'] == 'openparen';

    // 이동할 괄호가 속한 필터 인덱스 찾기
    int? oldFilterIndex;
    if (isOpenParen) {
      // 여는 괄호: 바로 다음 필터
      for (int i = oldBlockIndex; i < blocks.length; i++) {
        if (blocks[i]['type'] == 'filter') {
          oldFilterIndex = blocks[i]['index'] as int;
          break;
        }
      }
    } else {
      // 닫는 괄호: 바로 이전 필터
      for (int i = oldBlockIndex; i >= 0; i--) {
        if (blocks[i]['type'] == 'filter') {
          oldFilterIndex = blocks[i]['index'] as int;
          break;
        }
      }
    }

    if (oldFilterIndex == null) return;

    // 새로운 위치의 필터 인덱스 찾기
    int? newFilterIndex;
    if (isOpenParen) {
      // 여는 괄호: 바로 다음 필터
      for (int i = newBlockIndex; i < blocks.length; i++) {
        if (blocks[i]['type'] == 'filter') {
          newFilterIndex = blocks[i]['index'] as int;
          break;
        }
      }
    } else {
      // 닫는 괄호: 바로 이전 필터
      for (int i = newBlockIndex; i >= 0; i--) {
        if (blocks[i]['type'] == 'filter') {
          newFilterIndex = blocks[i]['index'] as int;
          break;
        }
      }
    }

    if (newFilterIndex == null) return;
    if (oldFilterIndex == newFilterIndex) return;

    // 필터 리스트 업데이트
    final newFilters = <FilterCondition>[];
    for (int i = 0; i < state.filters.length; i++) {
      final filter = state.filters[i];

      if (i == oldFilterIndex) {
        // 기존 위치에서 괄호 제거
        if (isOpenParen) {
          final newOpenCount = (filter.openGroupCount ?? 0) - 1;
          newFilters.add(filter.copyWith(
            openGroupCount: newOpenCount > 0 ? newOpenCount : 0,
          ));
        } else {
          final newCloseCount = (filter.closeGroupCount ?? 0) - 1;
          newFilters.add(filter.copyWith(
            closeGroupCount: newCloseCount > 0 ? newCloseCount : 0,
          ));
        }
      } else if (i == newFilterIndex) {
        // 새로운 위치에 괄호 추가
        if (isOpenParen) {
          newFilters.add(filter.copyWith(
            openGroupCount: (filter.openGroupCount ?? 0) + 1,
          ));
        } else {
          newFilters.add(filter.copyWith(
            closeGroupCount: (filter.closeGroupCount ?? 0) + 1,
          ));
        }
      } else {
        newFilters.add(filter);
      }
    }

    // 빈 괄호 제거
    final cleanedFilters = _cleanupFiltersAfterReorder(newFilters);

    state = state.copyWith(filters: cleanedFilters);
  }

  /// AND & OR 토글
  void toggleFilterOperatorAtBlock(int blockIndex) {
    final blocks = _buildFilterBlockList();

    if (blockIndex >= blocks.length) return;
    final block = blocks[blockIndex];

    if (block['type'] != 'operator') return;

    // 해당 연산자가 몇 번째 필터의 logicalOperator인지 찾기
    // 연산자는 필터 바로 뒤에 위치하므로, 이전 필터를 찾음
    int? filterIndex;
    for (int i = blockIndex - 1; i >= 0; i--) {
      if (blocks[i]['type'] == 'filter') {
        filterIndex = blocks[i]['index'] as int;
        break;
      }
    }

    if (filterIndex == null || filterIndex >= state.filters.length) return;

    // 해당 필터의 logicalOperator 토글
    final newFilters = List<FilterCondition>.from(state.filters);
    final filter = newFilters[filterIndex];
    final currentOp = filter.logicalOperator ?? 'AND';
    final newOp = currentOp == 'AND' ? 'OR' : 'AND';

    newFilters[filterIndex] = filter.copyWith(logicalOperator: newOp);

    state = state.copyWith(filters: newFilters);
  }

  void removeBlockAt(int blockIndex) {
    final blocks = state.filterBlocks != null
        ? List<Map<String, dynamic>>.from(state.filterBlocks!)
        : _createBlocksFromFilters();

    if (blockIndex < blocks.length) {
      blocks.removeAt(blockIndex);
      state = state.copyWith(filterBlocks: blocks);
    }
  }

  List<Map<String, dynamic>> _createBlocksFromFilters() {
    final blocks = <Map<String, dynamic>>[];
    for (int i = 0; i < state.filters.length; i++) {
      blocks.add({'type': 'filter', 'index': i});
      if (i < state.filters.length - 1) {
        blocks.add({'type': 'operator', 'value': 'AND'});
      }
    }
    return blocks;
  }

  void removeBlockAtBlockIndex(int blockIndex) {
    final blocks = _buildFilterBlockList();
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return;
    }

    final block = blocks[blockIndex];

    if (block['type'] == 'filter') {
      // 필터 제거
      final filterIndex = block['index'] as int;
      removeFilter(filterIndex);
    }
    else if (block['type'] == 'openparen' || block['type'] == 'closeparen') {
      // 괄호 제거: 해당 괄호가 속한 필터 찾아서 카운트 감소
      int? filterIndex;
      final isOpenParen = block['type'] == 'openparen';

      if (isOpenParen) {
        // 여는 괄호: 바로 다음 필터
        for (int i = blockIndex; i < blocks.length; i++) {
          if (blocks[i]['type'] == 'filter') {
            filterIndex = blocks[i]['index'] as int;
            break;
          }
        }
      } else {
        // 닫는 괄호: 바로 이전 필터
        for (int i = blockIndex; i >= 0; i--) {
          if (blocks[i]['type'] == 'filter') {
            filterIndex = blocks[i]['index'] as int;
            break;
          }
        }
      }

      if (filterIndex != null && filterIndex < state.filters.length) {
        final filter = state.filters[filterIndex];
        final newFilters = List<FilterCondition>.from(state.filters);

        if (isOpenParen) {
          final newOpenCount = (filter.openGroupCount ?? 0) - 1;
          newFilters[filterIndex] = filter.copyWith(
            openGroupCount: newOpenCount > 0 ? newOpenCount : 0,
          );
        } else {
          final newCloseCount = (filter.closeGroupCount ?? 0) - 1;
          newFilters[filterIndex] = filter.copyWith(
            closeGroupCount: newCloseCount > 0 ? newCloseCount : 0,
          );
        }

        state = state.copyWith(filters: newFilters);
      }
    }
  }

  List<Map<String, dynamic>> buildFilterBlockList(DataEditingState state) {
    final List<Map<String, dynamic>> blocks = [];
    final parenthesis = state.filterParenthesis ?? [];

    for (int i = 0; i < state.filters.length; i++) {
      // 조건 앞에 열림 괄호가 있으면 추가
      if (i < parenthesis.length && parenthesis[i]) {
        blocks.add({'type': 'openparen'});
      }

      // 필터 조건 블럭 추가
      blocks.add({'type': 'filter', 'index': i});

      // 조건 뒤에 닫힘 괄호가 있으면 추가
      if (i + 1 < parenthesis.length && parenthesis[i + 1]) {
        blocks.add({'type': 'closeparen'});
      }

      // 마지막 조건이 아니면 논리 연산자 ('AND' or 'OR') 추가
      if (i < state.filters.length - 1) {
        blocks.add({
          'type': 'operator',
          'value': state.filterOperators?[i] ?? 'AND',
        });
      }
    }

    return blocks;
  }
}

/// DatabaseHandler Provider Factory
final databaseHandlerProvider = Provider.family<DatabaseHandler, DatabaseHandlerParams>(
  (ref, params) {
    switch (params.server.type) {
      case 'PostgreSQL':
        return PostgresHandler(params.server, databaseName: params.database);
      default:
        throw Exception('Unsupported database type: ${params.server.type}');
    }
  },
);

class DatabaseHandlerParams {
  final ServerModel server;
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
  final ServerModel server;
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
              server == other.server &&
              database == other.database &&
              table == other.table;

  @override
  int get hashCode => server.hashCode ^ database.hashCode ^ table.hashCode;
}