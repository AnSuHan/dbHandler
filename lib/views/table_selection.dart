import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';

class TableSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> server;
  final String database;

  const TableSelectionScreen({
    super.key,
    required this.server,
    required this.database,
  });

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
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

  Future<void> _loadTables() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final connection = await _getConnection();
      final results = await connection.query('''
        SELECT
            t.table_name,
            COUNT(c.column_name) AS column_count
        FROM
            information_schema.tables AS t
        LEFT JOIN
            information_schema.columns AS c ON t.table_schema = c.table_schema AND t.table_name = c.table_name
        WHERE
            t.table_schema NOT IN ('pg_catalog', 'information_schema') AND t.table_type = 'BASE TABLE'
        GROUP BY
            t.table_name
        ORDER BY
            t.table_name;
      ''');

      if (mounted) {
        setState(() {
          _tables = results.map((row) {
            return {
              'name': row[0] as String,
              'columns': row[1] as int,
              'rows': '조회 중...',
            };
          }).toList();
          _isLoading = false;
        });
        _loadAllRowCounts();
      }
      await connection.close();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('테이블 목록을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _loadAllRowCounts() async {
    List<Future> futures = [];
    for (int i = 0; i < _tables.length; i++) {
      futures.add(_loadRowCount(i));
    }
    await Future.wait(futures);
  }

  Future<void> _loadRowCount(int index) async {
    final tableName = _tables[index]['name'] as String;
    PostgreSQLConnection? connection;
    try {
      connection = await _getConnection();
      final rowCountResult = await connection.query('SELECT COUNT(*) FROM \"$tableName\"');
      
      if (mounted) {
        setState(() {
          _tables[index]['rows'] = rowCountResult.first[0] as int;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tables[index]['rows'] = '오류';
        });
      }
    } finally {
      await connection?.close();
    }
  }


  Future<void> _performTableOperation(
    Future<void> Function(PostgreSQLConnection) operation,
    String successMessage,
    String failureMessage,
  ) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

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
          SnackBar(content: Text('$failureMessage: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      await _loadTables();
    }
  }

  Future<void> _createTable(String tableName) async {
    await _performTableOperation(
      (conn) => conn.query('CREATE TABLE "$tableName" (id SERIAL PRIMARY KEY);'),
      '테이블 $tableName 생성 완료',
      '테이블 생성 실패',
    );
  }

  Future<void> _renameTable(String oldName, String newName) async {
    await _performTableOperation(
      (conn) => conn.query('ALTER TABLE "$oldName" RENAME TO "$newName"'),
      '테이블 이름이 $newName (으)로 변경되었습니다.',
      '테이블 이름 변경 실패',
    );
  }

  Future<void> _deleteTable(String tableName) async {
    await _performTableOperation(
      (conn) => conn.query('DROP TABLE "$tableName"'),
      '$tableName 테이블이 삭제되었습니다.',
      '테이블 삭제 실패',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('데이터베이스 - ${widget.database}'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10B981), Color(0xFFF8F9FA)],
            stops: [0.0, 0.1],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.storage, color: Color(0xFF10B981), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '선택된 데이터베이스',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              widget.database,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showCreateTableDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('새 테이블'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tables.isEmpty
                      ? const Center(
                          child: Text(
                            '테이블이 없습니다. 새 테이블을 추가해주세요.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: _tables.length,
                          itemBuilder: (context, index) {
                            final table = _tables[index];
                            final tableName = table['name'] as String;
                            final columnCount = table['columns'] as int;
                            final rowCount = table['rows'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/data-editing',
                                    arguments: {
                                      'server': widget.server,
                                      'database': widget.database,
                                      'table': tableName,
                                    },
                                  );
                                },
                                child: ListTile(
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0x1A10B981),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.table_chart,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  title: Text(
                                    tableName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text('컬럼: $columnCount, 행: $rowCount'),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditTableDialog(tableName);
                                      } else if (value == 'delete') {
                                        _showDeleteTableDialog(tableName);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('수정'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('삭제', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTableDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('새 테이블 생성'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '테이블 이름',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final tableName = nameController.text.trim();
              if (tableName.isNotEmpty) {
                Navigator.pop(dialogContext);
                _createTable(tableName);
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  void _showEditTableDialog(String oldName) {
    final nameController = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('테이블 이름 수정'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '새 테이블 이름',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                Navigator.pop(dialogContext);
                _renameTable(oldName, newName);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTableDialog(String tableName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('테이블 삭제'),
        content: Text('$tableName 테이블을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteTable(tableName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
