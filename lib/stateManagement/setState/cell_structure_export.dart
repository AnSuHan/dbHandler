// lib/stateManagement/setState/cell_structure_export.dart
import 'dart:convert';
import 'cell_structure.dart';

/// 셀 구조 내보내기 파일의 메타데이터
class CellStructureMetadata {
  final String name;
  final String description;
  final String version;
  final String createdAt;
  final String table;

  const CellStructureMetadata({
    required this.name,
    this.description = '',
    this.version = '1.0',
    required this.createdAt,
    required this.table,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description.isNotEmpty) 'description': description,
        'version': version,
        'createdAt': createdAt,
        'table': table,
      };

  factory CellStructureMetadata.fromJson(Map<String, dynamic> j) =>
      CellStructureMetadata(
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        version: j['version'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
        table: j['table'] as String? ?? '',
      );
}

/// 내보내기 파일 전체 구조 (metadata + structures + 레이아웃 설정)
class CellStructureExport {
  final CellStructureMetadata metadata;
  final Map<String, CellStructure> structures;
  /// 일반모드 컬럼 폭 비율 목록
  final List<double>? columnWidths;
  /// 구조모드 컬럼 폭 비율 목록
  final List<double>? displayColumnWidths;
  /// 컬럼 표시 순서
  final List<String>? columnOrder;
  /// 저장된 필터 조건 목록
  final List<Map<String, dynamic>>? filters;
  /// 저장된 정렬 조건 목록
  final List<Map<String, dynamic>>? sorts;
  /// 저장된 그룹 기준 컬럼 목록
  final List<String>? groupByColumns;

  const CellStructureExport({
    required this.metadata,
    required this.structures,
    this.columnWidths,
    this.displayColumnWidths,
    this.columnOrder,
    this.filters,
    this.sorts,
    this.groupByColumns,
  });

  String toJsonString() {
    final map = <String, dynamic>{
      'metadata': metadata.toJson(),
      'structures': structures.map((k, v) => MapEntry(k, v.toJson())),
    };
    if (columnWidths != null && columnWidths!.isNotEmpty) {
      map['columnWidths'] = columnWidths;
    }
    if (displayColumnWidths != null && displayColumnWidths!.isNotEmpty) {
      map['displayColumnWidths'] = displayColumnWidths;
    }
    if (columnOrder != null && columnOrder!.isNotEmpty) {
      map['columnOrder'] = columnOrder;
    }
    if (filters != null && filters!.isNotEmpty) {
      map['filters'] = filters;
    }
    if (sorts != null && sorts!.isNotEmpty) {
      map['sorts'] = sorts;
    }
    if (groupByColumns != null && groupByColumns!.isNotEmpty) {
      map['groupByColumns'] = groupByColumns;
    }
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// JSON 파싱 — metadata 있는 새 포맷과 없는 구 포맷 모두 지원
  factory CellStructureExport.fromJson(
      Map<String, dynamic> json, String fallbackTable) {
    Map<String, CellStructure> structs;
    CellStructureMetadata meta;

    if (json.containsKey('structures') && json.containsKey('metadata')) {
      // 새 포맷
      meta = CellStructureMetadata.fromJson(
          json['metadata'] as Map<String, dynamic>);
      structs = (json['structures'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, CellStructure.fromJson(v as Map<String, dynamic>)),
      );
    } else {
      // 구 포맷 — 최상위가 바로 structures
      structs = json.map(
        (k, v) => MapEntry(k, CellStructure.fromJson(v as Map<String, dynamic>)),
      );
      meta = CellStructureMetadata(
        name: '가져온 구조',
        createdAt: '',
        table: fallbackTable,
      );
    }

    return CellStructureExport(
      metadata: meta,
      structures: structs,
      columnWidths: _parseDoubleList(json['columnWidths']),
      displayColumnWidths: _parseDoubleList(json['displayColumnWidths']),
      columnOrder: _parseStringList(json['columnOrder']),
      filters: _parseMapList(json['filters']),
      sorts: _parseMapList(json['sorts']),
      groupByColumns: _parseStringList(json['groupByColumns']),
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

  static List<String>? _parseStringList(dynamic raw) {
    if (raw == null) return null;
    try {
      return (raw as List).map((e) => e as String).toList();
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>>? _parseMapList(dynamic raw) {
    if (raw == null) return null;
    try {
      return (raw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 레이아웃 설정(컬럼 폭, 필터 등)이 하나라도 포함되어 있는지 여부
  bool get hasLayoutData =>
      (columnWidths?.isNotEmpty ?? false) ||
      (displayColumnWidths?.isNotEmpty ?? false) ||
      (filters?.isNotEmpty ?? false) ||
      (sorts?.isNotEmpty ?? false) ||
      (groupByColumns?.isNotEmpty ?? false);
}
