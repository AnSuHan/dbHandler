import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:get/get.dart';

import '../sqflite/models/server_model.dart';

/// getX 상태 관리
class TableSelectionScreen extends StatelessWidget {
  final ServerModel server;
  final String database;

  const TableSelectionScreen({
    super.key,
    required this.server,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    // GetX Controller 인라인 정의
    final tables = <Map<String, dynamic>>[].obs;
    final isLoading = true.obs;

    Future<PostgreSQLConnection> getConnection() async {
      final host = server.address.split(':')[0];
      final port = int.parse(server.address.split(':')[1]);
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

    Future<void> loadRowCount(int index) async {
      final tableName = tables[index]['name'] as String;
      PostgreSQLConnection? connection;
      try {
        connection = await getConnection();
        final rowCountResult = await connection.query('SELECT COUNT(*) FROM "$tableName"');
        tables[index]['rows'] = rowCountResult.first[0] as int;
        tables.refresh();
      } catch (e) {
        tables[index]['rows'] = '오류';
        tables.refresh();
      } finally {
        await connection?.close();
      }
    }

    Future<void> loadAllRowCounts() async {
      List<Future> futures = [];
      for (int i = 0; i < tables.length; i++) {
        futures.add(loadRowCount(i));
      }
      await Future.wait(futures);
    }

    Future<void> loadTables(BuildContext ctx) async {
      isLoading.value = true;

      try {
        final connection = await getConnection();
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

        tables.value = results.map((row) {
          return {
            'name': row[0] as String,
            'columns': row[1] as int,
            'rows': '조회 중...',
          };
        }).toList();

        isLoading.value = false;
        loadAllRowCounts();

        await connection.close();
      } catch (e) {
        isLoading.value = false;
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('테이블 목록을 불러오는데 실패했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    Future<void> performTableOperation(
        BuildContext ctx,
        Future<void> Function(PostgreSQLConnection) operation,
        String successMessage,
        String failureMessage,
        ) async {
      isLoading.value = true;

      try {
        final connection = await getConnection();
        await operation(connection);
        await connection.close();

        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('$failureMessage: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      await loadTables(ctx);
    }

    Future<void> createTable(BuildContext ctx, String tableName) async {
      await performTableOperation(
        ctx,
            (conn) => conn.query('CREATE TABLE "$tableName" (id SERIAL PRIMARY KEY);'),
        '테이블 $tableName 생성 완료',
        '테이블 생성 실패',
      );
    }

    Future<void> renameTable(BuildContext ctx, String oldName, String newName) async {
      await performTableOperation(
        ctx,
            (conn) => conn.query('ALTER TABLE "$oldName" RENAME TO "$newName"'),
        '테이블 이름이 $newName (으)로 변경되었습니다.',
        '테이블 이름 변경 실패',
      );
    }

    Future<void> deleteTable(BuildContext ctx, String tableName) async {
      await performTableOperation(
        ctx,
            (conn) => conn.query('DROP TABLE "$tableName"'),
        '$tableName 테이블이 삭제되었습니다.',
        '테이블 삭제 실패',
      );
    }

    void showCreateTableDialog(BuildContext ctx) {
      final nameController = TextEditingController();
      showDialog(
        context: ctx,
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
                  createTable(ctx, tableName);
                }
              },
              child: const Text('생성'),
            ),
          ],
        ),
      );
    }

    void showEditTableDialog(BuildContext ctx, String oldName) {
      final nameController = TextEditingController(text: oldName);
      showDialog(
        context: ctx,
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
                  renameTable(ctx, oldName, newName);
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      );
    }

    void showDeleteTableDialog(BuildContext ctx, String tableName) {
      showDialog(
        context: ctx,
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
                deleteTable(ctx, tableName);
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

    // 초기 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadTables(context);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('데이터베이스 - $database'),
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
                              database,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => showCreateTableDialog(context),
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
              child: Obx(() {
                if (isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (tables.isEmpty) {
                  return const Center(
                    child: Text(
                      '테이블이 없습니다. 새 테이블을 추가해주세요.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  itemCount: tables.length,
                  itemBuilder: (context, index) {
                    final table = tables[index];
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
                              'server': server,
                              'database': database,
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
                                showEditTableDialog(context, tableName);
                              } else if (value == 'delete') {
                                showDeleteTableDialog(context, tableName);
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
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}