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
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, String>> _columns = [];
  String? _primaryKeyColumn;

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  Future<PostgreSQLConnection> _getConnection() async {
    final host = widget.server['address'].split(':')[0];
    final port = int.parse(widget.server['address'].split(':')[1]);
    final connection = PostgreSQLConnection(
      host,
      port,
      widget.database,
      username: 'postgres',
      password: '0000',
    );
    await connection.open();
    return connection;
  }

  Future<void> _loadTableData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final connection = await _getConnection();

      // Fetch columns
      final columnResults = await connection.query(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' AND table_name = @tableName ORDER BY ordinal_position",
        substitutionValues: {'tableName': widget.table},
      );
      final columns = columnResults
          .map((row) => {'name': row[0] as String, 'type': row[1] as String})
          .toList();

      // Fetch primary key
      final pkResult = await connection.query(
        "SELECT kcu.column_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_name = @tableName",
        substitutionValues: {'tableName': widget.table},
      );
      final primaryKey = pkResult.isNotEmpty ? pkResult.first[0] as String : null;

      // Fetch rows
      String query = 'SELECT * FROM "${widget.table}"';
      if (primaryKey != null) {
        query += ' ORDER BY "$primaryKey" ASC';
      }
      final dataResult = await connection.query(query);
      final dataRows = dataResult.map((row) => row.toColumnMap()).toList();

      if (mounted) {
        setState(() {
          _columns = columns;
          _primaryKeyColumn = primaryKey;
          _rows = dataRows;
          _isLoading = false;
        });
      }

      await connection.close();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로딩 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _loadTableData,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '행 추가',
            onPressed: () => _showEditRowDialog(null),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('데이터가 없습니다. 행을 추가하세요.'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      columns: _columns
                          .map((c) => DataColumn(label: Text(c['name']!)))
                          .toList()
                        ..add(const DataColumn(label: Text('작업'))),
                      rows: _rows.map((row) {
                        return DataRow(
                          cells: _columns.map((col) {
                            final value = row[col['name']!];
                            return DataCell(Text(value?.toString() ?? 'NULL'));
                          }).toList()
                            ..add(DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showEditRowDialog(row),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmDialog(row),
                                  ),
                                ],
                              ),
                            )),
                        );
                      }).toList(),
                    ),
                  ),
                ),
    );
  }

  void _showEditRowDialog(Map<String, dynamic>? rowData) {
    final isNewRow = rowData == null;
    final controllers = <String, TextEditingController>{};
    final pkColName = _primaryKeyColumn;

    for (var col in _columns) {
      final colName = col['name']!;
      // Don't create an input for a serial primary key on new rows
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
                child: TextField(
                  controller: entry.value,
                  decoration: InputDecoration(labelText: entry.key, border: const OutlineInputBorder()),
                ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('오류: 기본 키가 없어 수정할 수 없습니다.'), backgroundColor: Colors.red),
                  );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류: 기본 키가 없어 삭제할 수 없습니다.'), backgroundColor: Colors.red),
      );
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
