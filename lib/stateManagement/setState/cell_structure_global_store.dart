// lib/stateManagement/setState/cell_structure_global_store.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cell_structure.dart';
import 'cell_structure_export.dart';

/// 서버-데이터베이스-테이블 단위 항목
class GlobalCellStructureEntry {
  final String server;
  final String database;
  final String table;
  final Map<String, CellStructure> structures;
  /// 일반모드 컬럼 폭 비율 목록
  final List<double>? columnWidths;
  /// 구조모드 컬럼 폭 비율 목록
  final List<double>? displayColumnWidths;

  const GlobalCellStructureEntry({
    required this.server,
    required this.database,
    required this.table,
    required this.structures,
    this.columnWidths,
    this.displayColumnWidths,
  });

  Map<String, dynamic> toJson() => {
        'server': server,
        'database': database,
        'table': table,
        'structures': structures.map((k, v) => MapEntry(k, v.toJson())),
        if (columnWidths != null && columnWidths!.isNotEmpty)
          'columnWidths': columnWidths,
        if (displayColumnWidths != null && displayColumnWidths!.isNotEmpty)
          'displayColumnWidths': displayColumnWidths,
      };

  factory GlobalCellStructureEntry.fromJson(Map<String, dynamic> j) {
    final raw = j['structures'] as Map<String, dynamic>? ?? {};
    return GlobalCellStructureEntry(
      server: j['server'] as String? ?? '',
      database: j['database'] as String? ?? '',
      table: j['table'] as String? ?? '',
      structures: raw.map(
        (k, v) => MapEntry(k, CellStructure.fromJson(v as Map<String, dynamic>)),
      ),
      columnWidths: _parseDoubleList(j['columnWidths']),
      displayColumnWidths: _parseDoubleList(j['displayColumnWidths']),
    );
  }

  static List<double>? _parseDoubleList(dynamic raw) {
    if (raw == null) return null;
    try {
      return (raw as List).map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }
}

/// 여러 서버/테이블을 포함하는 전체 내보내기 포맷
class GlobalCellStructureExport {
  static const _formatVersion = 'multi-table-1';

  final CellStructureMetadata metadata;
  final List<GlobalCellStructureEntry> entries;

  const GlobalCellStructureExport({
    required this.metadata,
    required this.entries,
  });

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert({
      'formatVersion': _formatVersion,
      'metadata': metadata.toJson(),
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  static bool isGlobalFormat(Map<String, dynamic> json) =>
      json['formatVersion'] == _formatVersion || json.containsKey('entries');

  factory GlobalCellStructureExport.fromJson(Map<String, dynamic> json) {
    final meta = json.containsKey('metadata')
        ? CellStructureMetadata.fromJson(
            json['metadata'] as Map<String, dynamic>)
        : const CellStructureMetadata(name: '', createdAt: '', table: '');
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    return GlobalCellStructureExport(
      metadata: meta,
      entries: rawEntries
          .map((e) =>
              GlobalCellStructureEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// SharedPreferences 에서 모든 셀 구조 설정 + 컬럼 폭을 읽고 쓰는 유틸리티
class CellStructureGlobalStore {
  static const _prefix = 'cell_structures|';
  static const _widthsPrefix = 'column_widths|';
  static const _displayWidthsPrefix = 'column_widths_display|';

  /// SharedPreferences 의 모든 항목을 읽어 반환 (셀 구조 + 컬럼 폭 포함)
  static Future<List<GlobalCellStructureEntry>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()
      ..sort();
    final entries = <GlobalCellStructureEntry>[];
    for (final key in keys) {
      final parts = key.split('|');
      if (parts.length != 4) continue;
      final server = parts[1];
      final database = parts[2];
      final table = parts[3];
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final structures = decoded.map(
          (k, v) =>
              MapEntry(k, CellStructure.fromJson(v as Map<String, dynamic>)),
        );

        // 일반모드 컬럼 폭 읽기
        List<double>? columnWidths;
        final widthsRaw =
            prefs.getString('$_widthsPrefix$server|$database|$table');
        if (widthsRaw != null) {
          try {
            columnWidths = (jsonDecode(widthsRaw) as List)
                .map((e) => (e as num).toDouble())
                .toList();
          } catch (_) {}
        }

        // 구조모드 컬럼 폭 읽기
        List<double>? displayColumnWidths;
        final displayWidthsRaw =
            prefs.getString('$_displayWidthsPrefix$server|$database|$table');
        if (displayWidthsRaw != null) {
          try {
            displayColumnWidths = (jsonDecode(displayWidthsRaw) as List)
                .map((e) => (e as num).toDouble())
                .toList();
          } catch (_) {}
        }

        entries.add(GlobalCellStructureEntry(
          server: server,
          database: database,
          table: table,
          structures: structures,
          columnWidths: columnWidths,
          displayColumnWidths: displayColumnWidths,
        ));
      } catch (_) {}
    }
    return entries;
  }

  /// 선택한 항목들을 SharedPreferences 에 저장 (기존 항목 병합)
  static Future<void> writeEntries(
      List<GlobalCellStructureEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in entries) {
      final key = '$_prefix${entry.server}|${entry.database}|${entry.table}';
      // 기존 항목이 있으면 병합, 없으면 신규 저장
      final existingRaw = prefs.getString(key);
      final existing = existingRaw != null
          ? (jsonDecode(existingRaw) as Map<String, dynamic>).map(
              (k, v) => MapEntry(
                  k, CellStructure.fromJson(v as Map<String, dynamic>)),
            )
          : <String, CellStructure>{};
      final merged = {...existing, ...entry.structures};
      final encoded =
          jsonEncode(merged.map((k, v) => MapEntry(k, v.toJson())));
      await prefs.setString(key, encoded);

      // 컬럼 폭 저장
      if (entry.columnWidths != null && entry.columnWidths!.isNotEmpty) {
        await prefs.setString(
          '$_widthsPrefix${entry.server}|${entry.database}|${entry.table}',
          jsonEncode(entry.columnWidths),
        );
      }
      if (entry.displayColumnWidths != null &&
          entry.displayColumnWidths!.isNotEmpty) {
        await prefs.setString(
          '$_displayWidthsPrefix${entry.server}|${entry.database}|${entry.table}',
          jsonEncode(entry.displayColumnWidths),
        );
      }
    }
  }

  /// 선택한 항목들로 기존 항목을 완전히 교체
  static Future<void> overwriteEntries(
      List<GlobalCellStructureEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in entries) {
      final key = '$_prefix${entry.server}|${entry.database}|${entry.table}';
      final encoded = jsonEncode(
          entry.structures.map((k, v) => MapEntry(k, v.toJson())));
      await prefs.setString(key, encoded);

      // 컬럼 폭 저장
      if (entry.columnWidths != null && entry.columnWidths!.isNotEmpty) {
        await prefs.setString(
          '$_widthsPrefix${entry.server}|${entry.database}|${entry.table}',
          jsonEncode(entry.columnWidths),
        );
      }
      if (entry.displayColumnWidths != null &&
          entry.displayColumnWidths!.isNotEmpty) {
        await prefs.setString(
          '$_displayWidthsPrefix${entry.server}|${entry.database}|${entry.table}',
          jsonEncode(entry.displayColumnWidths),
        );
      }
    }
  }
}
