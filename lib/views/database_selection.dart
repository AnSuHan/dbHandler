import 'package:db_handler/db/database_handler.dart';
import 'package:db_handler/db/postgres_handler.dart';
import 'package:flutter/material.dart';

class DatabaseSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> server;

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
    // In the future, you can add more database types here.
    switch (widget.server['type']) {
      case 'PostgreSQL':
        return PostgresHandler(widget.server);
      default:
        throw Exception('Unsupported database type: ${widget.server['type']}');
    }
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
      'Database $dbName created successfully.',
      'Failed to create database.',
    );
  }

  Future<void> _renameDatabase(String oldName, String newName) async {
    await _performDbOperation(
      () => _dbHandler.renameDatabase(oldName, newName),
      'Database renamed to $newName.',
      'Failed to rename database.',
    );
  }

  Future<void> _deleteDatabase(String dbName) async {
    await _performDbOperation(
      () => _dbHandler.deleteDatabase(dbName),
      'Database $dbName deleted successfully.',
      'Failed to delete database.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Server - ${widget.server['name']}"),
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
                        child: const Text('Go Back'),
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
                                    'Connected Server',
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
                              label: const Text('New Database'),
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
                        : _databases.isEmpty
                            ? const Center(
                                child: Text(
                                  'No databases found. Please add a new one.',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
                                          backgroundColor: const Color(0xFF8B5CF6),
                                          radius: 24,
                                          child: const Icon(
                                            Icons.storage,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(dbName),
                                        subtitle: const Text(' '),
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
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Delete', style: TextStyle(color: Colors.red)),
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
        title: const Text('Create New Database'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Database Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final dbName = nameController.text.trim();
              if (dbName.isNotEmpty) {
                Navigator.pop(dialogContext);
                _createDatabase(dbName);
              }
            },
            child: const Text('Create'),
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
        title: const Text('Edit Database Name'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Database Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                Navigator.pop(dialogContext);
                _renameDatabase(oldName, newName);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDatabaseDialog(String dbName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Database'),
        content: Text('Are you sure you want to delete the database $dbName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
