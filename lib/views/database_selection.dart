import 'dart:convert';
import 'dart:io';

import 'package:db_handler/db/database_handler.dart';
import 'package:db_handler/db/database_handler_factory.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/LocalizationManager.dart';
import '../sqflite/models/server_model.dart';
import '../stateManagement/getx/TableSelectionController.dart';
import 'unit/hidden_tables_dialog.dart';

class DatabaseSelectionScreen extends StatefulWidget {
  final ServerModel server;

  const DatabaseSelectionScreen({super.key, required this.server});

  @override
  State<DatabaseSelectionScreen> createState() => _DatabaseSelectionScreenState();
}

class _DatabaseSelectionScreenState extends State<DatabaseSelectionScreen> {
  late final DatabaseHandler _dbHandler;
  List<Map<String, dynamic>> _databases = [];
  bool _isLoading = true;
  String? _error;

  /// 숨겨진 데이터베이스 이름 집합
  Set<String> _hiddenDatabases = {};

  /// DB별 숨겨진 실제 테이블 수 (표시 카운트 보정용)
  Map<String, int> _hiddenRealCountPerDb = {};

  String get _hiddenDbPrefsKey => 'hidden_databases|${widget.server.id ?? widget.server.address}';

  @override
  void initState() {
    super.initState();
    _dbHandler = DatabaseHandlerFactory.createHandler(widget.server);
    _loadHiddenDatabases().then((_) => _loadDatabases());
  }

  Future<void> _loadHiddenDatabases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_hiddenDbPrefsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<String>();
        if (mounted) setState(() => _hiddenDatabases = list.toSet());
      }
    } catch (_) {}
  }

  Future<void> _loadHiddenCountsPerDb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = <String, int>{};
      for (final db in _databases) {
        final dbName = db['name'] as String;
        final raw = prefs.getString('hidden_tables|${widget.server.address}|$dbName');
        if (raw == null) continue;
        final map = jsonDecode(raw) as Map<String, dynamic>;
        result[dbName] = ((map['hiddenRealTables'] as List?)?.length ?? 0);
      }
      if (mounted) setState(() => _hiddenRealCountPerDb = result);
    } catch (_) {}
  }

  Future<void> _persistHiddenDatabases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hiddenDbPrefsKey, jsonEncode(_hiddenDatabases.toList()));
    } catch (_) {}
  }

  void _toggleDatabaseVisibility(String dbName) {
    setState(() {
      if (_hiddenDatabases.contains(dbName)) {
        _hiddenDatabases.remove(dbName);
      } else {
        _hiddenDatabases.add(dbName);
      }
    });
    _persistHiddenDatabases();
  }

  Future<void> _showAllTableHiddenSettings(BuildContext context) async {
    for (final db in _databases) {
      final dbName = db['name'] as String;
      final tag = '${widget.server.id}_$dbName';
      if (!Get.isRegistered<TableSelectionController>(tag: tag)) {
        Get.put(
          TableSelectionController(server: widget.server, database: dbName),
          tag: tag,
        );
      }
    }
    if (!context.mounted) return;
    final dbNames = _databases.map((db) => db['name'] as String).toList();
    await _showAllTableHiddenDialog(context, dbNames);
  }

  Future<void> _showAllTableHiddenDialog(
      BuildContext context, List<String> dbNames) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('전체 테이블 숨김 설정'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '데이터베이스를 선택하여 테이블 숨김을 설정하세요.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ...dbNames.map((dbName) {
                    final tag = '${widget.server.id}_$dbName';
                    final ctrl = Get.find<TableSelectionController>(tag: tag);
                    return Obx(() {
                      final visible = ctrl.visibleTableCount;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.storage, size: 20),
                        title: Text(dbName),
                        subtitle: Text('테이블 $visible개',
                            style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () async {
                          if (dialogContext.mounted) {
                            await showHiddenTablesDialog(
                                context: dialogContext, controller: ctrl);
                          }
                        },
                      );
                    });
                  }),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('내보내기'),
              onPressed: () => _exportServerHiddenConfig(dialogContext),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('가져오기'),
              onPressed: () => _importServerHiddenConfig(dialogContext, dbNames),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(intl.getString((l) => l.cancel)),
            ),
          ],
        );
      },
    );
  }

  /// 이 서버의 모든 DB 숨김 설정을 하나의 파일로 내보내기
  Future<void> _exportServerHiddenConfig(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'hidden_tables|${widget.server.address}|';
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix));
      final databases = <String, dynamic>{};
      for (final key in keys) {
        final db = key.substring(prefix.length);
        final raw = prefs.getString(key);
        if (raw == null) continue;
        databases[db] = jsonDecode(raw);
      }
      if (databases.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장된 숨김 설정이 없습니다.')),
          );
        }
        return;
      }
      final map = {
        'version': 2,
        'serverAddress': widget.server.address,
        'databases': databases,
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
      final safeName = widget.server.address.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '숨김 설정 내보내기',
        fileName: 'hidden_tables_$safeName.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsString(jsonStr, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장됨: $savePath (${databases.length}개 데이터베이스)',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 파일에서 서버 전체 숨김 설정을 가져와 모든 컨트롤러에 반영
  Future<void> _importServerHiddenConfig(
      BuildContext context, List<String> dbNames) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '숨김 설정 가져오기',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      final content = await File(path).readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      final version = map['version'] as int? ?? 1;
      final prefs = await SharedPreferences.getInstance();

      if (version >= 2 && map.containsKey('databases')) {
        final databases = map['databases'] as Map<String, dynamic>;
        for (final entry in databases.entries) {
          final db = entry.key;
          final dbMap = entry.value as Map<String, dynamic>;
          await prefs.setString(
            'hidden_tables|${widget.server.address}|$db',
            jsonEncode({
              'hiddenRealTables': dbMap['hiddenRealTables'] ?? [],
              'hiddenJoinViews': dbMap['hiddenJoinViews'] ?? [],
            }),
          );
        }
        // 등록된 모든 컨트롤러 갱신
        for (final dbName in dbNames) {
          final tag = '${widget.server.id}_$dbName';
          if (Get.isRegistered<TableSelectionController>(tag: tag)) {
            await Get.find<TableSelectionController>(tag: tag).reloadHiddenTables();
          }
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('가져오기 완료 (${databases.length}개 데이터베이스)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // v1 구 포맷: 단일 DB 설정 - database 필드가 있으면 해당 DB에만 적용
        final targetDb = map['database'] as String?;
        if (targetDb != null) {
          await prefs.setString(
            'hidden_tables|${widget.server.address}|$targetDb',
            jsonEncode({
              'hiddenRealTables': map['hiddenRealTables'] ?? [],
              'hiddenJoinViews': map['hiddenJoinViews'] ?? [],
            }),
          );
          final tag = '${widget.server.id}_$targetDb';
          if (Get.isRegistered<TableSelectionController>(tag: tag)) {
            await Get.find<TableSelectionController>(tag: tag).reloadHiddenTables();
          }
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('가져오기 완료'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가져오기 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showTableHiddenSettings(BuildContext context, String dbName) async {
    final tag = '${widget.server.id}_$dbName';
    final ctrl = Get.isRegistered<TableSelectionController>(tag: tag)
        ? Get.find<TableSelectionController>(tag: tag)
        : Get.put(
            TableSelectionController(server: widget.server, database: dbName),
            tag: tag,
          );
    if (context.mounted) {
      await showHiddenTablesDialog(context: context, controller: ctrl);
    }
  }

  Future<void> _loadDatabases() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final databases = await _dbHandler.getDatabases();
      if (!mounted) return;
      final defaultSchema = widget.server.defaultSchema;
      final filtered = (defaultSchema != null && defaultSchema.isNotEmpty)
          ? databases.where((db) => db['name'] == defaultSchema).toList()
          : databases;
      setState(() { _databases = filtered; _isLoading = false; });
      _loadHiddenCountsPerDb();
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = 'Failed to load databases: $e'; });
    }
  }

  Future<void> _performDbOperation(
    Future<void> Function() operation,
    String successMessage,
    String failureMessage,
  ) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      await operation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$failureMessage: $e')));
      }
    }
    if (mounted) await _loadDatabases();
  }

  Future<void> _createDatabase(String dbName) async {
    await _performDbOperation(
      () => _dbHandler.createDatabase(dbName),
      intl.getStringWithParams((l, dbName) => l.createDatabaseSuccess(dbName), dbName),
      intl.getString((l) => l.createDatabaseFailure),
    );
  }

  Future<void> _renameDatabase(String oldName, String newName) async {
    await _performDbOperation(
      () => _dbHandler.renameDatabase(oldName, newName),
      intl.getStringWithMultiParams(
          (l, params) => l.renameDatabaseSuccess(params[0], params[1]), [oldName, newName]),
      intl.getString((l) => l.renameDatabaseFailure),
    );
  }

  Future<void> _deleteDatabase(String dbName) async {
    await _performDbOperation(
      () => _dbHandler.deleteDatabase(dbName),
      intl.getStringWithParams((l, dbName) => l.deleteDatabaseSuccess(dbName), dbName),
      intl.getString((l) => l.deleteDatabaseFailure),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${intl.getString((l) => l.connectedServer)} - ${widget.server.name}"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _dbHandler.clearCache();
              _loadDatabases();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '더보기',
            onSelected: (value) {
              if (value == 'table_hidden_all') {
                _showAllTableHiddenSettings(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'table_hidden_all',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('전체 테이블 숨김 설정'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).colorScheme.background,
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
                        child: Text(intl.getString((l) => l.goBack)),
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
                            Icon(Icons.info_outline,
                                size: 24, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    intl.getString((l) => l.connectedServer),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    widget.server.name,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showCreateDatabaseDialog,
                              icon: const Icon(Icons.add),
                              label: Text(intl.getString((l) => l.newDatabase)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _databases.isEmpty
                            ? Center(
                                child: Text(
                                  intl.getString((l) => l.noDatabaseFound),
                                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                itemCount: _databases.length,
                                itemBuilder: (context, index) {
                                  final db = _databases[index];
                                  final dbName = db['name'] as String;
                                  final isHidden = _hiddenDatabases.contains(dbName);
                                  return _buildDatabaseCard(
                                      context, dbName, db, isHidden);
                                },
                              ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDatabaseCard(
    BuildContext context,
    String dbName,
    Map<String, dynamic> db,
    bool isHidden,
  ) {
    return Opacity(
      opacity: isHidden ? 0.45 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isHidden ? 0 : 2,
        child: InkWell(
          onTap: isHidden
              ? null
              : () {
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 24,
              child: Icon(
                isHidden ? Icons.visibility_off : Icons.storage,
                color: Colors.white,
              ),
            ),
            title: Text(
              dbName,
              style: TextStyle(
                decoration: isHidden ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Builder(builder: (_) {
              final total = db['table_count'] as int? ?? 0;
              final hidden = _hiddenRealCountPerDb[dbName] ?? 0;
              final visible = (total - hidden).clamp(0, total);
              return Text('${intl.getString((l) => l.table)}: $visible');
            }),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'toggle_hidden') {
                  _toggleDatabaseVisibility(dbName);
                } else if (value == 'table_hidden') {
                  _showTableHiddenSettings(context, dbName);
                } else if (value == 'edit') {
                  _showEditDatabaseDialog(dbName);
                } else if (value == 'delete') {
                  _showDeleteDatabaseDialog(dbName);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'toggle_hidden',
                  child: Row(
                    children: [
                      Icon(isHidden ? Icons.visibility : Icons.visibility_off_outlined,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(isHidden ? '데이터베이스 표시' : '데이터베이스 숨기기'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'table_hidden',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('테이블 숨김 설정'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(intl.getString((l) => l.edit),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(intl.getString((l) => l.delete),
                            style: const TextStyle(color: Colors.red),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateDatabaseDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.createNewDatabase)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: intl.getString((l) => l.databaseName),
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
              final dbName = nameController.text.trim();
              if (dbName.isNotEmpty) {
                Navigator.pop(dialogContext);
                _createDatabase(dbName);
              }
            },
            child: Text(intl.getString((l) => l.create)),
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
        title: Text(intl.getString((l) => l.editDatabaseName)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: intl.getString((l) => l.newDatabaseName),
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
                _renameDatabase(oldName, newName);
              }
            },
            child: Text(intl.getString((l) => l.save)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDatabaseDialog(String dbName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.deleteDatabase)),
        content: Text(intl.getStringWithParams(
            (l, dbName) => l.deleteDatabaseConfirm(dbName), dbName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((l) => l.cancel)),
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
            child: Text(intl.getString((l) => l.delete)),
          ),
        ],
      ),
    );
  }
}
