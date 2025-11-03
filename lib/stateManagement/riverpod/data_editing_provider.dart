import 'dart:math' as math;

import 'package:db_handler/db/database_handler.dart';
import 'package:db_handler/db/postgres_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class DataEditingArgs {
  const DataEditingArgs({
    required this.server,
    required this.database,
    required this.table,
  });

  final Map<String, dynamic> server;
  final String database;
  final String table;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataEditingArgs &&
        identical(server, other.server) &&
        database == other.database &&
        table == other.table;
  }

  @override
  int get hashCode => Object.hash(server, database, table);
}

@immutable
class DataColumnInfo {
  const DataColumnInfo({
    required this.name,
    required this.type,
  });

  final String name;
  final String type;
}

const _copyWithSentinel = Object();

@immutable
class DataEditingState {
  const DataEditingState({
    required this.isLoading,
    required this.error,
    required this.columns,
    required this.rows,
    required this.primaryKeyColumn,
    required this.columnWidths,
    required this.minColumnWidths,
  });

  final bool isLoading;
  final String? error;
  final List<DataColumnInfo> columns;
  final List<Map<String, dynamic>> rows;
  final String? primaryKeyColumn;
  final List<double> columnWidths;
  final List<double> minColumnWidths;

  bool get hasColumns => columns.isNotEmpty;

  double widthAt(int index) => columnWidths[index];

  double minWidthAt(int index) => minColumnWidths[index];

  Map<String, dynamic> rowAt(int index) => rows[index];

  dynamic cellValue(int rowIndex, int columnIndex) {
    final columnName = columns[columnIndex].name;
    return rows[rowIndex][columnName];
  }

  DataEditingState copyWith({
    bool? isLoading,
    Object? error = _copyWithSentinel,
    List<DataColumnInfo>? columns,
    List<Map<String, dynamic>>? rows,
    String? primaryKeyColumn,
    List<double>? columnWidths,
    List<double>? minColumnWidths,
  }) {
    return DataEditingState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _copyWithSentinel) ? this.error : error as String?,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      primaryKeyColumn: primaryKeyColumn ?? this.primaryKeyColumn,
      columnWidths: columnWidths ?? this.columnWidths,
      minColumnWidths: minColumnWidths ?? this.minColumnWidths,
    );
  }

  static DataEditingState initial() => const DataEditingState(
        isLoading: true,
        error: null,
        columns: [],
        rows: [],
        primaryKeyColumn: null,
        columnWidths: [60.0, 100.0],
        minColumnWidths: [60.0, 100.0],
      );
}

class DataEditingNotifier extends StateNotifier<DataEditingState> {
  DataEditingNotifier(this._args)
      : _dbHandler = _createDbHandler(_args.server, _args.database),
        super(DataEditingState.initial()) {
    _loadTableData();
  }

  final DataEditingArgs _args;
  final DatabaseHandler _dbHandler;

  static DatabaseHandler _createDbHandler(Map<String, dynamic> server, String database) {
    switch (server['type']) {
      case 'PostgreSQL':
        return PostgresHandler(server, database: database);
      default:
        throw Exception('Unsupported database type: ${server['type']}');
    }
  }

  Future<void> refresh() => _loadTableData();

  Future<void> _loadTableData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final columns = await _dbHandler.getColumns(_args.table);
      final primaryKey = await _dbHandler.getPrimaryKey(_args.table);
      final rows = await _dbHandler.getData(_args.table);

      final columnInfos = columns
          .map((c) => DataColumnInfo(name: c['name'] as String, type: c['type'] as String))
          .toList(growable: false);

      final minWidths = _calculateInitialMinWidths(columnInfos);
      final initialWidths = _calculateColumnWidths(columnInfos, rows, minWidths);

      state = state.copyWith(
        isLoading: false,
        error: null,
        columns: columnInfos,
        rows: rows,
        primaryKeyColumn: primaryKey,
        minColumnWidths: minWidths,
        columnWidths: initialWidths,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load table data: $e');
    }
  }

  Future<void> updateCellValue({
    required int rowIndex,
    required int columnIndex,
    required String columnName,
    required dynamic newValue,
  }) async {
    final pkColumn = state.primaryKeyColumn;
    if (pkColumn == null) {
      throw Exception('Error: Cannot edit cell without a primary key.');
    }

    final rows = state.rows;
    if (rowIndex < 0 || rowIndex >= rows.length) {
      throw Exception('Invalid row index.');
    }

    final pkValue = rows[rowIndex][pkColumn];
    await _dbHandler.updateCell(
      _args.table,
      columnName,
      newValue,
      pkColumn,
      pkValue,
    );

    final updatedRows = List<Map<String, dynamic>>.from(rows);
    final updatedRow = Map<String, dynamic>.from(updatedRows[rowIndex]);
    updatedRow[columnName] = newValue;
    updatedRows[rowIndex] = updatedRow;

    final updatedColumnWidths = List<double>.from(state.columnWidths);
    final widthIndex = columnIndex + 1; // account for row number column
    final measuredWidth = _measureCellWidth(newValue);
    updatedColumnWidths[widthIndex] = math.max(
      updatedColumnWidths[widthIndex],
      math.max(state.minColumnWidths[widthIndex], measuredWidth),
    );

    state = state.copyWith(rows: updatedRows, columnWidths: updatedColumnWidths);
  }

  Future<void> addRow(Map<String, dynamic> values) async {
    await _dbHandler.addRow(_args.table, values);
    await _loadTableData();
  }

  Future<void> updateRow({
    required Map<String, dynamic> values,
    required dynamic primaryKeyValue,
  }) async {
    final pkColumn = state.primaryKeyColumn;
    if (pkColumn == null) {
      throw Exception('Error: Cannot update without a primary key.');
    }
    await _dbHandler.updateRow(_args.table, values, pkColumn, primaryKeyValue);
    await _loadTableData();
  }

  Future<void> deleteRow(dynamic primaryKeyValue) async {
    final pkColumn = state.primaryKeyColumn;
    if (pkColumn == null) {
      throw Exception('Error: Cannot delete without a primary key.');
    }
    await _dbHandler.deleteRow(_args.table, pkColumn, primaryKeyValue);
    await _loadTableData();
  }

  Future<void> addColumn(
    String columnName,
    String dataType,
    String constraints,
  ) async {
    await _dbHandler.addColumn(_args.table, columnName, dataType, constraints);
    await _loadTableData();
  }

  Future<void> modifyColumn(
    String originalName,
    String newName,
    String dataType,
    String constraints,
  ) async {
    await _dbHandler.modifyColumn(_args.table, originalName, newName, dataType, constraints);
    await _loadTableData();
  }

  void updateColumnWidth(int columnIndex, double newWidth) {
    final updated = List<double>.from(state.columnWidths);
    final minWidth = state.minColumnWidths[columnIndex];
    updated[columnIndex] = math.max(newWidth, minWidth);
    state = state.copyWith(columnWidths: updated, error: state.error);
  }

  static List<double> _calculateInitialMinWidths(List<DataColumnInfo> columns) {
    final minWidths = <double>[60.0]; // row number column
    for (final column in columns) {
      final headerWidth = _measureTextWidth(
        column.name,
        const TextStyle(fontWeight: FontWeight.bold),
      );
      minWidths.add(headerWidth + 34.0);
    }
    minWidths.add(100.0); // actions column
    return minWidths;
  }

  static List<double> _calculateColumnWidths(
    List<DataColumnInfo> columns,
    List<Map<String, dynamic>> rows,
    List<double> minWidths,
  ) {
    final widths = <double>[];

    for (var i = 0; i < minWidths.length; i++) {
      if (i == 0) {
        widths.add(minWidths[i]);
        continue;
      }

      if (i == minWidths.length - 1) {
        widths.add(100.0);
        continue;
      }

      final columnIndex = i - 1;
      final columnName = columns[columnIndex].name;
      double maxWidth = minWidths[i];
      for (final row in rows) {
        final value = row[columnName]?.toString() ?? 'NULL';
        final cellWidth = _measureTextWidth(value, const TextStyle()) + 34.0;
        maxWidth = math.max(maxWidth, cellWidth);
      }
      widths.add(maxWidth);
    }

    return widths;
  }

  static double _measureTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return painter.size.width;
  }

  static double _measureCellWidth(dynamic value) {
    final display = value?.toString() ?? 'NULL';
    return _measureTextWidth(display, const TextStyle()) + 34.0;
  }
}

@immutable
class SelectedCell {
  const SelectedCell({required this.rowIndex, required this.colIndex});

  final int rowIndex;
  final int colIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedCell && other.rowIndex == rowIndex && other.colIndex == colIndex;
  }

  @override
  int get hashCode => Object.hash(rowIndex, colIndex);
}

@immutable
class DataEditingSelectionState {
  const DataEditingSelectionState({
    this.selectedColumnIndex,
    this.selectedRowIndex,
    this.selectedCell,
  });

  final int? selectedColumnIndex;
  final int? selectedRowIndex;
  final SelectedCell? selectedCell;

  static const DataEditingSelectionState initial = DataEditingSelectionState();

  bool isColumnSelected(int index) => selectedColumnIndex == index;

  bool isRowSelected(int index) => selectedRowIndex == index;

  bool isCellSelected(int rowIndex, int colIndex) {
    final cell = selectedCell;
    if (cell == null) return false;
    return cell.rowIndex == rowIndex && cell.colIndex == colIndex;
  }

  DataEditingSelectionState copyWith({
    int? selectedColumnIndex,
    int? selectedRowIndex,
    SelectedCell? selectedCell,
  }) {
    return DataEditingSelectionState(
      selectedColumnIndex: selectedColumnIndex,
      selectedRowIndex: selectedRowIndex,
      selectedCell: selectedCell,
    );
  }
}

class DataEditingSelectionNotifier extends StateNotifier<DataEditingSelectionState> {
  DataEditingSelectionNotifier() : super(DataEditingSelectionState.initial);

  void toggleColumn(int index) {
    if (state.selectedColumnIndex == index) {
      clear();
    } else {
      selectColumn(index);
    }
  }

  void toggleRow(int index) {
    if (state.selectedRowIndex == index) {
      clear();
    } else {
      selectRow(index);
    }
  }

  void toggleCell(int rowIndex, int colIndex) {
    final cell = state.selectedCell;
    if (cell != null && cell.rowIndex == rowIndex && cell.colIndex == colIndex) {
      clear();
    } else {
      selectCell(rowIndex, colIndex);
    }
  }

  void selectColumn(int index) {
    state = DataEditingSelectionState(selectedColumnIndex: index);
  }

  void selectRow(int index) {
    state = DataEditingSelectionState(selectedRowIndex: index);
  }

  void selectCell(int rowIndex, int colIndex) {
    state = DataEditingSelectionState(selectedCell: SelectedCell(rowIndex: rowIndex, colIndex: colIndex));
  }

  void clear() {
    state = DataEditingSelectionState.initial;
  }
}

final dataEditingProvider = AutoDisposeStateNotifierProviderFamily<DataEditingNotifier, DataEditingState, DataEditingArgs>(
  (ref, args) => DataEditingNotifier(args),
);

final dataEditingSelectionProvider =
    AutoDisposeStateNotifierProviderFamily<DataEditingSelectionNotifier, DataEditingSelectionState, DataEditingArgs>(
  (ref, args) => DataEditingSelectionNotifier(),
);
