import 'package:flutter/material.dart';

class DatabaseSelectionScreen extends StatefulWidget {
  final dynamic server;

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
        title: Text('데이터베이스 선택 - ${widget.server.name}'),
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
                              widget.server.name,
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
                          // 새 데이터베이스 생성 로직
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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF8B5CF6),
                              radius: 24,
                              child: const Icon(
                                Icons.storage,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    database.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${database.tables} 개의 테이블',
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
                                  database.size,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '크기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
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

