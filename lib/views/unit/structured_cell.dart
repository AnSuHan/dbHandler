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

    // 표시용 텍스트 계산 (수식 포함)
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
        alignment: Alignment.topLeft,
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

    // 편집 가능한 컬럼 목록 (수식 참조 컬럼 포함, 중복 제거, 등장 순서 유지)
    final editableCols = structure.editableColumns;

    // 컬럼별 컨트롤러
    final controllers = {
      for (final col in editableCols)
        col: TextEditingController(text: rowData[col]?.toString() ?? ''),
    };

    // 수식 줄 인덱스 (읽기 전용 표시용)
    final exprLines = structure.lines.where((l) => l.isExpression).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          // 현재 컨트롤러 값으로 임시 rowData 구성해 수식 미리보기
          final previewRow = Map<String, dynamic>.from(rowData);
          for (final col in editableCols) {
            final txt = controllers[col]!.text.trim();
            previewRow[col] = txt.isEmpty ? null : num.tryParse(txt) ?? txt;
          }

          return AlertDialog(
            title: Text('셀 편집 — ${structure.effectiveDisplayName}'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 편집 가능한 컬럼 필드 ──────────────────
                    ...editableCols.map((col) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: controllers[col],
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true, signed: true),
                            onChanged: (_) => setDlgState(() {}),
                            decoration: InputDecoration(
                              labelText: col,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        )),
                    // ── 수식 줄 미리보기 (읽기 전용) ─────────────
                    if (exprLines.isNotEmpty) ...[
                      const Divider(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.functions,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text('계산 결과',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                      ),
                      ...exprLines.map((line) {
                        String computed;
                        try {
                          // 임시 row로 수식 실시간 계산
                          final tempStructure = CellStructure(
                            mainColumnName: structure.mainColumnName,
                            lines: [line],
                          );
                          computed = tempStructure.format(previewRow);
                        } catch (_) {
                          computed = '?';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                line.prefix.isEmpty
                                    ? line.expression!
                                    : '${line.prefix}${line.expression}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                computed,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
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
                  final updates = <Map<String, dynamic>>[];
                  for (final col in editableCols) {
                    final newVal = controllers[col]!.text.trim();
                    final newValue = newVal.isEmpty ? null : newVal;
                    final oldValue = rowData[col];
                    if (oldValue?.toString() != newValue?.toString()) {
                      final colIdx = state.columns
                          .indexWhere((c) => c['name'] == col);
                      if (colIdx >= 0) {
                        try {
                          await dbHandler.updateCell(
                            dataEditingParams.table,
                            col,
                            newValue,
                            pkCol,
                            pkValue,
                          );
                          updates.add({
                            'rowIndex': rowIndex,
                            'colIndex': colIdx,
                            'columnName': col,
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
          );
        },
      ),
    ).whenComplete(() {
      for (final c in controllers.values) c.dispose();
    });
  }
}
