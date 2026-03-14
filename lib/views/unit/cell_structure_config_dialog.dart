// lib/views/unit/cell_structure_config_dialog.dart
import 'package:flutter/material.dart';
import '../../stateManagement/setState/cell_structure.dart';

/// 셀 구조 설정 다이얼로그
/// - 메인 컬럼에 표시할 줄(접두사 + 컬럼)을 편집
Future<CellStructure?> showCellStructureConfigDialog({
  required BuildContext context,
  required String mainColumnName,
  required List<String> availableColumns,
  CellStructure? existing,
}) {
  return showDialog<CellStructure>(
    context: context,
    builder: (ctx) => _CellStructureConfigDialog(
      mainColumnName: mainColumnName,
      availableColumns: availableColumns,
      existing: existing,
    ),
  );
}

class _CellStructureConfigDialog extends StatefulWidget {
  final String mainColumnName;
  final List<String> availableColumns;
  final CellStructure? existing;

  const _CellStructureConfigDialog({
    required this.mainColumnName,
    required this.availableColumns,
    this.existing,
  });

  @override
  State<_CellStructureConfigDialog> createState() =>
      _CellStructureConfigDialogState();
}

class _CellStructureConfigDialogState
    extends State<_CellStructureConfigDialog> {
  late List<_LineEntry> _lines;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _lines = widget.existing!.lines
          .map((l) => _LineEntry(
                prefixController: TextEditingController(text: l.prefix),
                columnName: l.columnName,
              ))
          .toList();
    } else {
      // 기본값: 메인 컬럼 하나만
      _lines = [
        _LineEntry(
          prefixController: TextEditingController(),
          columnName: widget.mainColumnName,
        )
      ];
    }
  }

  @override
  void dispose() {
    for (final e in _lines) {
      e.prefixController.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() {
      _lines.add(_LineEntry(
        prefixController: TextEditingController(),
        columnName: widget.availableColumns.first,
      ));
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].prefixController.dispose();
      _lines.removeAt(index);
    });
  }

  CellStructure _build() {
    return CellStructure(
      mainColumnName: widget.mainColumnName,
      lines: _lines
          .map((e) => CellStructureLine(
                prefix: e.prefixController.text,
                columnName: e.columnName,
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('셀 구조 설정 - ${widget.mainColumnName}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '각 줄마다 접두사와 컬럼을 지정합니다.\n'
              '흡수된 컬럼(메인 컬럼 외)은 테이블에서 숨겨집니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _lines.removeAt(oldIndex);
                  _lines.insert(newIndex, item);
                });
              },
              children: _lines.asMap().entries.map((entry) {
                final i = entry.key;
                final line = entry.value;
                return Padding(
                  key: ValueKey('line_$i'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: line.prefixController,
                          decoration: const InputDecoration(
                            labelText: '접두사',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: widget.availableColumns.contains(line.columnName)
                              ? line.columnName
                              : widget.availableColumns.first,
                          items: widget.availableColumns
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => line.columnName = v);
                            }
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red, size: 20),
                        onPressed: _lines.length > 1
                            ? () => _removeLine(i)
                            : null,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add),
              label: const Text('줄 추가'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _build()),
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _LineEntry {
  TextEditingController prefixController;
  String columnName;

  _LineEntry({required this.prefixController, required this.columnName});
}
