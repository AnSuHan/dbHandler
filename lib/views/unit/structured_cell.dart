// lib/views/unit/structured_cell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stateManagement/setState/cell_structure.dart';
import '../../stateManagement/setState/data_editing_riverpod.dart';

/// 구조화된 셀 위젯
/// 여러 컬럼 값을 한 셀에 표시 (표시 모드)
class StructuredDataCell extends ConsumerWidget {
  final int rowIndex;
  final int colIndex;
  final String columnName;
  final CellStructure structure;
  final DataEditingParams dataEditingParams;
  final double columnWidth;

  const StructuredDataCell({
    super.key,
    required this.rowIndex,
    required this.colIndex,
    required this.columnName,
    required this.structure,
    required this.dataEditingParams,
    required this.columnWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCellSelected = ref.watch(
      dataEditingProvider(dataEditingParams)
          .select((state) => state.isCellInRange(rowIndex, colIndex)),
    );
    final isRowSelected = ref.watch(
      dataEditingProvider(dataEditingParams)
          .select((state) => state.selectedRowIndex == rowIndex),
    );

    // 표시용 텍스트 계산
    final displayText = ref.watch(
      dataEditingProvider(dataEditingParams).select((state) {
        if (rowIndex >= state.rows.length) return '';
        return structure.format(state.rows[rowIndex]);
      }),
    );

    final notifier = ref.read(dataEditingProvider(dataEditingParams).notifier);

    Color? cellColor;
    if (isCellSelected) {
      cellColor =
          Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3);
    } else if (isRowSelected) {
      cellColor =
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
    }

    return GestureDetector(
      onTap: () => notifier.selectCell(rowIndex, colIndex),
      onDoubleTap: () {
        notifier.selectCell(rowIndex, colIndex);
        Future.microtask(() {
          final state = ref.read(dataEditingProvider(dataEditingParams));
          if (rowIndex < state.rows.length) {
            _showEditStructuredCellDialog(context, ref, state, notifier);
          }
        });
      },
      child: Container(
        width: columnWidth,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: cellColor,
          border: Border(
            right: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
          ),
        ),
        child: Text(
          displayText,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
          maxLines: structure.lines.length,
        ),
      ),
    );
  }

  void _showEditStructuredCellDialog(
    BuildContext context,
    WidgetRef ref,
    DataEditingState state,
    DataEditingNotifier notifier,
  ) {
    if (state.primaryKeyColumn == null) return;
    final rowData = state.rows[rowIndex];
    final pkCol = state.primaryKeyColumn!;
    final pkValue = rowData[pkCol];

    // 각 줄별 TextEditingController 생성
    final controllers = structure.lines.map((line) {
      final val = rowData[line.columnName]?.toString() ?? '';
      return TextEditingController(text: val);
    }).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('셀 편집'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: structure.lines.asMap().entries.map((entry) {
              final i = entry.key;
              final line = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                  controller: controllers[i],
                  decoration: InputDecoration(
                    labelText: line.prefix.isEmpty
                        ? line.columnName
                        : '${line.prefix}${line.columnName}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final dbHandler = ref.read(databaseHandlerProvider(
                  DatabaseHandlerParams(
                      server: dataEditingParams.server,
                      database: dataEditingParams.database)));
              // 각 컬럼 업데이트
              final updates = <Map<String, dynamic>>[];
              for (int i = 0; i < structure.lines.length; i++) {
                final line = structure.lines[i];
                final newVal = controllers[i].text.trim();
                final newValue = newVal.isEmpty ? null : newVal;
                final oldValue = rowData[line.columnName];
                if (oldValue?.toString() != newValue?.toString()) {
                  final colIdx = state.columns
                      .indexWhere((c) => c['name'] == line.columnName);
                  if (colIdx >= 0) {
                    try {
                      await dbHandler.updateCell(
                        dataEditingParams.table,
                        line.columnName,
                        newValue,
                        pkCol,
                        pkValue,
                      );
                      updates.add({
                        'rowIndex': rowIndex,
                        'colIndex': colIdx,
                        'columnName': line.columnName,
                        'newValue': newValue,
                      });
                    } catch (_) {}
                  }
                }
              }
              if (updates.isNotEmpty) {
                await notifier.updateMultipleCellValues(updates);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ).whenComplete(() {
      for (final c in controllers) {
        c.dispose();
      }
    });
  }
}
