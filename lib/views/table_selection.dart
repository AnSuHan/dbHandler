import 'package:flutter/material.dart';

class TableSelectionScreen extends StatefulWidget {
  final dynamic server;
  final dynamic database;

  const TableSelectionScreen({
    super.key,
    required this.server,
    required this.database,
  });

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  final List<TableInfo> tables = [
    TableInfo(name: 'users', rows: 15234, columns: 8),
    TableInfo(name: 'orders', rows: 52341, columns: 12),
    TableInfo(name: 'products', rows: 4523, columns: 15),
    TableInfo(name: 'categories', rows: 234, columns: 5),
    TableInfo(name: 'payments', rows: 89234, columns: 10),
    TableInfo(name: 'reviews', rows: 11234, columns: 7),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.database.name} - 테이블 선택'),
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
                              widget.database.name,
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  final table = tables[index];
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
                            'table': table,
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.table_chart,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    table.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${table.rows.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} 행',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${table.columns} 열',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.grey),
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

class TableInfo {
  final String name;
  final int rows;
  final int columns;

  TableInfo({
    required this.name,
    required this.rows,
    required this.columns,
  });
}

