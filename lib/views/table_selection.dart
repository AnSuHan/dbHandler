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

  Future<void> _loadTables() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final host = widget.server['address'].split(':')[0];
      final port = int.parse(widget.server['address'].split(':')[1]);

      final connection = PostgreSQLConnection(
        host,
        port,
        widget.database, // 선택된 데이터베이스 사용
        username: 'postgres',
        password: '0000',
      );
      await connection.open();

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

      setState(() {
        _tables = results.map((row) {
          return {
            'name': row[0] as String,
            'columns': row[1] as int,
          };
        }).toList();
        _isLoading = false;
      });

      await connection.close();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('테이블 목록을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.database} - 테이블 선택'),
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      itemCount: _tables.length,
                      itemBuilder: (context, index) {
                        final table = _tables[index];
                        final tableName = table['name'] as String;
                        final columnCount = table['columns'] as int;

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
                              subtitle: Text('$columnCount 개의 컬럼'),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    // _showEditTableDialog(table);
                                  } else if (value == 'delete') {
                                    // _showDeleteTableDialog(table);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 테이블 생성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: '테이블 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // 컬럼 추가 로직
              },
              icon: const Icon(Icons.add),
              label: const Text('컬럼 추가'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('테이블이 생성되었습니다.')),
              );
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }
}
