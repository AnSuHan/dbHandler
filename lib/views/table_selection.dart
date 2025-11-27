import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../l10n/LocalizationManager.dart';
import '../sqflite/models/server_model.dart';
import '../stateManagement/getx/TableSelectionController.dart';

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
    // GetX Controller 초기화
    final controller = Get.put(
      TableSelectionController(
        server: server,
        database: database,
      ),
      tag: '${server.id}_$database',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${intl.getString((l) => l.database)} - $database'),
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
                            Text(
                              intl.getString((l) => l.selectedDatabase),
                              style: const TextStyle(
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
                        onPressed: () => showCreateTableDialog(context, controller),
                        icon: const Icon(Icons.add),
                        label: Text(intl.getString((l) => l.newTable)),
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
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.tables.isEmpty) {
                  return Center(
                    child: Text(
                      intl.getString((l) => l.noTableExist),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  itemCount: controller.tables.length,
                  itemBuilder: (context, index) {
                    return Obx(() {
                      final table = controller.tables[index];
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
                            subtitle: Text('${intl.getString((l) => l.column)}: $columnCount, ${intl.getString((l) => l.row)}: $rowCount'),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  showEditTableDialog(context, controller, tableName);
                                } else if (value == 'delete') {
                                  showDeleteTableDialog(context, controller, tableName);
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit, size: 20),
                                      const SizedBox(width: 8),
                                      Text(intl.getString((l) => l.edit)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete, size: 20, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text(intl.getString((l) => l.delete), style: const TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void showCreateTableDialog(BuildContext ctx, TableSelectionController controller) {
    final nameController = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.createNewTable)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: intl.getString((l) => l.tableName),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((l) => l.cancel)),
          ),
          ElevatedButton(
            onPressed: () {
              final tableName = nameController.text.trim();
              if (tableName.isNotEmpty) {
                Navigator.pop(dialogContext);
                controller.createTable(tableName);
              }
            },
            child: Text(intl.getString((l) => l.create)),
          ),
        ],
      ),
    );
  }

  void showEditTableDialog(BuildContext ctx, TableSelectionController controller, String oldName) {
    final nameController = TextEditingController(text: oldName);
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.modifyTableName)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: intl.getString((l) => l.newTableName),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((l) => l.cancel)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                Navigator.pop(dialogContext);
                controller.renameTable(oldName, newName);
              }
            },
            child: Text(intl.getString((l) => l.save)),
          ),
        ],
      ),
    );
  }

  void showDeleteTableDialog(BuildContext ctx, TableSelectionController controller, String tableName) {
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.deleteTable)),
        content: Text(intl.getStringWithParams((l, tableName) => l.deleteTableConfirm(tableName), tableName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((l) => l.cancel)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.deleteTable(tableName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(intl.getString((l) => l.delete)),
          ),
        ],
      ),
    );
  }
}