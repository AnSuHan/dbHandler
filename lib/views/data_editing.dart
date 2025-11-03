import 'package:db_handler/stateManagement/riverpod/data_editing_provider.dart';
import 'package:db_handler/views/widgets/cell_item.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sqflite/platform_check.dart';

class CopyIntent extends Intent {}

class PasteIntent extends Intent {}

class DataEditingScreen extends ConsumerStatefulWidget {
  const DataEditingScreen({
    super.key,
    required this.server,
    required this.database,
    required this.table,
  });

  final Map<String, dynamic> server;
  final String database;
  final String table;

  @override
  ConsumerState<DataEditingScreen> createState() => _DataEditingScreenState();
}

class _DataEditingScreenState extends ConsumerState<DataEditingScreen> {
  late DataEditingArgs _args;
  final FocusNode _focusNode = FocusNode();
  late final ScrollController _horizontalHeadController;
  late final ScrollController _horizontalBodyController;

  @override
  void initState() {
    super.initState();
    _args = DataEditingArgs(server: widget.server, database: widget.database, table: widget.table);
    _horizontalHeadController = ScrollController();
    _horizontalBodyController = ScrollController();
    _syncScroll();
  }

  @override
  void didUpdateWidget(covariant DataEditingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.server != oldWidget.server ||
        widget.database != oldWidget.database ||
        widget.table != oldWidget.table) {
      final previousArgs = _args;
      _args = DataEditingArgs(server: widget.server, database: widget.database, table: widget.table);
      ref.invalidate(dataEditingProvider(previousArgs));
      ref.invalidate(dataEditingSelectionProvider(previousArgs));
    }
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

  DataEditingNotifier _notifier() => ref.read(dataEditingProvider(_args).notifier);

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _runDbAction({
    required Future<void> Function(DataEditingNotifier notifier) action,
    required String successMessage,
  }) async {
    try {
      await action(_notifier());
      _showSnack(successMessage, Colors.green);
    } catch (e) {
      _showSnack('Operation failed: $e', Colors.red);
    }
  }

  void _copyCell() {
    final selection = ref.read(dataEditingSelectionProvider(_args));
    final cell = selection.selectedCell;
    if (cell == null) return;

    final state = ref.read(dataEditingProvider(_args));
    if (cell.rowIndex >= state.rows.length || cell.colIndex >= state.columns.length) return;

    final value = state.cellValue(cell.rowIndex, cell.colIndex);
    Clipboard.setData(ClipboardData(text: value?.toString() ?? ''));
    _showSnack('Cell copied to clipboard', Colors.blueGrey.shade700);
  }

  Future<void> _pasteCell() async {
    final selection = ref.read(dataEditingSelectionProvider(_args));
    final cell = selection.selectedCell;
    if (cell == null) return;

    final state = ref.read(dataEditingProvider(_args));
    final pkColumn = state.primaryKeyColumn;
    if (pkColumn == null) {
      _showSnack('Error: Cannot paste without a primary key.', Colors.red);
      return;
    }

    if (cell.rowIndex >= state.rows.length || cell.colIndex >= state.columns.length) return;

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final newValue = clipboardData?.text;

    if (newValue == null) {
      _showSnack('Nothing to paste from clipboard.', Colors.orange);
      return;
    }

    final columnName = state.columns[cell.colIndex].name;
    await _runDbAction(
      action: (notifier) => notifier.updateCellValue(
        rowIndex: cell.rowIndex,
        columnIndex: cell.colIndex,
        columnName: columnName,
        newValue: newValue,
      ),
      successMessage: 'Cell updated successfully.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataEditingProvider(_args));

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyC): CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): PasteIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV): PasteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CopyIntent: CallbackAction<CopyIntent>((intent) {
            _copyCell();
            return null;
          }),
          PasteIntent: CallbackAction<PasteIntent>((intent) {
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
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.read(dataEditingSelectionProvider(_args).notifier).clear();
                    _notifier().refresh();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Row',
                  onPressed: () => _showEditRowDialog(null),
                ),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined),
                  tooltip: 'Add Column',
                  onPressed: _showAddColumnDialog,
                ),
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
                      enabled: ref.watch(
                        dataEditingSelectionProvider(_args).select((s) => s.selectedCell != null),
                      ),
                      child: const Text('Copy Cell'),
                    ),
                    PopupMenuItem<String>(
                      value: 'paste',
                      enabled: ref.watch(
                        dataEditingSelectionProvider(_args).select((s) => s.selectedCell != null),
                      ),
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
                    : !state.hasColumns
                        ? const Center(child: Text('Table has no columns. Please add one.'))
                        : Column(
                            children: [
                              _buildHeader(state),
                              _buildBody(state),
                            ],
                          ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DataEditingState state) {
    return SingleChildScrollView(
      controller: _horizontalHeadController,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          Container(
            width: state.widthAt(0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
                bottom: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
            ),
            child: const Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...List.generate(state.columns.length, (index) {
            final column = state.columns[index];
            final isSelected = ref.watch(
              dataEditingSelectionProvider(_args).select((selection) => selection.isColumnSelected(index)),
            );

            return Stack(
              children: [
                Container(
                  width: state.widthAt(index + 1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.withOpacity(0.2) : null,
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                      bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () => ref.read(dataEditingSelectionProvider(_args).notifier).toggleColumn(index),
                    onLongPressStart: (details) async {
                      if (PlatformCheck.isMouseAvailable) {
                        return;
                      }

                      final tapPosition = details.globalPosition;
                      final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;

                      final selected = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromRect(
                          Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 0, 0),
                          Offset.zero & overlay.size,
                        ),
                        items: const [
                          PopupMenuItem(value: 'edit', child: Text('Modify')),
                        ],
                      );

                      if (selected == 'edit') {
                        _showModifyColumnDialog(column);
                      }
                    },
                    onSecondaryTapDown: (details) async {
                      if (!PlatformCheck.isMouseAvailable) {
                        return;
                      }

                      final tapPosition = details.globalPosition;
                      final screenSize = MediaQuery.of(context).size;

                      final selected = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromLTRB(
                          tapPosition.dx,
                          tapPosition.dy,
                          screenSize.width - tapPosition.dx,
                          screenSize.height - tapPosition.dy,
                        ),
                        items: const [
                          PopupMenuItem(value: 'edit', child: Text('Modify')),
                        ],
                      );

                      if (selected == 'edit') {
                        _showModifyColumnDialog(column);
                      }
                    },
                    child: Text(
                      column.name,
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
                      final currentWidth = ref.read(dataEditingProvider(_args)).widthAt(index + 1);
                      final newWidth = currentWidth + details.delta.dx;
                      ref.read(dataEditingProvider(_args).notifier).updateColumnWidth(index + 1, newWidth);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: Container(width: 8, color: Colors.transparent),
                    ),
                  ),
                ),
              ],
            );
          }),
          Container(
            width: state.widthAt(state.columnWidths.length - 1),
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
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          controller: _horizontalBodyController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(state.rows.length, (index) => _buildRow(state, index)),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(DataEditingState state, int rowIndex) {
    final isRowSelected = ref.watch(
      dataEditingSelectionProvider(_args).select((selection) => selection.isRowSelected(rowIndex)),
    );

    return Container(
      decoration: BoxDecoration(
        color: rowIndex.isOdd && !isRowSelected ? Colors.grey.withOpacity(0.1) : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(dataEditingSelectionProvider(_args).notifier).toggleRow(rowIndex),
            child: Container(
              width: state.widthAt(0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isRowSelected ? Colors.blue.withOpacity(0.2) : null,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text('${rowIndex + 1}'),
            ),
          ),
          ...List.generate(state.columns.length, (colIndex) {
            return CellItem(
              args: _args,
              rowIndex: rowIndex,
              columnIndex: colIndex,
              onEditRequested: () => _showEditCellDialog(rowIndex, colIndex),
            );
          }),
          Container(
            width: state.widthAt(state.columnWidths.length - 1),
            decoration: BoxDecoration(
              color: isRowSelected ? Colors.blue.withOpacity(0.2) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  onPressed: () => _showEditRowDialog(rowIndex),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _showDeleteConfirmDialog(rowIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddColumnDialog() {
    final nameController = TextEditingController();
    String? selectedDataType;
    final List<Map<String, dynamic>> constraints = [];

    const dataTypes = [
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
    const commonConstraints = [
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
                constraints.add({'type': type, 'controller': TextEditingController()});
              });
            }

            void removeConstraint(int index) {
              setStateInDialog(() {
                constraints[index]['controller'].dispose();
                constraints.removeAt(index);
              });
            }

            bool needsInput(String type) => ['DEFAULT', 'CHECK', 'REFERENCES'].contains(type);

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
                      decoration: const InputDecoration(
                        labelText: 'Column Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
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
                          items: commonConstraints
                              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                              .toList(),
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
                      _showSnack('Column name and data type are required.', Colors.red);
                      return;
                    }
                    Navigator.pop(dialogContext);
                    final constraintsString = buildConstraintsString();
                    _runDbAction(
                      action: (notifier) => notifier.addColumn(columnName, selectedDataType!, constraintsString),
                      successMessage: 'Column added successfully.',
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

  void _showModifyColumnDialog(DataColumnInfo column) {
    final nameController = TextEditingController(text: column.name);
    const dataTypes = [
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

    String? selectedDataType = dataTypes.contains(column.type) ? column.type : dataTypes.first;
    final List<Map<String, dynamic>> constraints = [];

    const commonConstraints = [
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
                constraints.add({'type': type, 'controller': TextEditingController()});
              });
            }

            void removeConstraint(int index) {
              setStateInDialog(() {
                constraints[index]['controller'].dispose();
                constraints.removeAt(index);
              });
            }

            bool needsInput(String type) => ['DEFAULT', 'CHECK', 'REFERENCES'].contains(type);

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
                      decoration: const InputDecoration(
                        labelText: 'Column Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
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
                          items: commonConstraints
                              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                              .toList(),
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
                      _showSnack('Column name and data type are required.', Colors.red);
                      return;
                    }
                    Navigator.pop(dialogContext);
                    final constraintsString = buildConstraintsString();
                    _runDbAction(
                      action: (notifier) => notifier.modifyColumn(
                        column.name,
                        newColumnName,
                        selectedDataType!,
                        constraintsString,
                      ),
                      successMessage: 'Column modified successfully.',
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

  void _showEditCellDialog(int rowIndex, int columnIndex) {
    final state = ref.read(dataEditingProvider(_args));
    final pkColumn = state.primaryKeyColumn;
    if (pkColumn == null) {
      _showSnack('Error: Cannot edit cell without a primary key.', Colors.red);
      return;
    }

    final row = state.rowAt(rowIndex);
    final column = state.columns[columnIndex];
    final pkValue = row[pkColumn];
    final currentValue = state.cellValue(rowIndex, columnIndex);
    final controller = TextEditingController(text: currentValue?.toString() ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Cell: ${column.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
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
              _runDbAction(
                action: (notifier) => notifier.updateCellValue(
                  rowIndex: rowIndex,
                  columnIndex: columnIndex,
                  columnName: column.name,
                  newValue: newValue.isEmpty ? null : newValue,
                ),
                successMessage: 'Cell updated successfully.',
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditRowDialog(int? rowIndex) {
    final state = ref.read(dataEditingProvider(_args));
    final isNewRow = rowIndex == null;
    final pkColumn = state.primaryKeyColumn;
    final controllers = <String, TextEditingController>{};

    for (final column in state.columns) {
      final colName = column.name;
      final shouldSkipPk = isNewRow &&
          pkColumn != null &&
          colName == pkColumn &&
          (column.type.toLowerCase().contains('int') || column.type.toLowerCase().contains('serial'));

      if (shouldSkipPk) {
        continue;
      }

      final value = isNewRow ? '' : (state.rowAt(rowIndex!)[colName]?.toString() ?? '');
      controllers[colName] = TextEditingController(text: value);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isNewRow ? 'Add New Row' : 'Edit Row'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final values = controllers.map<String, dynamic>((key, controller) {
                final text = controller.text.trim();
                return MapEntry(key, text.isEmpty ? null : text);
              });

              if (isNewRow) {
                _runDbAction(
                  action: (notifier) => notifier.addRow(values),
                  successMessage: 'Row added successfully.',
                );
              } else {
                if (pkColumn == null) {
                  _showSnack('Error: Cannot update without a primary key.', Colors.red);
                  return;
                }
                final pkValue = state.rowAt(rowIndex!)[pkColumn];
                _runDbAction(
                  action: (notifier) => notifier.updateRow(
                    values: values,
                    primaryKeyValue: pkValue,
                  ),
                  successMessage: 'Row updated successfully.',
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(int rowIndex) {
    final state = ref.read(dataEditingProvider(_args));
    final pkColumn = state.primaryKeyColumn;
    if (pkColumn == null) {
      _showSnack('Error: Cannot delete without a primary key.', Colors.red);
      return;
    }

    final pkValue = state.rowAt(rowIndex)[pkColumn];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Row'),
        content: Text('Are you sure you want to delete this row? (Primary Key: $pkValue)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext);
              _runDbAction(
                action: (notifier) => notifier.deleteRow(pkValue),
                successMessage: 'Row deleted successfully.',
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
