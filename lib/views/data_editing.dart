import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';

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
                  child: Text(
                    col['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
            return Container(
              width: _columnWidths[colIndex],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
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

    final List<String> dataTypes = [
      'VARCHAR(255)', 'TEXT', 'INTEGER', 'BIGINT', 'NUMERIC',
      'BOOLEAN', 'DATE', 'TIMESTAMP', 'JSON', 'JSONB'
    ];
    final List<String> commonConstraints = ['NOT NULL', 'UNIQUE', 'PRIMARY KEY', 'DEFAULT', 'CHECK', 'REFERENCES'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        List<Map<String, dynamic>> dialogConstraints = [];

        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            void addConstraint(String constraint) {
              setStateInDialog(() {
                dialogConstraints.add({
                  'type': constraint,
                  'value': '',
                  'controller': TextEditingController(), // 컨트롤러를 데이터에 포함
                });
              });
            }

            void removeConstraint(int index) {
              setStateInDialog(() {
                dialogConstraints[index]['controller']?.dispose();
                dialogConstraints.removeAt(index);
              });
            }

            void updateConstraintValue(int index, String newValue) {
              dialogConstraints[index]['value'] = newValue;
              // setState 호출하지 않음 - 컨트롤러가 자동으로 처리
            }

            bool needsAdditionalInput(String constraintType) {
              return ['DEFAULT', 'CHECK', 'REFERENCES'].contains(constraintType);
            }

            String buildConstraintString(Map<String, dynamic> constraint) {
              final type = constraint['type']!;
              final value = constraint['value'] ?? '';

              switch (type) {
                case 'NOT NULL':
                  return 'NOT NULL';
                case 'UNIQUE':
                  return 'UNIQUE';
                case 'PRIMARY KEY':
                  return 'PRIMARY KEY';
                case 'DEFAULT':
                  return value.isNotEmpty ? 'DEFAULT $value' : 'DEFAULT';
                case 'CHECK':
                  return value.isNotEmpty ? 'CHECK ($value)' : 'CHECK';
                case 'REFERENCES':
                  return value.isNotEmpty ? 'REFERENCES $value' : 'REFERENCES';
                default:
                  return type;
              }
            }

            bool validateConstraints() {
              for (var constraint in dialogConstraints) {
                final type = constraint['type']!;
                final value = constraint['value'] ?? '';

                if (needsAdditionalInput(type) && value.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$type 제약조건은 추가 값이 필요합니다.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return false;
                }

                // CHECK 문법 검증
                if (type == 'CHECK' && value.isNotEmpty) {
                  if (!value.contains('>') && !value.contains('<') &&
                      !value.contains('=') && !value.contains('IN') &&
                      !value.contains('LIKE') && !value.contains('BETWEEN')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('CHECK 제약조건에 유효한 조건식을 입력하세요. (예: age > 18)'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return false;
                  }
                }

                // REFERENCES 문법 검증
                if (type == 'REFERENCES' && value.isNotEmpty) {
                  if (!value.contains('(') || !value.contains(')')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('REFERENCES 형식이 올바르지 않습니다. (예: table_name(column_name))'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return false;
                  }
                }
              }
              return true;
            }

            return AlertDialog(
              title: const Text('새 열 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '열 이름',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedDataType,
                      hint: const Text('데이터 타입 선택'),
                      items: dataTypes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setStateInDialog(() => selectedDataType = newValue);
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          "제약조건",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          hint: const Icon(Icons.add_circle_outline),
                          underline: const SizedBox(),
                          items: commonConstraints.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              addConstraint(newValue);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(dialogConstraints.length, (index) {
                      final constraint = dialogConstraints[index];
                      final constraintType = constraint['type']!;
                      final needsInput = needsAdditionalInput(constraintType);
                      final controller = constraint['controller'] as TextEditingController;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      constraintType,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => removeConstraint(index),
                                  ),
                                ],
                              ),
                              if (needsInput) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: _getInputLabel(constraintType),
                                    hintText: _getInputHint(constraintType),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (newValue) {
                                    updateConstraintValue(index, newValue);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // 컨트롤러 정리
                    for (var constraint in dialogConstraints) {
                      constraint['controller']?.dispose();
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final columnName = nameController.text.trim();
                    final columnType = selectedDataType;

                    if (columnName.isEmpty || columnType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('열 이름과 데이터 타입은 필수입니다.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (!validateConstraints()) {
                      return;
                    }

                    final allConstraints = dialogConstraints
                        .map((c) => buildConstraintString(c))
                        .join(' ');

                    // 컨트롤러 정리
                    for (var constraint in dialogConstraints) {
                      constraint['controller']?.dispose();
                    }

                    Navigator.pop(dialogContext);
                    String query = 'ALTER TABLE "${widget.table}" ADD COLUMN "$columnName" $columnType';
                    if (allConstraints.isNotEmpty) {
                      query += ' $allConstraints';
                    }
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

  String _getInputLabel(String constraintType) {
    switch (constraintType) {
      case 'DEFAULT':
        return '기본값';
      case 'CHECK':
        return '조건식';
      case 'REFERENCES':
        return '참조 테이블(컬럼)';
      default:
        return '값';
    }
  }

  String _getInputHint(String constraintType) {
    switch (constraintType) {
      case 'DEFAULT':
        return "예: 0, 'default', CURRENT_TIMESTAMP";
      case 'CHECK':
        return '예: age > 18, status IN (\'active\', \'inactive\')';
      case 'REFERENCES':
        return '예: users(id)';
      default:
        return '';
    }
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
