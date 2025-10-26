import 'package:flutter/material.dart';

class DatabaseSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> server;

  const DatabaseSelectionScreen({super.key, required this.server});

  @override
  State<DatabaseSelectionScreen> createState() => _DatabaseSelectionScreenState();
}

class _DatabaseSelectionScreenState extends State<DatabaseSelectionScreen> {
  final List<Database> databases = [
    Database(name: 'ecommerce', tables: 12, size: '2.3 GB'),
    Database(name: 'analytics', tables: 45, size: '15.7 GB'),
    Database(name: 'users', tables: 8, size: '850 MB'),
    Database(name: 'logs', tables: 23, size: '8.1 GB'),
    Database(name: 'test_db', tables: 3, size: '150 MB'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('데이터베이스 선택 - ${widget.server['name']}'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B5CF6), Color(0xFFF8F9FA)],
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
                      const Icon(Icons.info_outline, size: 24, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '연결된 서버',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              widget.server['name'],
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
                          _showCreateDatabaseDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('새 데이터베이스'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
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
                itemCount: databases.length,
                itemBuilder: (context, index) {
                  final database = databases[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/table-selection',
                          arguments: {
                            'server': widget.server,
                            'database': database,
                          },
                        );
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF8B5CF6),
                          radius: 24,
                          child: const Icon(
                            Icons.storage,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(database.name),
                        subtitle: Text('${database.tables} 개의 테이블'),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditDatabaseDialog(database);
                            } else if (value == 'delete') {
                              _showDeleteDatabaseDialog(database);
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

  void _showEditDatabaseDialog(Database database) {
    final nameController = TextEditingController(text: database.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터베이스 수정'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '데이터베이스 이름',
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
                  content: Text('데이터베이스가 수정되었습니다.'),
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

  void _showDeleteDatabaseDialog(Database database) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터베이스 삭제'),
        content: Text('${database.name} 데이터베이스를 삭제하시겠습니까?'),
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
                  content: Text('데이터베이스가 삭제되었습니다.'),
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

  void _showCreateDatabaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 데이터베이스 생성'),
        content: const TextField(
          decoration: InputDecoration(
            labelText: '데이터베이스 이름',
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
                const SnackBar(content: Text('데이터베이스가 생성되었습니다.')),
              );
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }
}

class Database {
  final String name;
  final int tables;
  final String size;

  Database({
    required this.name,
    required this.tables,
    required this.size,
  });
}
