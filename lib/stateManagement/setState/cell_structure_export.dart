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

/// 내보내기 파일 전체 구조 (metadata + structures)
class CellStructureExport {
  final CellStructureMetadata metadata;
  final Map<String, CellStructure> structures;

  const CellStructureExport({
    required this.metadata,
    required this.structures,
  });

  String toJsonString() {
    final map = {
      'metadata': metadata.toJson(),
      'structures': structures.map((k, v) => MapEntry(k, v.toJson())),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// JSON 파싱 — metadata 있는 새 포맷과 없는 구 포맷 모두 지원
  factory CellStructureExport.fromJson(
      Map<String, dynamic> json, String fallbackTable) {
    if (json.containsKey('structures') && json.containsKey('metadata')) {
      // 새 포맷
      final meta =
          CellStructureMetadata.fromJson(json['metadata'] as Map<String, dynamic>);
      final structs = (json['structures'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, CellStructure.fromJson(v as Map<String, dynamic>)),
      );
      return CellStructureExport(metadata: meta, structures: structs);
    } else {
      // 구 포맷 — 최상위가 바로 structures
      final structs = json.map(
        (k, v) => MapEntry(k, CellStructure.fromJson(v as Map<String, dynamic>)),
      );
      return CellStructureExport(
        metadata: CellStructureMetadata(
          name: '가져온 구조',
          createdAt: '',
          table: fallbackTable,
        ),
        structures: structs,
      );
    }
  }
}
