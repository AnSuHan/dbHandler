import 'package:db_handler/db/database_handler.dart';
import 'package:db_handler/db/database_handler_factory.dart';
import 'package:flutter/material.dart';

import '../l10n/LocalizationManager.dart';
import '../sqflite/models/server_model.dart';

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

  @override
  void initState() {
    super.initState();
    _dbHandler = _getDbHandler();
    _loadDatabases();
  }

  DatabaseHandler _getDbHandler() {
    return DatabaseHandlerFactory.createHandler(widget.server);
  }

  Future<void> _loadDatabases() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final databases = await _dbHandler.getDatabases();
      if (!mounted) return;

      setState(() {
        _databases = databases;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load databases: $e';
        });
      }
    }
  }

  Future<void> _performDbOperation(
    Future<void> Function() operation,
    String successMessage,
    String failureMessage,
  ) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await operation();

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
      () => _dbHandler.createDatabase(dbName),
      intl.getStringWithParams(
        (l, dbName) => l.createDatabaseSuccess(dbName),
        dbName,
      ),
      intl.getString((l) => l.createDatabaseFailure),
    );
  }

  Future<void> _renameDatabase(String oldName, String newName) async {
    await _performDbOperation(
      () => _dbHandler.renameDatabase(oldName, newName),
      intl.getStringWithMultiParams(
        (l, params) => l.renameDatabaseSuccess(params[0], params[1]),
        [oldName, newName],
      ),
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
                            Icon(Icons.info_outline, size: 24, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    intl.getString((l) => l.connectedServer),
                                    style: const TextStyle(
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
                                _showCreateDatabaseDialog();
                              },
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
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          radius: 24,
                                          child: const Icon(
                                            Icons.storage,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(dbName),
                                        subtitle: Text('${intl.getString((l) => l.table)}: ${db['table_count'] ?? 0}'),
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
        content: Text(intl.getStringWithParams((l, dbName) => l.deleteDatabaseConfirm(dbName), dbName)),
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
