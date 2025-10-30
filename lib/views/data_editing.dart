import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';

import '../sqflite/platform_check.dart';

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
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, String>> _columns = [];
  String? _primaryKeyColumn;
  List<double> _columnWidths = [];
  List<double> _minColumnWidths = [];

  late final ScrollController _horizontalHeadController;
  late final ScrollController _horizontalBodyController;

  @override
  void initState() {
    super.initState();
    _horizontalHeadController = ScrollController();
    _horizontalBodyController = ScrollController();
    _syncScroll();
    _loadTableData();
  }

  void _syncScroll() {
    _horizontalHeadController.addListener(() {
      if (_horizontalBodyController.hasClients && _horizontalBodyController.offset != _horizontalHeadController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeadController.offset);
      }
    });
    _horizontalBodyController.addListener(() {
      if (_horizontalHeadController.hasClients && _horizontalHeadController.offset != _horizontalBodyController.offset) {
        _horizontalHeadController.jumpTo(_horizontalBodyController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeadController.dispose();
    _horizontalBodyController.dispose();
    super.dispose();
  }

  Future<PostgreSQLConnection> _getConnection() async {
    final host = widget.server['address'].split(':')[0];
    final port = int.parse(widget.server['address'].split(':')[1]);
    final username = widget.server['username'] as String?;
    final password = widget.server['password'] as String?;
    
    final connection = PostgreSQLConnection(
      host,
      port,
      widget.database,
      username: username,
      password: password,
    );
    await connection.open();
    return connection;
  }

  Future<void> _loadTableData() async {
    if (mounted) setState(() => _isLoading = true);

    PostgreSQLConnection? connection;
    try {
      connection = await _getConnection();
      
      final columnResults = await connection.query(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' AND table_name = @tableName ORDER BY ordinal_position",
        substitutionValues: {'tableName': widget.table},
      );
      final columns = columnResults
          .map((row) => {'name': row[0] as String, 'type': row[1] as String})
          .toList();

      final pkResult = await connection.query(
        "SELECT kcu.column_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_name = @tableName",
        substitutionValues: {'tableName': widget.table},
      );
      final primaryKey = pkResult.isNotEmpty ? pkResult.first[0] as String : null;

      String query = 'SELECT * FROM "${widget.table}"';
      if (primaryKey != null) {
        query += ' ORDER BY "$primaryKey" ASC';
      }
      final dataResult = await connection.query(query);
      final dataRows = dataResult.map((row) => row.toColumnMap()).toList();
      
      final minWidths = columns.map<double>((col) {
        return _getTextWidth(col['name']!, const TextStyle(fontWeight: FontWeight.bold)) + 34.0; // Increased buffer
      }).toList();
      
      final initialWidths = _calculateColumnWidths(columns, dataRows, minWidths);

      if (mounted) {
        setState(() {
          _columns = columns;
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
          _error = '데이터 로딩 실패: $e';
        });
      }
    } finally {
      await connection?.close();
    }
  }
  
  List<double> _calculateColumnWidths(List<Map<String, String>> columns, List<Map<String, dynamic>> rows, List<double> minWidths) {
    final List<double> widths = [];
    final columnsAndActions = [...columns, {'name': '작업'}];

    for (int i = 0; i < columnsAndActions.length; i++) {
        if (i < columns.length) { // Regular column
            double maxWidth = minWidths[i]; // Start with min width (header width + padding)
            final colName = columns[i]['name']!;
            for (var row in rows) {
                final value = row[colName]?.toString() ?? 'NULL';
                final cellWidth = _getTextWidth(value, const TextStyle()) + 34.0; // Increased buffer
                maxWidth = max(maxWidth, cellWidth);
            }
            widths.add(maxWidth);
        } else { // Actions column
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
    Future<void> Function(PostgreSQLConnection) operation,
    String successMessage,
  ) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final connection = await _getConnection();
      await operation(connection);
      await connection.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('작업 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      await _loadTableData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.table} - 데이터 편집'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: '새로고침', onPressed: _loadTableData),
          IconButton(icon: const Icon(Icons.add), tooltip: '행 추가', onPressed: () => _showEditRowDialog(null)),
          IconButton(icon: const Icon(Icons.add_box_outlined), tooltip: '열 추가', onPressed: _showAddColumnDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null 
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _columns.isEmpty 
                  ? const Center(child: Text('테이블에 열이 없습니다. 열을 추가하세요.'))
                  : Column(
                      children: [
                        _buildHeader(),
                        _buildBody(),
                      ],
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
          ..._columns.asMap().entries.map((entry) {
            final i = entry.key;
            final col = entry.value;
            return Stack(
              children: [
                Container(
                  width: _columnWidths[i],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
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
                          PopupMenuItem(value: 'edit', child: Text('수정')),
                          // 다른 메뉴 항목들...
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
                          PopupMenuItem(value: 'edit', child: Text('수정')),
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
                        final newWidth = _columnWidths[i] + details.delta.dx;
                        _columnWidths[i] = max(newWidth, _minColumnWidths[i]);
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
            child: const Text('작업', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  int? _selectedColumnIndex;

  void _selectColumn(int index) {
    setState(() {
      if (_selectedColumnIndex == index) {
        // 같은 컬럼을 다시 클릭하면 선택 해제
        _selectedColumnIndex = null;
      } else {
        // 다른 컬럼 클릭 시 선택 변경
        _selectedColumnIndex = index;
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
    return Container(
      decoration: BoxDecoration(
        color: rowIndex.isOdd ? Colors.grey.withOpacity(0.1) : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          ..._columns.asMap().entries.map((entry) {
            final colIndex = entry.key;
            final col = entry.value;
            final value = rowData[col['name']];
            final bool isSelected = _selectedColumnIndex == colIndex; // 컬럼 선택 상태

            return Container(
              width: _columnWidths[colIndex],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.2) : null,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text(value?.toString() ?? 'NULL'),
            );
          }).toList(),
          Container(
            width: _columnWidths.last,
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
      'VARCHAR(255)', 'TEXT', 'INTEGER', 'BIGINT', 'NUMERIC',
      'BOOLEAN', 'DATE', 'TIMESTAMP', 'JSON', 'JSONB'
    ];
    final List<String> commonConstraints = ['NOT NULL', 'UNIQUE', 'PRIMARY KEY', 'DEFAULT', 'CHECK', 'REFERENCES'];

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
                case 'DEFAULT': return '기본값';
                case 'CHECK': return '조건 (예: price > 0)';
                case 'REFERENCES': return '참조 테이블(열)';
                default: return '';
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
              title: const Text('새 열 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: '열 이름', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedDataType,
                      hint: const Text('데이터 타입 선택'),
                      items: dataTypes.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                      onChanged: (newValue) => setStateInDialog(() => selectedDataType = newValue),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('제약조건', style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          hint: const Text('추가'),
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
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
                ElevatedButton(
                  onPressed: () {
                    final columnName = nameController.text.trim();
                    if (columnName.isEmpty || selectedDataType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('열 이름과 데이터 타입은 필수입니다.'), backgroundColor: Colors.red));
                      return;
                    }
                    Navigator.pop(dialogContext);
                    final constraintsString = buildConstraintsString();
                    final query = 'ALTER TABLE "${widget.table}" ADD COLUMN "$columnName" $selectedDataType $constraintsString';
                    _performOperation((conn) => conn.query(query), '열이 추가되었습니다.');
                  },
                  child: const Text('추가'),
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
      'VARCHAR(255)', 'TEXT', 'INTEGER', 'BIGINT', 'NUMERIC',
      'BOOLEAN', 'DATE', 'TIMESTAMP', 'JSON', 'JSONB'
    ];
    String? selectedDataType = columnData['type'] as String?;
    selectedDataType = (selectedDataType != null && dataTypes.contains(selectedDataType))
        ? selectedDataType
        : dataTypes.first;

    final List<Map<String, dynamic>> constraints = [];

    // 기존 제약조건이 있다면 초기화 (null 체크 후 적용 필요)
    if (columnData['constraints'] != null) {
      for (var c in columnData['constraints'] as List<Map<String, dynamic>>) {
        constraints.add({
          'type': c['type'],
          'controller': TextEditingController(text: c['value'] ?? ''),
        });
      }
    }

    final List<String> commonConstraints = ['NOT NULL', 'UNIQUE', 'PRIMARY KEY', 'DEFAULT', 'CHECK', 'REFERENCES'];

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
                case 'DEFAULT': return '기본값';
                case 'CHECK': return '조건 (예: price > 0)';
                case 'REFERENCES': return '참조 테이블(열)';
                default: return '';
              }
            }

            String buildConstraintsString() {
              // 수정 시 제약조건 변경을 위한 구문 생성 참고용 (실제 쿼리는 더 복잡할 수 있음)
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
              title: const Text('열 수정'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: '열 이름', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedDataType,
                      hint: const Text('데이터 타입 선택'),
                      items: dataTypes.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                      onChanged: (newValue) => setStateInDialog(() => selectedDataType = newValue),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('제약조건', style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          hint: const Text('추가'),
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
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
                ElevatedButton(
                  onPressed: () {
                    final columnName = nameController.text.trim();
                    if (columnName.isEmpty || selectedDataType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('열 이름과 데이터 타입은 필수입니다.'), backgroundColor: Colors.red));
                      return;
                    }
                    Navigator.pop(dialogContext);
                    final constraintsString = buildConstraintsString();
                    // 수정 쿼리 예시 (데이터 타입 변경과 제약조건 적용)
                    final query =
                        'ALTER TABLE "${widget.table}" ALTER COLUMN "$columnName" TYPE $selectedDataType, '
                        'ALTER COLUMN "$columnName" SET $constraintsString';
                    _performOperation((conn) => conn.query(query), '열이 수정되었습니다.');
                  },
                  child: const Text('수정'),
                ),
              ],
            );
          },
        );
      },
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
        title: Text(isNewRow ? '새 행 추가' : '행 편집'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(controller: entry.value, decoration: InputDecoration(labelText: entry.key, border: const OutlineInputBorder())),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final values = controllers.map<String, dynamic>((key, value) {
                final text = value.text;
                return MapEntry(key, text.isEmpty ? null : text);
              });

              if (isNewRow) {
                final query = values.isEmpty
                    ? 'INSERT INTO "${widget.table}" DEFAULT VALUES'
                    : 'INSERT INTO "${widget.table}" (${values.keys.map((k) => '"$k"').join(',')}) VALUES (${values.keys.map((k) => '@$k').join(',')})';
                _performOperation(
                    (conn) => conn.query(query, substitutionValues: values.isEmpty ? null : values),
                    '행이 추가되었습니다.');
              } else {
                if (pkColName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류: 기본 키가 없어 수정할 수 없습니다.'), backgroundColor: Colors.red));
                  return;
                }
                final setClauses = values.keys.map((k) => '"$k" = @$k').join(',');
                final query = 'UPDATE "${widget.table}" SET $setClauses WHERE "$pkColName" = @primaryKeyValue';
                values['primaryKeyValue'] = rowData![pkColName];
                _performOperation((conn) => conn.query(query, substitutionValues: values), '행이 수정되었습니다.');
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> row) {
    if (_primaryKeyColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류: 기본 키가 없어 삭제할 수 없습니다.'), backgroundColor: Colors.red));
      return;
    }
    final pkValue = row[_primaryKeyColumn!];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('행 삭제'),
        content: Text('이 행을 삭제하시겠습니까? (기본 키: $pkValue)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final query = 'DELETE FROM "${widget.table}" WHERE "$_primaryKeyColumn" = @pkValue';
              _performOperation(
                (conn) => conn.query(query, substitutionValues: {'pkValue': pkValue}),
                '행이 삭제되었습니다.',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
