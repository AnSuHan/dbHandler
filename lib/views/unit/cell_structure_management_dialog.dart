// lib/views/unit/cell_structure_management_dialog.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../stateManagement/setState/cell_structure.dart';
import '../../stateManagement/setState/data_editing_riverpod.dart';
import 'cell_structure_config_dialog.dart';
import 'cell_structure_from_string_dialog.dart';

Future<void> showCellStructureManagementDialog({
  required BuildContext context,
  required DataEditingParams dataEditingParams,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => _CellStructureManagementDialog(
      dataEditingParams: dataEditingParams,
    ),
  );
}

class _CellStructureManagementDialog extends ConsumerStatefulWidget {
  final DataEditingParams dataEditingParams;

  const _CellStructureManagementDialog({required this.dataEditingParams});

  @override
  ConsumerState<_CellStructureManagementDialog> createState() =>
      _CellStructureManagementDialogState();
}

class _CellStructureManagementDialogState
    extends ConsumerState<_CellStructureManagementDialog> {
  String? _selectedNewColumn;

  @override
  Widget build(BuildContext context) {
    final cellStructures = ref.watch(
      dataEditingProvider(widget.dataEditingParams)
          .select((s) => s.cellStructures),
    );
    final columns = ref.watch(
      dataEditingProvider(widget.dataEditingParams)
          .select((s) => s.columns),
    );
    final notifier =
        ref.read(dataEditingProvider(widget.dataEditingParams).notifier);
    final availableColumns = columns.map((c) => c['name']!).toList();

    // 아직 구조가 없는 컬럼만 새로 추가 가능
    final unstructuredColumns = availableColumns
        .where((c) => !cellStructures.containsKey(c))
        .toList();

    // 선택된 컬럼이 목록에 없으면 초기화
    if (_selectedNewColumn != null &&
        !unstructuredColumns.contains(_selectedNewColumn)) {
      _selectedNewColumn = null;
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.view_agenda_outlined),
          SizedBox(width: 8),
          Text('셀 구조 관리'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 새 구조 추가 영역
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('새 구조 추가',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (unstructuredColumns.isEmpty)
                    const Text('모든 컬럼에 구조가 설정되어 있습니다.',
                        style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedNewColumn,
                          hint: const Text('메인 컬럼 선택'),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          items: unstructuredColumns
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedNewColumn = v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _selectedNewColumn == null
                                    ? null
                                    : () => _createNew(
                                        context, notifier, _selectedNewColumn!,
                                        availableColumns),
                                icon: const Icon(Icons.tune, size: 16),
                                label: const Text('수동 설정'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _selectedNewColumn == null
                                    ? null
                                    : () => _createFromString(
                                        context, notifier, _selectedNewColumn!,
                                        availableColumns),
                                icon: const Icon(Icons.auto_fix_high, size: 16),
                                label: const Text('문자열로 정의'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 내보내기 / 가져오기 / 전체 삭제 버튼
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _export(context, cellStructures),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('내보내기'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _import(context, notifier, availableColumns),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('가져오기'),
                ),
                const Spacer(),
                if (cellStructures.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        _confirmClearAll(context, notifier, cellStructures),
                    icon: const Icon(Icons.delete_sweep,
                        size: 18, color: Colors.red),
                    label: const Text('전체 삭제',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            const Divider(height: 20),
            if (cellStructures.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '설정된 셀 구조가 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView(
                  shrinkWrap: true,
                  children: cellStructures.entries.map((entry) {
                    final mainCol = entry.key;
                    final structure = entry.value;
                    final absorbed = structure.absorbedColumns;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.table_chart, size: 16, color: Colors.blue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    mainCol,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: '수동 편집',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    final result = await showCellStructureConfigDialog(
                                      context: context,
                                      mainColumnName: mainCol,
                                      availableColumns: availableColumns,
                                      existing: structure,
                                    );
                                    if (result != null) {
                                      notifier.setCellStructure(mainCol, result);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.auto_fix_high, size: 18),
                                  tooltip: '문자열로 재정의',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    final result = await showCellStructureFromStringDialog(
                                      context: context,
                                      availableColumns: availableColumns,
                                      initialMainColumn: mainCol,
                                    );
                                    if (result != null) {
                                      notifier.setCellStructure(result.mainColumnName, result);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  tooltip: '삭제',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmDelete(context, notifier, mainCol),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 구조 미리보기
                            ...structure.lines.asMap().entries.map((e) {
                              final line = e.value;
                              final label = line.prefix.isEmpty
                                  ? line.columnName
                                  : '"${line.prefix}" + ${line.columnName}';
                              return Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  ],
                                ),
                              );
                            }),
                            if (absorbed.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: absorbed.map((c) => Chip(
                                  label: Text(c, style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.orange.shade50,
                                  side: BorderSide(color: Colors.orange.shade200),
                                  avatar: const Icon(Icons.visibility_off, size: 12),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Future<void> _createNew(
    BuildContext context,
    DataEditingNotifier notifier,
    String mainColumnName,
    List<String> availableColumns,
  ) async {
    final result = await showCellStructureConfigDialog(
      context: context,
      mainColumnName: mainColumnName,
      availableColumns: availableColumns,
    );
    if (result != null) {
      notifier.setCellStructure(mainColumnName, result);
      setState(() => _selectedNewColumn = null);
    }
  }

  Future<void> _createFromString(
    BuildContext context,
    DataEditingNotifier notifier,
    String mainColumnName,
    List<String> availableColumns,
  ) async {
    final result = await showCellStructureFromStringDialog(
      context: context,
      availableColumns: availableColumns,
      initialMainColumn: mainColumnName,
    );
    if (result != null) {
      notifier.setCellStructure(result.mainColumnName, result);
      setState(() => _selectedNewColumn = null);
    }
  }

  Future<void> _export(
      BuildContext context, Map<String, CellStructure> structures) async {
    if (structures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보낼 구조가 없습니다.')),
      );
      return;
    }

    final jsonStr = const JsonEncoder.withIndent('  ')
        .convert(structures.map((k, v) => MapEntry(k, v.toJson())));

    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '셀 구조 내보내기',
        fileName: 'cell_structures_${widget.dataEditingParams.table}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return;
      await File(path).writeAsString(jsonStr, encoding: utf8);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장됨: $path'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _import(
    BuildContext context,
    DataEditingNotifier notifier,
    List<String> availableColumns,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '셀 구조 가져오기',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;

      final content = await File(result.files.single.path!).readAsString(encoding: utf8);
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final imported = decoded.map((k, v) =>
          MapEntry(k, CellStructure.fromJson(v as Map<String, dynamic>)));

      // 컬럼 유효성 확인
      final unknownCols = <String>{};
      for (final s in imported.values) {
        for (final line in s.lines) {
          if (!availableColumns.contains(line.columnName)) {
            unknownCols.add(line.columnName);
          }
        }
      }

      if (unknownCols.isNotEmpty && context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('경고'),
            content: Text(
              '다음 컬럼이 현재 테이블에 없습니다:\n${unknownCols.join(', ')}\n\n계속 가져오시겠습니까?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('계속'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      notifier.importCellStructures(imported);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${imported.length}개 구조를 가져왔습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가져오기 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(
      BuildContext context, DataEditingNotifier notifier, String columnName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구조 삭제'),
        content: Text('"$columnName" 컬럼의 셀 구조를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.removeCellStructure(columnName);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(
    BuildContext context,
    DataEditingNotifier notifier,
    Map<String, CellStructure> structures,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 삭제'),
        content: Text('${structures.length}개 구조를 모두 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              for (final key in structures.keys.toList()) {
                notifier.removeCellStructure(key);
              }
            },
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );
  }
}
