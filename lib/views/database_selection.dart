import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';

class DatabaseSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> server;

  const DatabaseSelectionScreen({super.key, required this.server});

  @override
  State<DatabaseSelectionScreen> createState() => _DatabaseSelectionScreenState();
}

class _DatabaseSelectionScreenState extends State<DatabaseSelectionScreen> {
  List<Map<String, dynamic>> _databases = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  Future<PostgreSQLConnection> _getConnection(String database) async {
    final host = widget.server['address'].split(':')[0];
    final port = int.parse(widget.server['address'].split(':')[1]);
    final connection = PostgreSQLConnection(
      host,
      port,
      database,
      username: 'postgres',
      password: '0000',
    );
    await connection.open();
    return connection;
  }

  Future<void> _loadDatabases() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final connection = await _getConnection('postgres');
      final results = await connection.query('''
        SELECT d.datname, pg_size_pretty(pg_database_size(d.datname)) AS size
        FROM pg_database d
        WHERE d.datistemplate = false;
      ''');

      if (mounted) {
        setState(() {
          _databases = results.map((row) {
            return {
              'name': row[0] as String,
              'size': row[1] as String,
            };
          }).toList();
          _isLoading = false;
        });
      }
      await connection.close();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '서버에 연결할 수 없습니다. 주소와 포트를 확인하거나 서버 상태를 점검하세요.\n오류: $e';
        });
      }
    }
  }

  Future<void> _performDbOperation(
    Future<void> Function(PostgreSQLConnection) operation,
    String successMessage,
    String failureMessage,
  ) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final connection = await _getConnection('postgres');
      await operation(connection);
      await connection.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failureMessage: $e')),
        );
      }
    }

    if (mounted) {
      await _loadDatabases();
    }
  }

  Future<void> _createDatabase(String dbName) async {
    await _performDbOperation(
      (conn) => conn.query('CREATE DATABASE "$dbName"'),
      '데이터베이스 $dbName 생성 완료',
      '데이터베이스 생성 실패',
    );
  }

  Future<void> _renameDatabase(String oldName, String newName) async {
    await _performDbOperation(
      (conn) => conn.query('ALTER DATABASE "$oldName" RENAME TO "$newName"'),
      '데이터베이스 이름이 $newName (으)로 변경되었습니다.',
      '데이터베이스 이름 변경 실패',
    );
  }

  Future<void> _deleteDatabase(String dbName) async {
    await _performDbOperation(
      (conn) => conn.query('DROP DATABASE "$dbName"'),
      '$dbName 데이터베이스가 삭제되었습니다.',
      '데이터베이스 삭제 실패',
    );
  }

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
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('뒤로 가기'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
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
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            itemCount: _databases.length,
                            itemBuilder: (context, index) {
                              final db = _databases[index];
                              final dbName = db['name'] as String;
                              final dbSize = db['size'] as String;
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
                                        'database': dbName,
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
                                    title: Text(dbName),
                                    subtitle: Text(dbSize),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEditDatabaseDialog(dbName);
                                        } else if (value == 'delete') {
                                          _showDeleteDatabaseDialog(dbName);
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

  void _showCreateDatabaseDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('새 데이터베이스 생성'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '데이터베이스 이름',
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
              final dbName = nameController.text.trim();
              if (dbName.isNotEmpty) {
                Navigator.pop(dialogContext);
                _createDatabase(dbName);
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  void _showEditDatabaseDialog(String oldName) {
    final nameController = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('데이터베이스 이름 수정'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '새 데이터베이스 이름',
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
                _renameDatabase(oldName, newName);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDatabaseDialog(String dbName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('데이터베이스 삭제'),
        content: Text('$dbName 데이터베이스를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteDatabase(dbName);
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
