import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/LocalizationManager.dart';
import '../sqflite/models/server_model.dart';
import '../sqflite/platform_check.dart';
import '../stateManagement/setState/data_editing_riverpod.dart';
import '../stateManagement/setState/join_definition.dart';
import 'unit/cell_structure_management_dialog.dart';
import 'unit/data_cell.dart';
import 'unit/filter_sort_group_panel.dart';
import 'unit/structured_cell.dart';

class CopyIntent extends Intent {}

class PasteIntent extends Intent {}

/// Riverpod 상태 관리
class DataEditingScreen extends ConsumerStatefulWidget {
  final ServerModel server;
  final String database;
  final String table;
  final JoinDefinition? joinDefinition;

  const DataEditingScreen({
    super.key,
    required this.server,
    required this.database,
    required this.table,
    this.joinDefinition,
  });

  @override
  ConsumerState<DataEditingScreen> createState() => _DataEditingScreenState();
}

class _DataEditingScreenState extends ConsumerState<DataEditingScreen> {
  final FocusNode _focusNode = FocusNode();
  late final ScrollController _horizontalHeadController;
  late final ScrollController _horizontalBodyController;

  @override
  void initState() {
    super.initState();
    _horizontalHeadController = ScrollController();
    _horizontalBodyController = ScrollController();
    _syncScroll();
  }

  void _syncScroll() {
    _horizontalHeadController.addListener(() {
      if (_horizontalBodyController.hasClients &&
          _horizontalBodyController.offset != _horizontalHeadController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeadController.offset);
      }
    });
    _horizontalBodyController.addListener(() {
      if (_horizontalHeadController.hasClients &&
          _horizontalHeadController.offset != _horizontalBodyController.offset) {
        _horizontalHeadController.jumpTo(_horizontalBodyController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeadController.dispose();
    _horizontalBodyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performOperation(
    Future<void> Function() operation,
    String successMessage, {
    int? updatedRowIndex,
  }) async {
    if (!mounted) return;
    final notifier = ref.read(dataEditingProvider(DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
      joinDefinition: widget.joinDefinition,
    )).notifier);

    try {
      await notifier.performOperation(operation, updatedRowIndex: updatedRowIndex);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${intl.getString((l) => l.operationFailed)}: $e', maxLines: 3, overflow: TextOverflow.ellipsis), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyCell() {
    final dataEditingParams = DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
      joinDefinition: widget.joinDefinition,
    );
    final state = ref.read(dataEditingProvider(dataEditingParams));
    
    final selectedKeys = state.getSelectedCellKeys();
    if (selectedKeys.isEmpty) return;

    // 선택된 셀들의 범위 계산 (사각형 범위)
    int? minRow, maxRow, minCol, maxCol;
    
    for (final key in selectedKeys) {
      final parts = key.split('_');
      if (parts.length != 2) continue;
      
      final rowIndex = int.tryParse(parts[0]);
      final colIndex = int.tryParse(parts[1]);
      
      if (rowIndex == null || colIndex == null) continue;
      
      // 범위 업데이트
      minRow = minRow == null ? rowIndex : (minRow < rowIndex ? minRow : rowIndex);
      maxRow = maxRow == null ? rowIndex : (maxRow > rowIndex ? maxRow : rowIndex);
      minCol = minCol == null ? colIndex : (minCol < colIndex ? minCol : colIndex);
      maxCol = maxCol == null ? colIndex : (maxCol > colIndex ? maxCol : colIndex);
    }
    
    // 범위가 없으면 종료
    if (minRow == null || maxRow == null || minCol == null || maxCol == null) {
      return;
    }
    
    // TSV 형식으로 데이터 생성 (사각형 범위의 모든 셀 포함)
    final buffer = StringBuffer();
    for (int row = minRow; row <= maxRow; row++) {
      final rowData = <String>[];
      for (int col = minCol; col <= maxCol; col++) {
        final key = '${row}_$col';
        // 선택된 셀이고 유효한 범위 내에 있으면 값 복사, 아니면 빈 문자열
        if (selectedKeys.contains(key) && 
            row < state.rows.length && 
            col < state.columns.length) {
          final value = state.rows[row][state.columns[col]['name']!];
          rowData.add(value?.toString() ?? '');
        } else {
          rowData.add('');
        }
      }
      buffer.writeln(rowData.join('\t'));
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));

    final cellCount = selectedKeys.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(intl.getStringWithParams((l, cellCount) => l.cellCopied(cellCount), cellCount)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _pasteCell() async {
    final dataEditingParams = DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
      joinDefinition: widget.joinDefinition,
    );
    final state = ref.read(dataEditingProvider(dataEditingParams));
    final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
      server: widget.server,
      database: widget.database,
    )));

    // 선택된 셀이 없으면 종료
    if (state.selectedCell == null && state.selectedCellRange == null) return;
    if (state.primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(intl.getString((l) => l.cannotPastePk)), backgroundColor: Colors.red));
      return;
    }

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text;

    if (clipboardText == null || clipboardText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(intl.getString((l) => l.cannotPasteNothing)), backgroundColor: Colors.orange));
      return;
    }

    // TSV 형식 파싱 (탭으로 구분된 값)
    final normalizedText = clipboardText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalizedText.split('\n').where((l) => l.trim().isNotEmpty || l.contains('\t')).toList();
    if (lines.isEmpty) return;

    final pasteData = lines.map((line) => line.isEmpty ? <String>[] : line.split('\t'))
        .where((row) => row.isNotEmpty)
        .toList();
    if (pasteData.isEmpty) return;

    final topLeftCell = state.getTopLeftSelectedCell();
    if (topLeftCell == null) return;

    final startRowIndex = topLeftCell['rowIndex']!;
    final startColIndex = topLeftCell['colIndex']!;
    final notifier = ref.read(dataEditingProvider(dataEditingParams).notifier);

    // 선택된 범위 계산
    final selectedKeys = state.getSelectedCellKeys();
    int? minRow, maxRow, minCol, maxCol;

    for (final key in selectedKeys) {
      final parts = key.split('_');
      if (parts.length != 2) continue;

      final rowIndex = int.tryParse(parts[0]);
      final colIndex = int.tryParse(parts[1]);

      if (rowIndex == null || colIndex == null) continue;

      minRow = minRow == null ? rowIndex : (minRow < rowIndex ? minRow : rowIndex);
      maxRow = maxRow == null ? rowIndex : (maxRow > rowIndex ? maxRow : rowIndex);
      minCol = minCol == null ? colIndex : (minCol < colIndex ? minCol : colIndex);
      maxCol = maxCol == null ? colIndex : (maxCol > colIndex ? maxCol : colIndex);
    }

    // 복사된 데이터가 1x1인지 확인
    final isSingleCellCopy = pasteData.length == 1 && pasteData[0].length == 1;
    final singleValue = isSingleCellCopy ? pasteData[0][0] : null;

    int successCount = 0;
    int failCount = 0;
    final cellUpdates = <Map<String, dynamic>>[];

    try {
      try {
        await dbHandler.runInTransaction(() async {
          if (isSingleCellCopy && minRow != null && maxRow != null && minCol != null && maxCol != null) {
            // 케이스 1: 1개 셀 복사 -> m*n 범위에 모두 동일한 값 붙여넣기
            for (int rowIdx = minRow; rowIdx <= maxRow; rowIdx++) {
              if (rowIdx >= state.rows.length) break;

              final pkValue = state.rows[rowIdx][state.primaryKeyColumn!];

              for (int colIdx = minCol; colIdx <= maxCol; colIdx++) {
                if (colIdx >= state.columns.length) break;

                final trimmedValue = singleValue!.trim();
                final newValue = trimmedValue.isEmpty ? null : trimmedValue;
                final targetColumnName = state.columns[colIdx]['name']!;
                final oldValue = state.rows[rowIdx][targetColumnName];
                final isValueChanged = oldValue != newValue;

                if (isValueChanged) {
                  try {
                    await dbHandler.updateCell(
                      widget.table,
                      targetColumnName,
                      newValue,
                      state.primaryKeyColumn!,
                      pkValue,
                    );
                    cellUpdates.add({
                      'rowIndex': rowIdx,
                      'colIndex': colIdx,
                      'columnName': targetColumnName,
                      'newValue': newValue,
                    });
                    successCount++;
                  } catch (e) {
                    throw Exception('Failed to update cell at row $rowIdx, col $colIdx: $e');
                  }
                } else {
                  successCount++;
                }
              }
            }
          } else {
            // 케이스 2: m*n 복사 -> 기존 로직대로 붙여넣기
            for (int rowOffset = 0; rowOffset < pasteData.length; rowOffset++) {
              final targetRowIndex = startRowIndex + rowOffset;
              if (targetRowIndex >= state.rows.length) break;

              final rowData = pasteData[rowOffset];
              if (rowData.isEmpty) continue;

              final pkValue = state.rows[targetRowIndex][state.primaryKeyColumn!];

              for (int colOffset = 0; colOffset < rowData.length; colOffset++) {
                final targetColIndex = startColIndex + colOffset;
                if (targetColIndex >= state.columns.length) break;

                final cellValue = rowData[colOffset];
                final trimmedValue = cellValue.trim();
                final newValue = trimmedValue.isEmpty ? null : trimmedValue;
                final targetColumnName = state.columns[targetColIndex]['name']!;
                final oldValue = state.rows[targetRowIndex][targetColumnName];
                final isValueChanged = oldValue != newValue;

                if (isValueChanged) {
                  try {
                    await dbHandler.updateCell(
                      widget.table,
                      targetColumnName,
                      newValue,
                      state.primaryKeyColumn!,
                      pkValue,
                    );
                    cellUpdates.add({
                      'rowIndex': targetRowIndex,
                      'colIndex': targetColIndex,
                      'columnName': targetColumnName,
                      'newValue': newValue,
                    });
                    successCount++;
                  } catch (e) {
                    throw Exception('Failed to update cell at row $targetRowIndex, col $targetColIndex: $e');
                  }
                } else {
                  successCount++;
                }
              }
            }
          }
        });
      } catch (e) {
        failCount = isSingleCellCopy
            ? ((maxRow! - minRow! + 1) * (maxCol! - minCol! + 1))
            : (pasteData.length * (state.columns.length));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${intl.getStringWithParams((l, error) => l.transactionFailed(error), e)}: ${e.toString()}', maxLines: 3, overflow: TextOverflow.ellipsis), backgroundColor: Colors.red),
        );
        return;
      }

      // 2단계: 모든 셀을 한 번에 업데이트 (배치 업데이트로 리빌드 최소화)
      if (cellUpdates.isNotEmpty) {
        await notifier.updateMultipleCellValues(cellUpdates);
      }

      if (mounted) {
        if (failCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(intl.getStringWithParams((l, cellPaste) => l.cellPasteSuccess(cellPaste), successCount)),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(intl.getStringWithMultiParams(
                      (l, params) => l.cellPasteSuccessPartial(successCount, failCount), [successCount, failCount])),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(intl.getStringWithParams((l, error) => l.transactionFailed(error), e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataEditingParams = DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
      joinDefinition: widget.joinDefinition,
    );
    final notifier = ref.read(dataEditingProvider(dataEditingParams).notifier);
    final isJoinView = widget.joinDefinition != null;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyC): CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): PasteIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV): PasteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CopyIntent: CallbackAction<CopyIntent>(onInvoke: (intent) {
            _copyCell();
            return null;
          }),
          PasteIntent: CallbackAction<PasteIntent>(onInvoke: (intent) {
            _pasteCell();
            return null;
          }),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isJoinView) ...[
                    const Icon(Icons.join_inner, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      isJoinView
                          ? '${widget.joinDefinition!.name} - ${intl.getString((l) => l.dataEditing)}'
                          : '${widget.table} - ${intl.getString((l) => l.dataEditing)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              elevation: 0,
              actions: [
                Consumer(
                  builder: (context, ref, _) {
                    final isDisplayMode = ref.watch(
                      dataEditingProvider(dataEditingParams)
                          .select((s) => s.isDisplayMode),
                    );
                    final hasStructures = ref.watch(
                      dataEditingProvider(dataEditingParams)
                          .select((s) => s.cellStructures.isNotEmpty),
                    );
                    if (!hasStructures) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(isDisplayMode
                          ? Icons.table_rows_outlined
                          : Icons.view_agenda_outlined),
                      tooltip: isDisplayMode ? '일반 보기' : '구조 보기',
                      onPressed: () => notifier.toggleDisplayMode(),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: intl.getString((l) => l.refresh),
                  onPressed: () => notifier.loadTableData(),
                ),
                if (!isJoinView) ...[
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: intl.getString((l) => l.addRow),
                    onPressed: () => _showEditRowDialog(null, dataEditingParams),
                  ),
                ],
                if (!isJoinView)
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined),
                    tooltip: intl.getString((l) => l.addColumn),
                    onPressed: () => _showAddColumnDialog(dataEditingParams),
                  ),
                _AppBarMenu(dataEditingParams: dataEditingParams),
              ],
            ),
            body: Consumer(
              builder: (context, ref, child) {
                // 최소한의 상태만 watch (isLoading, error, columns.length)
                final isLoading = ref.watch(
                  dataEditingProvider(dataEditingParams).select((state) => state.isLoading),
                );
                final error = ref.watch(
                  dataEditingProvider(dataEditingParams).select((state) => state.error),
                );
                final columnsLength = ref.watch(
                  dataEditingProvider(dataEditingParams).select((state) => state.columns.length),
                );

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (error != null) {
                  return Center(child: Text(error, style: const TextStyle(color: Colors.red)));
                }
                if (columnsLength == 0) {
                  return Center(child: Text(intl.getString((l) => l.tableHasNoColumn)));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSortGroupPanel(dataEditingParams: dataEditingParams),
                    _TableHeader(
                      dataEditingParams: dataEditingParams,
                      horizontalHeadController: _horizontalHeadController,
                    ),
                    Expanded(
                      child: _buildBody(dataEditingParams),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DataEditingParams dataEditingParams) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          controller: _horizontalBodyController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Align(
            alignment: Alignment.topLeft,
            child: Consumer(
              builder: (context, ref, child) {
                // rows.length만 watch하여 행 추가/삭제 시에만 리빌드
                final rowsCount = ref.watch(
                  dataEditingProvider(dataEditingParams).select((state) => state.rows.length),
                );
                
                // columns와 columnWidths도 watch (구조 변경 시에만 리빌드)
                // final columns = ref.watch(
                //   dataEditingProvider(dataEditingParams).select((state) => state.columns),
                // );
                final columnWidths = ref.watch(
                  dataEditingProvider(dataEditingParams).select((state) => state.columnWidths),
                );
                
                return _TableBodyWidget(
                  rowsCount: rowsCount,
                  dataEditingParams: dataEditingParams,
                  columnWidths: columnWidths,
                );
              },
            ),
          ),
        ),
      ),
    );
  }



  void _showAddColumnDialog(DataEditingParams dataEditingParams) {
    final nameController = TextEditingController();
    String? selectedDataType;
    final List<Map<String, dynamic>> constraints = [];

    final List<String> dataTypes = [
      'VARCHAR(255)',
      'TEXT',
      'INTEGER',
      'BIGINT',
      'NUMERIC',
      'BOOLEAN',
      'DATE',
      'TIMESTAMP',
      'JSON',
      'JSONB'
    ];
    final List<String> commonConstraints = [
      'NOT NULL',
      'UNIQUE',
      'PRIMARY KEY',
      'DEFAULT',
      'CHECK',
      'REFERENCES'
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            void addConstraint(String type) {
              setStateInDialog(() {
                constraints.add({
                  'type': type,
                  'controller': TextEditingController(),
                });
              });
            }

            void removeConstraint(int index) {
              setStateInDialog(() {
                constraints[index]['controller'].dispose();
                constraints.removeAt(index);
              });
            }

            bool needsInput(String type) {
              return ['DEFAULT', 'CHECK', 'REFERENCES'].contains(type);
            }

            String getHintFor(String type) {
              switch (type) {
                case 'DEFAULT':
                  return 'Default value';
                case 'CHECK':
                  return 'Condition (e.g., price > 0)';
                case 'REFERENCES':
                  return 'Ref table(column)';
                default:
                  return '';
              }
            }

            String buildConstraintsString() {
              return constraints.map((c) {
                final type = c['type'] as String;
                if (needsInput(type)) {
                  final value = (c['controller'] as TextEditingController).text.trim();
                  if (type == 'CHECK') return 'CHECK ($value)';
                  return '$type $value';
                }
                return type;
              }).join(' ');
            }

            return AlertDialog(
              title: Text(intl.getString((l) => l.addNewColumn)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: intl.getString((l) => l.columnName), border: const OutlineInputBorder())),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDataType,
                      hint: Text(intl.getString((l) => l.selectDataType)),
                      items: dataTypes.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                      onChanged: (newValue) => setStateInDialog(() => selectedDataType = newValue),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(intl.getString((l) => l.constraints), style: const TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          hint: Text(intl.getString((l) => l.add)),
                          icon: const Icon(Icons.add_circle_outline),
                          items:
                              commonConstraints.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                          onChanged: (value) {
                            if (value != null && !constraints.any((c) => c['type'] == value)) {
                              addConstraint(value);
                            }
                          },
                        ),
                      ],
                    ),
                    ...constraints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final constraint = entry.value;
                      final type = constraint['type'] as String;
                      final controller = constraint['controller'] as TextEditingController;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            if (needsInput(type))
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: type,
                                    hintText: getHintFor(type),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              )
                            else
                              Expanded(child: Text(type)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => removeConstraint(index),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final columnName = nameController.text.trim();
                    if (columnName.isEmpty || selectedDataType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(intl.getString((l) => l.requiredAddingNewColumn)), backgroundColor: Colors.red));
                      return;
                    }
                    Navigator.pop(dialogContext);
                    final constraintsString = buildConstraintsString();
                    final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                      server: widget.server,
                      database: widget.database,
                    )));
                    _performOperation(
                      () => dbHandler.addColumn(widget.table, columnName, selectedDataType!, constraintsString),
                      intl.getString((l) => l.columnAddedSuccess),
                    );
                  },
                  child: Text(intl.getString((l) => l.add)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showModifyColumnDialog(Map<String, dynamic> columnData, DataEditingParams dataEditingParams) {
    final nameController = TextEditingController(text: columnData['name']);
    final List<String> dataTypes = [
      'VARCHAR(255)',
      'TEXT',
      'INTEGER',
      'BIGINT',
      'NUMERIC',
      'BOOLEAN',
      'DATE',
      'TIMESTAMP',
      'JSON',
      'JSONB'
    ];
    String? selectedDataType = columnData['type'] as String?;
    selectedDataType = (selectedDataType != null && dataTypes.contains(selectedDataType))
        ? selectedDataType
        : dataTypes.first;

    final List<Map<String, dynamic>> constraints = [];

    if (columnData['constraints'] != null) {
      for (var c in columnData['constraints'] as List<Map<String, dynamic>>) {
        constraints.add({
          'type': c['type'],
          'controller': TextEditingController(text: c['value'] ?? ''),
        });
      }
    }

    final List<String> commonConstraints = [
      'NOT NULL',
      'UNIQUE',
      'PRIMARY KEY',
      'DEFAULT',
      'CHECK',
      'REFERENCES'
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            void addConstraint(String type) {
              setStateInDialog(() {
                constraints.add({
                  'type': type,
                  'controller': TextEditingController(),
                });
              });
            }

            void removeConstraint(int index) {
              setStateInDialog(() {
                constraints[index]['controller'].dispose();
                constraints.removeAt(index);
              });
            }

            bool needsInput(String type) {
              return ['DEFAULT', 'CHECK', 'REFERENCES'].contains(type);
            }

            String getHintFor(String type) {
              switch (type) {
                case 'DEFAULT':
                  return 'Default value';
                case 'CHECK':
                  return 'Condition (e.g., price > 0)';
                case 'REFERENCES':
                  return 'Ref table(column)';
                default:
                  return '';
              }
            }

            String buildConstraintsString() {
              return constraints.map((c) {
                final type = c['type'] as String;
                final value = (c['controller'] as TextEditingController).text.trim();
                if (needsInput(type)) {
                  if (type == 'CHECK') return 'CHECK ($value)';
                  return '$type $value';
                }
                return type;
              }).join(' ');
            }

            return AlertDialog(
              title: Text(intl.getString((l) => l.modifyColumn)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: intl.getString((l) => l.columnName), border: const OutlineInputBorder())),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDataType,
                      hint: Text(intl.getString((l) => l.selectDataType)),
                      items: dataTypes.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                      onChanged: (newValue) => setStateInDialog(() => selectedDataType = newValue),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(intl.getString((l) => l.constraints), style: const TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          hint: Text(intl.getString((l) => l.add)),
                          icon: const Icon(Icons.add_circle_outline),
                          items: commonConstraints.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                          onChanged: (value) {
                            if (value != null && !constraints.any((c) => c['type'] == value)) {
                              addConstraint(value);
                            }
                          },
                        ),
                      ],
                    ),
                    ...constraints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final constraint = entry.value;
                      final type = constraint['type'] as String;
                      final controller = constraint['controller'] as TextEditingController;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            if (needsInput(type))
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: type,
                                    hintText: getHintFor(type),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              )
                            else
                              Expanded(child: Text(type)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => removeConstraint(index),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(intl.getString((l) => l.cancel))),
                ElevatedButton(
                  onPressed: () {
                    final newColumnName = nameController.text.trim();
                    if (newColumnName.isEmpty || selectedDataType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(intl.getString((l) => l.requiredAddingNewColumn)), backgroundColor: Colors.red));
                      return;
                    }
                    Navigator.pop(dialogContext);
                    final constraintsString = buildConstraintsString();
                    final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                      server: widget.server,
                      database: widget.database,
                    )));
                    _performOperation(
                      () => dbHandler.modifyColumn(
                          widget.table, columnData['name'], newColumnName, selectedDataType!, constraintsString),
                      intl.getString((l) => l.modifyColumnSuccess),
                    );
                  },
                  child: Text(intl.getString((l) => l.modify)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteColumnDialog(Map<String, String> column, DataEditingParams dataEditingParams) {
    final columnName = column['name']!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.deleteColumn)),
        content: Text(intl.getStringWithParams((l, columnName) => l.deleteColumnMessage(columnName), columnName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((l) => l.cancel)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                server: widget.server,
                database: widget.database,
              )));
              _performOperation(
                    () => dbHandler.deleteColumn(widget.table, columnName),
                intl.getStringWithParams((l, columnName) => l.deleteColumnSuccess(columnName), columnName),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(intl.getString((l) => l.delete)),
          ),
        ],
      ),
    );
  }

  void _showEditRowDialog(Map<String, dynamic>? rowData, DataEditingParams dataEditingParams) {
    final state = ref.read(dataEditingProvider(dataEditingParams));
    final notifier = ref.read(dataEditingProvider(dataEditingParams).notifier);
    final isNewRow = rowData == null;
    final controllers = <String, TextEditingController>{};
    final pkColName = state.primaryKeyColumn;

    for (var col in state.columns) {
      final colName = col['name']!;
      if (isNewRow && colName == pkColName && (col['type']!.contains('int') || col['type']!.contains('serial'))) {
        continue;
      }
      final value = isNewRow ? '' : (rowData[colName]?.toString() ?? '');
      controllers[colName] = TextEditingController(text: value);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isNewRow ? intl.getString((l) => l.addNewRow) : intl.getString((l) => l.editRow)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(
                    controller: entry.value, decoration: InputDecoration(labelText: entry.key, border: const OutlineInputBorder())),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(intl.getString((l) => l.cancel))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final values = controllers.map<String, dynamic>((key, value) {
                final text = value.text;
                return MapEntry(key, text.isEmpty ? null : text);
              });

              final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                server: dataEditingParams.server,
                database: dataEditingParams.database,
              )));
              
              notifier.setLoading(true);
              try {
                if (isNewRow) {
                  await dbHandler.addRow(dataEditingParams.table, values);
                  await notifier.loadTableData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(intl.getString((l) => l.addRowSuccess)), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  if (pkColName == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(intl.getString((l) => l.addRowFailurePK)), backgroundColor: Colors.red));
                    }
                    return;
                  }
                  final pkValue = rowData[pkColName];
                  await dbHandler.updateRow(dataEditingParams.table, values, pkColName, pkValue);
                  
                  // 행 인덱스 찾기
                  int? rowIndex;
                  for (int i = 0; i < state.rows.length; i++) {
                    if (state.rows[i][pkColName] == pkValue) {
                      rowIndex = i;
                      break;
                    }
                  }
                  
                  // 특정 행만 업데이트 (부분 리빌드)
                  if (rowIndex != null) {
                    await notifier.updateRowData(rowIndex);
                  } else {
                    await notifier.loadTableData();
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(intl.getString((l) => l.updateRowSuccess)), backgroundColor: Colors.green),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${intl.getString((l) => l.operationFailed)}: $e', maxLines: 3, overflow: TextOverflow.ellipsis), backgroundColor: Colors.red),
                  );
                }
              } finally {
                notifier.setLoading(false);
              }
            },
            child: Text(intl.getString((l) => l.save)),
          ),
        ],
      ),
    );
  }

  void _showStructureConfigDialog(
      Map<String, String> column, DataEditingParams dataEditingParams) {
    showCellStructureManagementDialog(
      context: context,
      dataEditingParams: dataEditingParams,
      initialColumn: column['name']!,
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> row, DataEditingParams dataEditingParams) {
    final state = ref.read(dataEditingProvider(dataEditingParams));
    final notifier = ref.read(dataEditingProvider(dataEditingParams).notifier);
    
    if (state.primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(intl.getString((l) => l.deleteFailedPk)), backgroundColor: Colors.red));
      return;
    }
    final pkValue = row[state.primaryKeyColumn!];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.deleteRow)),
        content: Text(intl.getStringWithParams((l, pkValue) => l.deleteRowConfirm(pkValue), pkValue)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(intl.getString((l) => l.cancel))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                server: dataEditingParams.server,
                database: dataEditingParams.database,
              )));
              
              notifier.setLoading(true);
              try {
                await dbHandler.deleteRow(dataEditingParams.table, state.primaryKeyColumn!, pkValue);
                await notifier.loadTableData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(intl.getStringWithParams((l, pkValue) => l.deleteRowConfirm(pkValue), pkValue)), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${intl.getString((l) => l.operationFailed)}: $e', maxLines: 3, overflow: TextOverflow.ellipsis), backgroundColor: Colors.red),
                  );
                }
              } finally {
                notifier.setLoading(false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(intl.getString((l) => l.delete)),
          ),
        ],
      ),
    );
  }
}

/// 테이블 본문 위젯 - 행들을 렌더링
class _TableBodyWidget extends StatelessWidget {
  final int rowsCount;
  final DataEditingParams dataEditingParams;
  final List<double> columnWidths;

  const _TableBodyWidget({
    required this.rowsCount,
    required this.dataEditingParams,
    required this.columnWidths,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(rowsCount, (index) {
        return _RowWidget(
          key: ValueKey('row_$index'),
          rowIndex: index,
          dataEditingParams: dataEditingParams,
          columnWidths: columnWidths,
        );
      }),
    );
  }
}

/// 행 위젯 - 각 행을 독립적으로 관리하여 부분 리빌드 최적화
class _RowWidget extends ConsumerWidget {
  final int rowIndex;
  final DataEditingParams dataEditingParams;
  final List<double> columnWidths;

  const _RowWidget({
    super.key,
    required this.rowIndex,
    required this.dataEditingParams,
    required this.columnWidths,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // columns만 watch (컬럼 구조 변경 시에만 리빌드)
    final columns = ref.watch(
      dataEditingProvider(dataEditingParams).select((state) => state.columns),
    );

    // 행 선택 상태만 watch
    final isRowSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedRowIndex == rowIndex,
      ),
    );

    // groupByColumns와 rows를 가져와서 구분선 표시 여부 결정
    final state = ref.watch(dataEditingProvider(dataEditingParams));
    final groupByColumns = state.groupByColumns;
    final rows = state.rows;
    final cellStructures = state.cellStructures;
    final isDisplayMode = state.isDisplayMode;

    // 흡수된 컬럼 목록
    final absorbedColumns = isDisplayMode
        ? cellStructures.values.fold<Set<String>>(
            {}, (s, cs) => s..addAll(cs.absorbedColumns))
        : <String>{};

    // 이전 행과 현재 행의 groupBy 컬럼 값이 다른지 확인
    bool shouldShowGroupDivider = false;
    if (groupByColumns.isNotEmpty && rowIndex > 0 && rowIndex < rows.length) {
      final currentRow = rows[rowIndex];
      final previousRow = rows[rowIndex - 1];

      for (final groupCol in groupByColumns) {
        if (currentRow[groupCol] != previousRow[groupCol]) {
          shouldShowGroupDivider = true;
          break;
        }
      }
    }
    // 전체 테이블 너비 계산
    final totalWidth = columnWidths.reduce((a, b) => a + b);

    return Column(
      children: [
        // 구분선 표시 - HR 태그처럼 전체 너비
        if (shouldShowGroupDivider)
          SizedBox(
            width: totalWidth,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.3),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        // 행 컨테이너
        Container(
          decoration: BoxDecoration(
            color: rowIndex.isOdd && !isRowSelected
                ? Theme.of(context).dividerColor.withValues(alpha: 0.05)
                : null,
            border: Border(
                bottom: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.2))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row number cell
              _RowNumberCellWidget(
                rowIndex: rowIndex,
                dataEditingParams: dataEditingParams,
                columnWidth: columnWidths.first,
              ),
              // Data cells
              ...columns.asMap().entries.map((entry) {
                final colIndex = entry.key;
                final col = entry.value;
                final colName = col['name']!;
                final width = columnWidths[colIndex + 1];

                // 흡수된 컬럼은 0 너비 SizedBox로 숨김
                if (isDisplayMode && absorbedColumns.contains(colName)) {
                  return SizedBox(key: ValueKey('cell_${rowIndex}_$colIndex'), width: 0);
                }

                // 구조화 셀 (메인 컬럼이고 구조가 정의된 경우)
                if (isDisplayMode && cellStructures.containsKey(colName)) {
                  return StructuredDataCell(
                    key: ValueKey('cell_${rowIndex}_$colIndex'),
                    rowIndex: rowIndex,
                    colIndex: colIndex,
                    columnName: colName,
                    structure: cellStructures[colName]!,
                    dataEditingParams: dataEditingParams,
                    columnWidth: width,
                  );
                }

                return EditableDataCell(
                  key: ValueKey('cell_${rowIndex}_$colIndex'),
                  rowIndex: rowIndex,
                  colIndex: colIndex,
                  columnName: colName,
                  dataEditingParams: dataEditingParams,
                  columnWidth: width,
                );
              }).toList(),
              // Actions cell
              _RowActionsCellWidget(
                rowIndex: rowIndex,
                dataEditingParams: dataEditingParams,
                columnWidth: columnWidths.last,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// AppBar 메뉴 위젯 - selectedCell 상태만 구독
class _AppBarMenu extends ConsumerWidget {
  final DataEditingParams dataEditingParams;

  const _AppBarMenu({
    required this.dataEditingParams,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // selectedCell과 selectedCellRange 모두 watch
    final selectedCell = ref.watch(
      dataEditingProvider(dataEditingParams).select((state) => state.selectedCell),
    );
    final selectedCellRange = ref.watch(
      dataEditingProvider(dataEditingParams).select((state) => state.selectedCellRange),
    );

    // 단일 셀이나 범위가 선택되어 있으면 활성화
    final hasSelection = selectedCell != null || selectedCellRange != null;

    return PopupMenuButton<String>(
      onSelected: (value) {
        final screen = context.findAncestorStateOfType<_DataEditingScreenState>();
        if (screen == null) return;

        if (value == 'copy') {
          screen._copyCell();
        } else if (value == 'paste') {
          screen._pasteCell();
        } else if (value == 'manageStructures') {
          showCellStructureManagementDialog(
            context: context,
            dataEditingParams: dataEditingParams,
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'copy',
          enabled: hasSelection,
          child: Text(intl.getString((i) => i.copyCell)),
        ),
        PopupMenuItem<String>(
          value: 'paste',
          enabled: hasSelection,
          child: Text(intl.getString((i) => i.pasteCell)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'manageStructures',
          child: Row(
            children: [
              Icon(Icons.view_agenda_outlined, size: 20),
              SizedBox(width: 8),
              Flexible(child: Text('셀 구조 관리', overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}

/// 테이블 헤더 위젯 - 필요한 상태만 선택적으로 구독
class _TableHeader extends ConsumerWidget {
  final DataEditingParams dataEditingParams;
  final ScrollController horizontalHeadController;

  const _TableHeader({
    required this.dataEditingParams,
    required this.horizontalHeadController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // columns와 columnWidths만 watch
    final columns = ref.watch(
      dataEditingProvider(dataEditingParams).select((state) => state.columns),
    );
    final columnWidths = ref.watch(
      dataEditingProvider(dataEditingParams).select((state) => state.columnWidths),
    );
    
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        controller: horizontalHeadController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            // Row number column header
            Container(
              width: columnWidths.first,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Theme.of(context).dividerColor),
                  bottom: BorderSide(color: Theme.of(context).dividerColor, width: 2),
                ),
              ),
              child: const Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...columns.asMap().entries.map((entry) {
              final i = entry.key;
              final col = entry.value;
              return _HeaderColumnCell(
                columnIndex: i,
                column: col,
                columnWidth: columnWidths[i + 1],
                dataEditingParams: dataEditingParams,
                onModifyColumn: (column) {
                  final screen = context.findAncestorStateOfType<_DataEditingScreenState>();
                  if (screen != null) {
                    screen._showModifyColumnDialog(column, dataEditingParams);
                  }
                },
                onDeleteColumn: (column) {
                  final screen = context.findAncestorStateOfType<_DataEditingScreenState>();
                  if (screen != null) {
                    screen._showDeleteColumnDialog(column, dataEditingParams);
                  }
                },
                onConfigStructure: (column) {
                  final screen = context.findAncestorStateOfType<_DataEditingScreenState>();
                  if (screen != null) {
                    screen._showStructureConfigDialog(column, dataEditingParams);
                  }
                },
              );
            }).toList(),
            Container(
              width: columnWidths.last,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor, width: 2),
                ),
              ),
              child: Text(intl.getString((i) => i.actions), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 헤더 열 셀 위젯 - 해당 열의 선택 상태만 구독
class _HeaderColumnCell extends ConsumerWidget {
  final int columnIndex;
  final Map<String, String> column;
  final double columnWidth;
  final DataEditingParams dataEditingParams;
  final void Function(Map<String, String>) onModifyColumn;
  final void Function(Map<String, String>) onDeleteColumn;
  final void Function(Map<String, String>) onConfigStructure;

  const _HeaderColumnCell({
    required this.columnIndex,
    required this.column,
    required this.columnWidth,
    required this.dataEditingParams,
    required this.onModifyColumn,
    required this.onDeleteColumn,
    required this.onConfigStructure,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 해당 열의 선택 상태만 watch
    final isSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedColumnIndex == columnIndex,
      ),
    );

    // columnWidths만 watch (리사이즈 시 리빌드)
    final columnWidths = ref.watch(
      dataEditingProvider(dataEditingParams).select((state) => state.columnWidths),
    );

    // 표시 모드일 때 displayName으로 헤더 표시
    final headerLabel = ref.watch(
      dataEditingProvider(dataEditingParams).select((state) {
        if (!state.isDisplayMode) return column['name']!;
        final structure = state.cellStructures[column['name']!];
        return structure?.effectiveDisplayName ?? column['name']!;
      }),
    );

    final notifier = ref.read(dataEditingProvider(dataEditingParams).notifier);

    return Stack(
      children: [
        Container(
          width: columnWidths[columnIndex + 1],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : null,
            border: Border(
              right: BorderSide(color: Theme.of(context).dividerColor),
              bottom: BorderSide(color: Theme.of(context).dividerColor, width: 2),
            ),
          ),
          child: GestureDetector(
            onTap: () => notifier.selectColumn(columnIndex),
            onLongPressStart: (LongPressStartDetails details) async {
              if (PlatformCheck.isMouseAvailable) {
                return;
              }

              final tapPosition = details.globalPosition;
              final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;

              final selected = await showMenu(
                context: context,
                position: RelativeRect.fromRect(
                  Rect.fromLTWH(
                    tapPosition.dx,
                    tapPosition.dy,
                    0,
                    0,
                  ),
                  Offset.zero & overlay.size,
                ),
                items: [
                  PopupMenuItem(value: 'edit', child: Text(intl.getString((i) => i.modify))),
                  const PopupMenuItem(
                    value: 'configStructure',
                    child: Row(
                      children: [
                        Icon(Icons.view_agenda_outlined, size: 20),
                        SizedBox(width: 8),
                        Flexible(child: Text('셀 구조 설정', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        Flexible(child: Text(intl.getString((i) => i.delete), style: const TextStyle(color: Colors.red), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ],
              );

              if (selected == 'edit') {
                onModifyColumn(column);
              } else if (selected == 'configStructure') {
                onConfigStructure(column);
              } else if (selected == 'delete') {
                onDeleteColumn(column);
              }
            },
            onSecondaryTapDown: (TapDownDetails details) async {
              if (!PlatformCheck.isMouseAvailable) {
                return;
              }

              final tapPosition = details.globalPosition;
              final screenSize = MediaQuery.of(context).size;

              final selected = await showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  tapPosition.dx,
                  tapPosition.dy,
                  screenSize.width - tapPosition.dx,
                  screenSize.height - tapPosition.dy,
                ),
                items: [
                  PopupMenuItem(value: 'edit', child: Text(intl.getString((i) => i.modify))),
                  const PopupMenuItem(
                    value: 'configStructure',
                    child: Row(
                      children: [
                        Icon(Icons.view_agenda_outlined, size: 20),
                        SizedBox(width: 8),
                        Flexible(child: Text('셀 구조 설정', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        Flexible(child: Text(intl.getString((i) => i.delete), style: const TextStyle(color: Colors.red), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ],
              );

              if (selected == 'edit') {
                onModifyColumn(column);
              } else if (selected == 'configStructure') {
                onConfigStructure(column);
              } else if (selected == 'delete') {
                onDeleteColumn(column);
              }
            },
            child: Text(
              headerLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final newWidth = columnWidths[columnIndex + 1] + details.delta.dx;
              notifier.updateColumnWidth(columnIndex + 1, newWidth);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(
                width: 8,
                color: Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 행 번호 셀 위젯 - 행 선택 상태만 구독하여 부분 리빌드 최적화
class _RowNumberCellWidget extends ConsumerWidget {
  final int rowIndex;
  final DataEditingParams dataEditingParams;
  final double columnWidth;

  const _RowNumberCellWidget({
    required this.rowIndex,
    required this.dataEditingParams,
    required this.columnWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 행 선택 상태만 watch
    final isRowSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedRowIndex == rowIndex,
      ),
    );

    final notifier = ref.read(dataEditingProvider(dataEditingParams).notifier);

    return GestureDetector(
      onTap: () => notifier.selectRow(rowIndex),
      child: Container(
        width: columnWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isRowSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : null,
          border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
        ),
        child: Text('${rowIndex + 1}'),
      ),
    );
  }
}

/// 행 액션 셀 위젯 - 행 선택 상태와 행 데이터만 구독
class _RowActionsCellWidget extends ConsumerWidget {
  final int rowIndex;
  final DataEditingParams dataEditingParams;
  final double columnWidth;

  const _RowActionsCellWidget({
    required this.rowIndex,
    required this.dataEditingParams,
    required this.columnWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 행 선택 상태만 watch
    final isRowSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedRowIndex == rowIndex,
      ),
    );

    // 행 데이터 가져오기 (수정/삭제 다이얼로그용)
    final state = ref.read(dataEditingProvider(dataEditingParams));

    if (rowIndex >= state.rows.length) {
      return Container(width: columnWidth);
    }

    final rowData = state.rows[rowIndex];

    return Container(
      width: columnWidth,
      decoration: BoxDecoration(
        color: isRowSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
            onPressed: () {
              final screen = context.findAncestorStateOfType<_DataEditingScreenState>();
              if (screen != null) {
                screen._showEditRowDialog(rowData, dataEditingParams);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            onPressed: () {
              final screen = context.findAncestorStateOfType<_DataEditingScreenState>();
              if (screen != null) {
                screen._showDeleteConfirmDialog(rowData, dataEditingParams);
              }
            },
          ),
        ],
      ),
    );
  }
}

