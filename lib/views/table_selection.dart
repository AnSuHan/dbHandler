import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../l10n/LocalizationManager.dart';
import '../sqflite/models/server_model.dart';
import '../stateManagement/getx/TableSelectionController.dart';
import '../stateManagement/setState/join_definition.dart';
import 'unit/join_table_dialog.dart';

/// getX 상태 관리
class TableSelectionScreen extends StatefulWidget {
  final ServerModel server;
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
  late final TableSelectionController controller;
  // Worker들을 저장
  Worker? successWorker;
  Worker? errorWorker;

  @override
  void initState() {
    super.initState();

    // GetX Controller 초기화
    controller = Get.put(
      TableSelectionController(
        server: widget.server,
        database: widget.database,
      ),
      tag: '${widget.server.id}_${widget.database}',
    );

    // 메시지 리스너 추가 - initState에서 한 번만 등록
    successWorker = ever(controller.successMessage, (message) {
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        controller.successMessage.value = null;
      }
    });

    errorWorker = ever(controller.errorMessage, (message) {
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
        controller.errorMessage.value = null;
      }
    });
  }

  @override
  void dispose() {
    successWorker?.dispose();
    errorWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${intl.getString((l) => l.database)} - ${widget.database}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              controller.refreshTables();
            },
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).colorScheme.background,
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
                      Icon(Icons.storage, color: Theme.of(context).colorScheme.primary, size: 24),
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
                        onPressed: () => _showCreateJoinViewDialog(),
                        icon: const Icon(Icons.join_inner),
                        label: const Text('JOIN 뷰'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => showCreateTableDialog(context, controller),
                        icon: const Icon(Icons.add),
                        label: Text(intl.getString((l) => l.newTable)),
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

                final realTables = controller.tables;
                final joinDefs = controller.joinDefinitions;

                if (realTables.isEmpty && joinDefs.isEmpty) {
                  return Center(
                    child: Text(
                      intl.getString((l) => l.noTableExist),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final totalCount = realTables.length + joinDefs.length;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  itemCount: totalCount,
                  itemBuilder: (context, index) {
                    // 실제 테이블 먼저, 그 다음 JOIN 뷰
                    if (index < realTables.length) {
                      return _buildTableCard(index);
                    } else {
                      final joinIndex = index - realTables.length;
                      return _buildJoinViewCard(joinIndex);
                    }
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(int index) {
    return Obx(() {
      final table = controller.tables[index];
      final tableName = table['name'] as String;
      final tableSchema = table['schema'] as String? ?? 'public';
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
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.table_chart,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                  showEditTableDialog(context, controller, tableName, tableSchema);
                } else if (value == 'delete') {
                  showDeleteTableDialog(context, controller, tableName, tableSchema);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 8),
                      Flexible(child: Text(intl.getString((l) => l.edit), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Flexible(child: Text(intl.getString((l) => l.delete), style: const TextStyle(color: Colors.red), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildJoinViewCard(int joinIndex) {
    return Obx(() {
      if (joinIndex >= controller.joinDefinitions.length) return const SizedBox.shrink();
      final joinDef = controller.joinDefinitions[joinIndex];

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
                'table': joinDef.name,
                'joinDefinition': joinDef,
              },
            );
          },
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.join_inner,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
            title: Text(
              joinDef.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              joinDef.allTables.join(' + '),
              style: const TextStyle(fontSize: 13),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditJoinViewDialog(joinIndex, joinDef);
                } else if (value == 'delete') {
                  _showDeleteJoinViewDialog(joinIndex, joinDef);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 8),
                      Flexible(child: Text(intl.getString((l) => l.edit), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Flexible(child: Text(intl.getString((l) => l.delete), style: const TextStyle(color: Colors.red), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _showCreateJoinViewDialog() async {
    final availableTables = controller.tables
        .map((t) => t['name'] as String)
        .toList();

    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JOIN 뷰를 만들려면 테이블이 필요합니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showJoinTableDialog(
      context: context,
      dbHandler: controller.dbHandler,
      database: widget.database,
      availableTables: availableTables,
    );

    if (result != null) {
      controller.addJoinDefinition(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('JOIN 뷰 "${result.name}" 생성 완료'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showEditJoinViewDialog(int index, JoinDefinition existingDef) async {
    final availableTables = controller.tables
        .map((t) => t['name'] as String)
        .toList();

    final result = await showJoinTableDialog(
      context: context,
      dbHandler: controller.dbHandler,
      database: widget.database,
      availableTables: availableTables,
      existingDefinition: existingDef,
    );

    if (result != null) {
      controller.updateJoinDefinition(index, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('JOIN 뷰 "${result.name}" 수정 완료'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showDeleteJoinViewDialog(int index, JoinDefinition joinDef) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('JOIN 뷰 삭제'),
        content: Text('"${joinDef.name}" JOIN 뷰를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((l) => l.cancel)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.removeJoinDefinition(index);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('JOIN 뷰 "${joinDef.name}" 삭제 완료'),
                  backgroundColor: Colors.green,
                ),
              );
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

  void showEditTableDialog(BuildContext ctx, TableSelectionController controller, String oldName, String tableSchema) {
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
                controller.renameTable(oldName, newName, schema: tableSchema);
              }
            },
            child: Text(intl.getString((l) => l.save)),
          ),
        ],
      ),
    );
  }

  void showDeleteTableDialog(BuildContext ctx, TableSelectionController controller, String tableName, String tableSchema) {
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
              controller.deleteTable(tableName, schema: tableSchema);
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
