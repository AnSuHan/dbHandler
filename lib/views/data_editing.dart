import 'package:flutter/material.dart';

class DataEditingScreen extends StatefulWidget {
  final dynamic server;
  final dynamic database;
  final dynamic table;

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
  final List<Map<String, dynamic>> data = [
    {'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'age': 28, 'city': 'Seoul', 'status': 'Active'},
    {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com', 'age': 32, 'city': 'Busan', 'status': 'Active'},
    {'id': 3, 'name': 'Bob Johnson', 'email': 'bob@example.com', 'age': 45, 'city': 'Incheon', 'status': 'Inactive'},
    {'id': 4, 'name': 'Alice Williams', 'email': 'alice@example.com', 'age': 29, 'city': 'Seoul', 'status': 'Active'},
    {'id': 5, 'name': 'Charlie Brown', 'email': 'charlie@example.com', 'age': 35, 'city': 'Daegu', 'status': 'Active'},
  ];

  @override
  Widget build(BuildContext context) {
    final columns = data.isEmpty ? [] : data[0].keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.table.name} - 데이터 편집'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '행 추가',
            onPressed: () {
              _showAddRowDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '저장',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('변경사항이 저장되었습니다.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.dns, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  widget.server.name,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Icon(Icons.chevron_right, size: 16),
                Icon(Icons.storage, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  widget.database.name,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Icon(Icons.chevron_right, size: 16),
                Icon(Icons.table_chart, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  widget.table.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Table
          Expanded(
            child: data.isEmpty
                ? const Center(
                    child: Text('데이터가 없습니다.'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 40,
                        headingRowColor: MaterialStateProperty.all(
                          Colors.grey[100],
                        ),
                        columns: [
                          const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                          ...columns.map(
                            (column) => DataColumn(
                              label: Text(
                                column,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const DataColumn(label: Text('작업', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: data.map((row) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  row['id'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...columns.map(
                                (column) => DataCell(
                                  _buildEditableCell(row, column),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      color: const Color(0xFF3B82F6),
                                      onPressed: () {
                                        _showEditRowDialog(row);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      color: const Color(0xFFEF4444),
                                      onPressed: () {
                                        _showDeleteConfirmDialog(row);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCell(Map<String, dynamic> row, String column) {
    final value = row[column];
    if (value == null) {
      return const Text('-');
    }

    return GestureDetector(
      onTap: () {
        _showEditCellDialog(row, column);
      },
      child: Text(
        value.toString(),
        style: const TextStyle(color: Color(0xFF3B82F6)),
      ),
    );
  }

  void _showEditCellDialog(Map<String, dynamic> row, String column) {
    final controller = TextEditingController(text: row[column].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$column 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
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
              setState(() {
                row[column] = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showAddRowDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 행 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextField(
                decoration: InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 8),
              const TextField(
                decoration: InputDecoration(labelText: '이메일'),
              ),
              const SizedBox(height: 8),
              const TextField(
                decoration: InputDecoration(labelText: '나이'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                data.add({
                  'id': data.length + 1,
                  'name': 'New User',
                  'email': 'new@example.com',
                  'age': 0,
                  'city': 'Seoul',
                  'status': 'Active',
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('새 행이 추가되었습니다.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showEditRowDialog(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('행 편집'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: row.keys.map((key) {
              final controller = TextEditingController(text: row[key].toString());
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: key,
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('행 삭제'),
        content: const Text('이 행을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                data.remove(row);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('행이 삭제되었습니다.'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

