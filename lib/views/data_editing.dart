import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sqflite/platform_check.dart';
import '../stateManagement/setState/data_editing_riverpod.dart';

class CopyIntent extends Intent {}

class PasteIntent extends Intent {}

class DataEditingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> server;
  final String database;
  final String table;

  const DataEditingScreen({
    super.key,
    required this.server,
    required this.database,
    required this.table,
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
          SnackBar(content: Text('Operation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyCell() {
    final state = ref.read(dataEditingProvider(DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
    )));
    
    if (state.selectedCell == null) return;

    final rowIndex = state.selectedCell!['rowIndex']!;
    final colIndex = state.selectedCell!['colIndex']!;
    final value = state.rows[rowIndex][state.columns[colIndex]['name']!];

    Clipboard.setData(ClipboardData(text: value?.toString() ?? ''));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cell copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _pasteCell() async {
    final state = ref.read(dataEditingProvider(DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
    )));
    final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
      server: widget.server,
      database: widget.database,
    )));
    
    if (state.selectedCell == null) return;
    if (state.primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error: Cannot paste without a primary key.'), backgroundColor: Colors.red));
      return;
    }

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final newValue = clipboardData?.text;

    if (newValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nothing to paste from clipboard.'), backgroundColor: Colors.orange));
      return;
    }

    final rowIndex = state.selectedCell!['rowIndex']!;
    final colIndex = state.selectedCell!['colIndex']!;
    final targetColumnName = state.columns[colIndex]['name']!;
    final pkValue = state.rows[rowIndex][state.primaryKeyColumn!];

    await _performOperation(
      () => dbHandler.updateCell(
        widget.table,
        targetColumnName,
        newValue,
        state.primaryKeyColumn!,
        pkValue,
      ),
      'Cell updated successfully.',
      updatedRowIndex: rowIndex, // 특정 행만 업데이트
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataEditingProvider(DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
    )));
    final notifier = ref.read(dataEditingProvider(DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
    )).notifier);
    
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
              title: Text('${widget.table} - Data Editing'),
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              actions: [
                IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: () => notifier.loadTableData()),
                IconButton(
                    icon: const Icon(Icons.add), tooltip: 'Add Row', onPressed: () => _showEditRowDialog(null, state, notifier)),
                IconButton(
                    icon: const Icon(Icons.add_box_outlined),
                    tooltip: 'Add Column',
                    onPressed: () => _showAddColumnDialog(state, notifier)),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'copy') {
                      _copyCell();
                    } else if (value == 'paste') {
                      _pasteCell();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'copy',
                      enabled: state.selectedCell != null,
                      child: const Text('Copy Cell'),
                    ),
                    PopupMenuItem<String>(
                      value: 'paste',
                      enabled: state.selectedCell != null,
                      child: const Text('Paste Cell'),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
            body: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text(state.error!, style: const TextStyle(color: Colors.red)))
                    : state.columns.isEmpty
                        ? const Center(child: Text('Table has no columns. Please add one.'))
                        : Column(
                            children: [
                              _buildHeader(state, notifier),
                              _buildBody(state),
                            ],
                          ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DataEditingState state, DataEditingNotifier notifier) {
    return SingleChildScrollView(
      controller: _horizontalHeadController,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          // Row number column header
          Container(
            width: state.columnWidths.first,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
                bottom: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
            ),
            child: const Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...state.columns.asMap().entries.map((entry) {
            final i = entry.key;
            final col = entry.value;
            return Stack(
              children: [
                Container(
                  width: state.columnWidths[i + 1],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: state.selectedColumnIndex == i ? Colors.blue.withOpacity(0.2) : null,
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                      bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      notifier.selectColumn(i);
                    },
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
                          PopupMenuItem(value: 'edit', child: Text('Modify')),
                          // other menu items...
                        ],
                      );

                      if (selected == 'edit') {
                        _showModifyColumnDialog(state.columns[i], state, notifier);
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
                          PopupMenuItem(value: 'edit', child: Text('Modify')),
                        ],
                      );

                      if (selected == 'edit') {
                        _showModifyColumnDialog(state.columns[i], state, notifier);
                      }
                    },
                    child: Text(
                      col['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final newWidth = state.columnWidths[i + 1] + details.delta.dx;
                      notifier.updateColumnWidth(i + 1, newWidth);
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
          }).toList(),
          Container(
            width: state.columnWidths.last,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
            ),
            child: const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DataEditingState state) {
    final notifier = ref.read(dataEditingProvider(DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
    )).notifier);
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          controller: _horizontalBodyController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: state.rows.asMap().entries.map((entry) {
              final index = entry.key;
              final rowData = entry.value;
              return _buildRow(rowData, index, state, notifier);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> rowData, int rowIndex, DataEditingState state, DataEditingNotifier notifier) {
    final dataEditingParams = DataEditingParams(
      server: widget.server,
      database: widget.database,
      table: widget.table,
    );

    return Consumer(
      builder: (context, ref, child) {
        // ref.watch에 selector를 사용하여 행 선택 상태만 선택적으로 구독 (행 배경색용)
        final isRowSelected = ref.watch(
          dataEditingProvider(dataEditingParams).select(
            (state) => state.selectedRowIndex == rowIndex,
          ),
        );

        return Container(
          decoration: BoxDecoration(
            color: rowIndex.isOdd && !isRowSelected ? Colors.grey.withOpacity(0.1) : null,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // Row number cell
              child!,
              ...state.columns.asMap().entries.map((entry) {
                final colIndex = entry.key;
                final col = entry.value;
                return _DataCellWidget(
                  key: ValueKey('cell_${rowIndex}_${colIndex}'),
                  rowIndex: rowIndex,
                  colIndex: colIndex,
                  columnName: col['name']!,
                  dataEditingParams: dataEditingParams,
                  columnWidth: state.columnWidths[colIndex + 1],
                  onTap: () => notifier.selectCell(rowIndex, colIndex),
                  onDoubleTap: () {
                    notifier.selectCell(rowIndex, colIndex);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        // state에서 현재 행 데이터 가져오기
                        final currentState = ref.read(dataEditingProvider(dataEditingParams));
                        if (rowIndex < currentState.rows.length) {
                          final currentRowData = currentState.rows[rowIndex];
                          _showEditCellDialog(currentRowData, col['name']!, currentState, notifier);
                        }
                      }
                    });
                  },
                );
              }).toList(),
              // Actions cell
              Consumer(
                builder: (context, ref, child) {
                  // ref.watch에 selector를 사용하여 행 선택 상태만 선택적으로 구독
                  final isRowSelectedForActions = ref.watch(
                    dataEditingProvider(dataEditingParams).select(
                      (state) => state.selectedRowIndex == rowIndex,
                    ),
                  );
                  return Container(
                    width: state.columnWidths.last,
                    decoration: BoxDecoration(
                      color: isRowSelectedForActions ? Colors.blue.withOpacity(0.2) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                          onPressed: () => _showEditRowDialog(rowData, state, notifier),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _showDeleteConfirmDialog(rowData, state, notifier),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      child: GestureDetector(
        onTap: () => notifier.selectRow(rowIndex),
        child: Consumer(
          builder: (context, ref, child) {
            // ref.watch에 selector를 사용하여 행 선택 상태만 선택적으로 구독
            final isRowSelected = ref.watch(
              dataEditingProvider(DataEditingParams(
                server: widget.server,
                database: widget.database,
                table: widget.table,
              )).select(
                (state) => state.selectedRowIndex == rowIndex,
              ),
            );
            return Container(
              width: state.columnWidths.first,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isRowSelected ? Colors.blue.withOpacity(0.2) : null,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text('${rowIndex + 1}'),
            );
          },
        ),
      ),
    );
  }

  void _showAddColumnDialog(DataEditingState state, DataEditingNotifier notifier) {
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
              title: const Text('Add New Column'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Column Name', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedDataType,
                      hint: const Text('Select Data Type'),
                      items: dataTypes.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                      onChanged: (newValue) => setStateInDialog(() => selectedDataType = newValue),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Constraints', style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          hint: const Text('Add'),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Column name and data type are required.'), backgroundColor: Colors.red));
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
                      'Column added successfully.',
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showModifyColumnDialog(Map<String, dynamic> columnData, DataEditingState state, DataEditingNotifier notifier) {
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
              title: const Text('Modify Column'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Column Name', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedDataType,
                      hint: const Text('Select Data Type'),
                      items: dataTypes.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                      onChanged: (newValue) => setStateInDialog(() => selectedDataType = newValue),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Constraints', style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          hint: const Text('Add'),
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
                    final newColumnName = nameController.text.trim();
                    if (newColumnName.isEmpty || selectedDataType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Column name and data type are required.'), backgroundColor: Colors.red));
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
                      'Column modified successfully.',
                    );
                  },
                  child: const Text('Modify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCellDialog(Map<String, dynamic> rowData, String columnName, DataEditingState state, DataEditingNotifier notifier) {
    if (state.primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error: Cannot edit cell without a primary key.'),
          backgroundColor: Colors.red));
      return;
    }

    final pkValue = rowData[state.primaryKeyColumn!];
    final currentValue = rowData[columnName];
    final controller = TextEditingController(text: currentValue?.toString() ?? '');

    // 행 인덱스 찾기 (부분 리빌드를 위해 필요)
    int? rowIndex;
    for (int i = 0; i < state.rows.length; i++) {
      if (state.rows[i][state.primaryKeyColumn!] == pkValue) {
        rowIndex = i;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Cell: $columnName'),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final newValue = controller.text.trim();
              final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                server: widget.server,
                database: widget.database,
              )));
              _performOperation(
                () => dbHandler.updateCell(
                  widget.table,
                  columnName,
                  newValue.isEmpty ? null : newValue,
                  state.primaryKeyColumn!,
                  pkValue,
                ),
                'Cell updated successfully.',
                updatedRowIndex: rowIndex, // 특정 행만 업데이트
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditRowDialog(Map<String, dynamic>? rowData, DataEditingState state, DataEditingNotifier notifier) {
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
        title: Text(isNewRow ? 'Add New Row' : 'Edit Row'),
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final values = controllers.map<String, dynamic>((key, value) {
                final text = value.text;
                return MapEntry(key, text.isEmpty ? null : text);
              });

              final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                server: widget.server,
                database: widget.database,
              )));
              if (isNewRow) {
                _performOperation(() => dbHandler.addRow(widget.table, values), 'Row added successfully.');
              } else {
                if (pkColName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Error: Cannot update without a primary key.'), backgroundColor: Colors.red));
                  return;
                }
                final pkValue = rowData[pkColName];
                _performOperation(
                    () => dbHandler.updateRow(widget.table, values, pkColName, pkValue), 'Row updated successfully.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> row, DataEditingState state, DataEditingNotifier notifier) {
    if (state.primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Cannot delete without a primary key.'), backgroundColor: Colors.red));
      return;
    }
    final pkValue = row[state.primaryKeyColumn!];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Row'),
        content: Text('Are you sure you want to delete this row? (Primary Key: $pkValue)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final dbHandler = ref.read(databaseHandlerProvider(DatabaseHandlerParams(
                server: widget.server,
                database: widget.database,
              )));
              _performOperation(
                () => dbHandler.deleteRow(widget.table, state.primaryKeyColumn!, pkValue),
                'Row deleted successfully.',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// 개별 셀 위젯 - 해당 셀의 값과 선택 상태만 구독하여 부분 리빌드 최적화
class _DataCellWidget extends ConsumerWidget {
  final int rowIndex;
  final int colIndex;
  final String columnName;
  final DataEditingParams dataEditingParams;
  final double columnWidth;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _DataCellWidget({
    super.key,
    required this.rowIndex,
    required this.colIndex,
    required this.columnName,
    required this.dataEditingParams,
    required this.columnWidth,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch에 selector를 사용하여 특정 셀 값만 선택적으로 구독 (값이 변경될 때만 리빌드)
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

    // ref.watch에 selector를 사용하여 셀 선택 상태만 선택적으로 구독
    final isCellSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedCell != null &&
            state.selectedCell!['rowIndex'] == rowIndex &&
            state.selectedCell!['colIndex'] == colIndex,
      ),
    );

    // ref.watch에 selector를 사용하여 열 선택 상태만 선택적으로 구독
    final isColSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedColumnIndex == colIndex,
      ),
    );

    // ref.watch에 selector를 사용하여 행 선택 상태만 선택적으로 구독
    final isRowSelected = ref.watch(
      dataEditingProvider(dataEditingParams).select(
        (state) => state.selectedRowIndex == rowIndex,
      ),
    );

    Color? cellColor;
    if (isCellSelected) {
      cellColor = Colors.green.withOpacity(0.4);
    } else if (isRowSelected || isColSelected) {
      cellColor = Colors.blue.withOpacity(0.2);
    }

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        width: columnWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cellColor,
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Text(cellValue?.toString() ?? 'NULL'),
      ),
    );
  }
}
