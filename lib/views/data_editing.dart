import 'dart:math';
import 'package:db_handler/db/database_handler.dart';
import 'package:db_handler/db/postgres_handler.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sqflite/platform_check.dart';

class CopyIntent extends Intent {}

class PasteIntent extends Intent {}

class DataEditingScreen extends StatefulWidget {
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
  State<DataEditingScreen> createState() => _DataEditingScreenState();
}

class _DataEditingScreenState extends State<DataEditingScreen> {
  late final DatabaseHandler _dbHandler;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, String>> _columns = [];
  String? _primaryKeyColumn;
  List<double> _columnWidths = [];
  List<double> _minColumnWidths = [];

  int? _selectedColumnIndex;
  int? _selectedRowIndex;
  Map<String, int>? _selectedCell; // { 'rowIndex': int, 'colIndex': int }
  final FocusNode _focusNode = FocusNode();

  late final ScrollController _horizontalHeadController;
  late final ScrollController _horizontalBodyController;

  @override
  void initState() {
    super.initState();
    _dbHandler = _getDbHandler();
    _horizontalHeadController = ScrollController();
    _horizontalBodyController = ScrollController();
    _syncScroll();
    _loadTableData();
  }

  DatabaseHandler _getDbHandler() {
    switch (widget.server['type']) {
      case 'PostgreSQL':
        return PostgresHandler(widget.server, database: widget.database);
      default:
        throw Exception('Unsupported database type: ${widget.server['type']}');
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

  Future<void> _loadTableData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final columns = await _dbHandler.getColumns(widget.table);
      final primaryKey = await _dbHandler.getPrimaryKey(widget.table);
      final dataRows = await _dbHandler.getData(widget.table);

      final minWidths = columns.map<double>((col) {
        return _getTextWidth(col['name']!, const TextStyle(fontWeight: FontWeight.bold)) + 34.0;
      }).toList();

      final initialWidths = _calculateColumnWidths(columns, dataRows, minWidths);

      // Add width for the row number column
      initialWidths.insert(0, 60.0);
      minWidths.insert(0, 60.0);

      if (mounted) {
        setState(() {
          _columns = columns.map((c) => {'name': c['name'] as String, 'type': c['type'] as String}).toList();
          _primaryKeyColumn = primaryKey;
          _rows = dataRows;
          _minColumnWidths = minWidths;
          _columnWidths = initialWidths;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load table data: $e';
        });
      }
    }
  }

  List<double> _calculateColumnWidths(
      List<Map<String, dynamic>> columns, List<Map<String, dynamic>> rows, List<double> minWidths) {
    final List<double> widths = [];
    final columnsAndActions = [...columns, {'name': 'Actions'}];

    for (int i = 0; i < columnsAndActions.length; i++) {
      if (i < columns.length) {
        // Regular column
        double maxWidth = minWidths[i]; // Start with min width (header width + padding)
        final colName = columns[i]['name']!;
        for (var row in rows) {
          final value = row[colName]?.toString() ?? 'NULL';
          final cellWidth = _getTextWidth(value, const TextStyle()) + 34.0; // Increased buffer
          maxWidth = max(maxWidth, cellWidth);
        }
        widths.add(maxWidth);
      } else {
        // Actions column
        widths.add(100.0);
      }
    }
    return widths;
  }

  double _getTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }

  Future<void> _performOperation(
    Future<void> Function() operation,
    String successMessage,
  ) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await operation();

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

    if (mounted) {
      await _loadTableData();
    }
  }

  void _copyCell() {
    if (_selectedCell == null) return;

    final rowIndex = _selectedCell!['rowIndex']!;
    final colIndex = _selectedCell!['colIndex']!;
    final value = _rows[rowIndex][_columns[colIndex]['name']!];

    Clipboard.setData(ClipboardData(text: value?.toString() ?? ''));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cell copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _pasteCell() async {
    if (_selectedCell == null) return;
    if (_primaryKeyColumn == null) {
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

    final rowIndex = _selectedCell!['rowIndex']!;
    final colIndex = _selectedCell!['colIndex']!;
    final targetColumnName = _columns[colIndex]['name']!;
    final pkValue = _rows[rowIndex][_primaryKeyColumn!];

    await _performOperation(
      () => _dbHandler.updateCell(
        widget.table,
        targetColumnName,
        newValue,
        _primaryKeyColumn!,
        pkValue,
      ),
      'Cell updated successfully.',
    );
  }

  @override
  Widget build(BuildContext context) {
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
                IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadTableData),
                IconButton(
                    icon: const Icon(Icons.add), tooltip: 'Add Row', onPressed: () => _showEditRowDialog(null)),
                IconButton(
                    icon: const Icon(Icons.add_box_outlined),
                    tooltip: 'Add Column',
                    onPressed: _showAddColumnDialog),
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
                      enabled: _selectedCell != null,
                      child: const Text('Copy Cell'),
                    ),
                    PopupMenuItem<String>(
                      value: 'paste',
                      enabled: _selectedCell != null,
                      child: const Text('Paste Cell'),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _columns.isEmpty
                        ? const Center(child: Text('Table has no columns. Please add one.'))
                        : Column(
                            children: [
                              _buildHeader(),
                              _buildBody(),
                            ],
                          ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SingleChildScrollView(
      controller: _horizontalHeadController,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          // Row number column header
          Container(
            width: _columnWidths.first,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
                bottom: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
            ),
            child: const Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ..._columns.asMap().entries.map((entry) {
            final i = entry.key;
            final col = entry.value;
            return Stack(
              children: [
                Container(
                  width: _columnWidths[i + 1],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedColumnIndex == i ? Colors.blue.withOpacity(0.2) : null,
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                      bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      _selectColumn(i);
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
                        _showModifyColumnDialog(_columns[i]);
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
                        _showModifyColumnDialog(_columns[i]);
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
                      setState(() {
                        final newWidth = _columnWidths[i + 1] + details.delta.dx;
                        _columnWidths[i + 1] = max(newWidth, _minColumnWidths[i + 1]);
                      });
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
            width: _columnWidths.last,
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

  void _selectColumn(int index) {
    setState(() {
      if (_selectedColumnIndex == index) {
        _selectedColumnIndex = null; // deselect
      } else {
        _selectedColumnIndex = index;
        _selectedRowIndex = null;
        _selectedCell = null;
      }
    });
  }

  void _selectRow(int index) {
    setState(() {
      if (_selectedRowIndex == index) {
        _selectedRowIndex = null; // deselect
      } else {
        _selectedRowIndex = index;
        _selectedColumnIndex = null;
        _selectedCell = null;
      }
    });
  }

  void _selectCell(int rowIndex, int colIndex) {
    setState(() {
      final currentCell = _selectedCell;
      if (currentCell != null &&
          currentCell['rowIndex'] == rowIndex &&
          currentCell['colIndex'] == colIndex) {
        _selectedCell = null; // deselect
      } else {
        _selectedCell = {'rowIndex': rowIndex, 'colIndex': colIndex};
        _selectedRowIndex = null;
        _selectedColumnIndex = null;
      }
    });
  }

  Widget _buildBody() {
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          controller: _horizontalBodyController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _rows.asMap().entries.map((entry) {
              final index = entry.key;
              final rowData = entry.value;
              return _buildRow(rowData, index);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> rowData, int rowIndex) {
    final isRowSelectedForColor = _selectedRowIndex == rowIndex;

    return Container(
      decoration: BoxDecoration(
        color: rowIndex.isOdd && !isRowSelectedForColor ? Colors.grey.withOpacity(0.1) : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Row number cell
          GestureDetector(
            onTap: () => _selectRow(rowIndex),
            child: Container(
              width: _columnWidths.first,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isRowSelectedForColor ? Colors.blue.withOpacity(0.2) : null,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text('${rowIndex + 1}'),
            ),
          ),
          ..._columns.asMap().entries.map((entry) {
            final colIndex = entry.key;
            final col = entry.value;
            final value = rowData[col['name']];

            final isColSelected = _selectedColumnIndex == colIndex;
            final isCellSelected = _selectedCell != null &&
                _selectedCell!['rowIndex'] == rowIndex &&
                _selectedCell!['colIndex'] == colIndex;

            Color? cellColor;
            if (isCellSelected) {
              cellColor = Colors.green.withOpacity(0.4);
            } else if (isRowSelectedForColor || isColSelected) {
              cellColor = Colors.blue.withOpacity(0.2);
            }

            return GestureDetector(
              onTap: () => _selectCell(rowIndex, colIndex),
              onDoubleTap: () {
                setState(() {
                  _selectedCell = {'rowIndex': rowIndex, 'colIndex': colIndex};
                  _selectedRowIndex = null;
                  _selectedColumnIndex = null;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showEditCellDialog(rowData, col['name']!);
                  }
                });
              },
              child: Container(
                width: _columnWidths[colIndex + 1],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cellColor,
                  border: Border(right: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Text(value?.toString() ?? 'NULL'),
              ),
            );
          }).toList(),
          Container(
            width: _columnWidths.last,
            decoration: BoxDecoration(
              color: isRowSelectedForColor ? Colors.blue.withOpacity(0.2) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  onPressed: () => _showEditRowDialog(rowData),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _showDeleteConfirmDialog(rowData),
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
                    _performOperation(
                      () => _dbHandler.addColumn(widget.table, columnName, selectedDataType!, constraintsString),
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

  void _showModifyColumnDialog(Map<String, dynamic> columnData) {
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
                    _performOperation(
                      () => _dbHandler.modifyColumn(
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

  void _showEditCellDialog(Map<String, dynamic> rowData, String columnName) {
    if (_primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error: Cannot edit cell without a primary key.'),
          backgroundColor: Colors.red));
      return;
    }

    final pkValue = rowData[_primaryKeyColumn!];
    final currentValue = rowData[columnName];
    final controller = TextEditingController(text: currentValue?.toString() ?? '');

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
              _performOperation(
                () => _dbHandler.updateCell(
                  widget.table,
                  columnName,
                  newValue.isEmpty ? null : newValue,
                  _primaryKeyColumn!,
                  pkValue,
                ),
                'Cell updated successfully.',
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditRowDialog(Map<String, dynamic>? rowData) {
    final isNewRow = rowData == null;
    final controllers = <String, TextEditingController>{};
    final pkColName = _primaryKeyColumn;

    for (var col in _columns) {
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

              if (isNewRow) {
                _performOperation(() => _dbHandler.addRow(widget.table, values), 'Row added successfully.');
              } else {
                if (pkColName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Error: Cannot update without a primary key.'), backgroundColor: Colors.red));
                  return;
                }
                final pkValue = rowData![pkColName];
                _performOperation(
                    () => _dbHandler.updateRow(widget.table, values, pkColName, pkValue), 'Row updated successfully.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> row) {
    if (_primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Cannot delete without a primary key.'), backgroundColor: Colors.red));
      return;
    }
    final pkValue = row[_primaryKeyColumn!];

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
              _performOperation(
                () => _dbHandler.deleteRow(widget.table, _primaryKeyColumn!, pkValue),
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
