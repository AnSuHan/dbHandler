import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/LocalizationManager.dart';
import '../../stateManagement/setState/data_editing_riverpod.dart';

/// 개별 데이터 셀 위젯
/// Riverpod의 select를 사용하여 해당 셀의 값만 정밀하게 구독
/// 다른 셀이 변경되어도 이 셀은 리빌드되지 않습니다.
class EditableDataCell extends ConsumerWidget {
  final int rowIndex;
  final int colIndex;
  final String columnName;
  final DataEditingParams dataEditingParams;
  final double columnWidth;

  const EditableDataCell({
    super.key,
    required this.rowIndex,
    required this.colIndex,
    required this.columnName,
    required this.dataEditingParams,
    required this.columnWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod의 select를 사용하여 특정 셀 값만 선택적으로 구독
    // 이 셀의 값이 변경될 때만 리빌드됩니다 (ValueNotifier와 유사한 동작)
    final cellValue = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) {
          if (rowIndex >= state.rows.length) return null;
          if (colIndex >= state.columns.length) return null;
          final colName = state.columns[colIndex]['name']!;
          final row = state.rows[rowIndex];
          return row[colName];
        },
      ),
    );

    // 셀 선택 상태만 선택적으로 구독 (다중 셀 선택 범위 포함)
    final isCellSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.isCellInRange(rowIndex, colIndex),
      ),
    );

    // 열 선택 상태만 선택적으로 구독
    final isColSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedColumnIndex == colIndex,
      ),
    );

    // 행 선택 상태만 선택적으로 구독
    final isRowSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedRowIndex == rowIndex,
      ),
    );

    // notifier는 read만 사용 (리빌드 트리거하지 않음)
    final notifier = ref.read(dataEditingProvider(dataEditingParams).notifier);

    // 셀 배경색 결정
    Color? cellColor;
    if (isCellSelected) {
      cellColor = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3);
    } else if (isRowSelected || isColSelected) {
      cellColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
    }

    // 드래그 상태 추적을 위한 전역 변수 대신, 각 셀에서 마우스 이벤트 처리
    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse) {
          final keys = HardwareKeyboard.instance.logicalKeysPressed;
          final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
              keys.contains(LogicalKeyboardKey.shiftRight);
          if (isShift) {
            notifier.updateCellSelection(rowIndex, colIndex);
          } else {
            notifier.startCellSelection(rowIndex, colIndex);
          }
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final keys = HardwareKeyboard.instance.logicalKeysPressed;
          final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
              keys.contains(LogicalKeyboardKey.shiftRight);
          if (isShift) {
            notifier.updateCellSelection(rowIndex, colIndex);
          } else {
            notifier.selectCell(rowIndex, colIndex);
          }
        },
        onDoubleTap: () {
          notifier.selectCell(rowIndex, colIndex);
          // 다음 프레임에서 다이얼로그 표시 (상태 업데이트 후)
          Future.microtask(() {
            final state = ref.read(dataEditingProvider(dataEditingParams));
            if (rowIndex < state.rows.length) {
              final currentRowData = state.rows[rowIndex];
              _showEditCellDialog(context, ref, currentRowData, columnName, state, notifier, colIndex);
            }
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (event) {
            // 마우스가 셀 위에 들어올 때, 버튼이 눌려있으면 범위 선택 업데이트
            if (event.buttons == kPrimaryButton) {
              final state = ref.read(dataEditingProvider(dataEditingParams));
              // 선택이 시작되었으면 범위 업데이트
              if (state.selectedCellRange != null || state.selectedCell != null) {
                notifier.updateCellSelection(rowIndex, colIndex);
              }
            }
          },
          child: Container(
            width: columnWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cellColor,
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
            ),
            child: Text(
              cellValue?.toString() ?? 'NULL',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  /// 셀 편집 다이얼로그 표시
  void _showEditCellDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> rowData,
    String columnName,
    DataEditingState state,
    DataEditingNotifier notifier,
    int targetColIndex,
  ) async {
    if (state.primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(intl.getString((i) => i.cannotEditCellPK)),
          backgroundColor: Colors.red));
      return;
    }

    final pkValue = rowData[state.primaryKeyColumn!];
    final currentValue = rowData[columnName];
    final controller = TextEditingController(text: currentValue?.toString() ?? '');

    // 행 인덱스 찾기 (부분 리빌드를 위해 필요)
    int? targetRowIndex;
    for (int i = 0; i < state.rows.length; i++) {
      if (state.rows[i][state.primaryKeyColumn!] == pkValue) {
        targetRowIndex = i;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${intl.getString((i) => i.editCell)}: $columnName'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((i) => i.cancel)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final newValue = controller.text.trim();
              final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                server: dataEditingParams.server,
                database: dataEditingParams.database,
              )));

              try {
                // DB 업데이트
                if (dataEditingParams.joinDefinition != null) {
                  final meta = state.joinColumnMeta[columnName];
                  if (meta == null) throw Exception('컬럼 메타 정보 없음: $columnName');
                  await dbHandler.updateJoinedCell(
                    meta['sourceTable']!,
                    meta['sourceColumn']!,
                    newValue.isEmpty ? null : newValue,
                    state.primaryKeyColumn!,
                    pkValue,
                  );
                } else {
                  await dbHandler.updateCell(
                    dataEditingParams.table,
                    columnName,
                    newValue.isEmpty ? null : newValue,
                    state.primaryKeyColumn!,
                    pkValue,
                  );
                }
                
                // 셀 값만 업데이트 (최소 단위 리빌드)
                if (targetRowIndex != null && targetColIndex < state.columns.length) {
                  await notifier.updateCellValue(
                    targetRowIndex,
                    targetColIndex,
                    columnName,
                    newValue.isEmpty ? null : newValue,
                  );
                } else {
                  // 행을 찾을 수 없으면 전체 데이터 로드
                  await notifier.loadTableData();
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(intl.getString((l) => l.updateCellSuccess)), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${intl.getString((l) => l.operationFailed)}: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(intl.getString((l) => l.save)),
          ),
        ],
      ),
    );
  }
}