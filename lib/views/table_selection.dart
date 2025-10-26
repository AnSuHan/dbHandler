import 'package:flutter/material.dart';
import 'database_selection.dart';

class TableSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> server;
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
        title: Text('${(widget.database as Database).name} - 테이블 선택'),
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
                              (widget.database as Database).name,
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
                            'table': {
                              'name': table.name,
                              'rows': table.rows,
                              'columns': table.columns,
                            },
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
                          table.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${table.rows.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} 행 • ${table.columns} 열',
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditTableDialog(table);
                            } else if (value == 'delete') {
                              _showDeleteTableDialog(table);
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

  void _showEditTableDialog(TableInfo table) {
    final nameController = TextEditingController(text: table.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테이블 수정'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '테이블 이름',
            border: OutlineInputBorder(),
          ),
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
                const SnackBar(
                  content: Text('테이블이 수정되었습니다.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTableDialog(TableInfo table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테이블 삭제'),
        content: Text('${table.name} 테이블을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('테이블이 삭제되었습니다.'),
                  backgroundColor: Colors.green,
                ),
              );
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
