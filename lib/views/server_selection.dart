// lib/views/server_selection.dart
import 'package:db_handler/views/util/SettingDialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/LocalizationManager.dart';
import '../stateManagement/mobx/mobx_store.dart';
import '../sqflite/models/server_model.dart';

/// MobX 상태 관리
class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _defaultSchemaController = TextEditingController();
  String _selectedDbType = 'PostgreSQL';

  static const List<String> _dbTypes = [
    'PostgreSQL',
    'MySQL',
    'MariaDB',
    'SQLite',
    'MSSQL',
  ];
  static const Set<String> _enabledDbTypes = {'PostgreSQL', 'MySQL'};
  static const Map<String, String> _defaultPorts = {
    'PostgreSQL': '5432',
    'MySQL': '3306',
    'MariaDB': '3306',
    'SQLite': '',
    'MSSQL': '1433',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = Provider.of<ServerStore>(context, listen: false);
      store.loadServers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _defaultSchemaController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<ServerModel?> _showAuthDialog(ServerModel server, {bool isTest = false, bool isInitialSetup = false}) async {
    final usernameController = TextEditingController(text: server.username ?? '');
    final passwordController = TextEditingController(text: server.password ?? '');
    final keyFilePathController = TextEditingController(text: server.keyFilePath ?? '');
    final store = Provider.of<ServerStore>(context, listen: false);

    if (isTest && (server.username == null || server.username!.isEmpty)) {
      usernameController.text = server.type == 'MySQL' ? 'root' : 'postgres';
      passwordController.text = '0000';
    }

    return await showDialog<ServerModel?>(
      context: context,
      builder: (dialogContext) {
        bool isPasswordObscured = true;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(intl.getString((l) => l.accountInfo)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                        labelText: intl.getString((l) => l.account),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: isPasswordObscured,
                    decoration: InputDecoration(
                      labelText: intl.getString((l) => l.password),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(isPasswordObscured
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            isPasswordObscured = !isPasswordObscured;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: keyFilePathController,
                          decoration: InputDecoration(
                              labelText: intl.getString((l) => l.keyFilePath),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.vpn_key)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: () async {
                          FilePickerResult? result =
                          await FilePicker.platform.pickFiles();
                          if (result != null) {
                            keyFilePathController.text = result.files.single.path ?? '';
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: Text(isInitialSetup ? intl.getString((l) => l.skip) : intl.getString((l) => l.cancel)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final updatedServer = server.copyWith(
                    username: usernameController.text.trim(),
                    password: passwordController.text.trim(),
                    keyFilePath: keyFilePathController.text.trim(),
                  );
                  await store.updateServer(updatedServer, _showSnackbar);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, updatedServer);
                },
                child: Text(intl.getString((l) => l.save)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditServerDialog(ServerModel server) async {
    final nameController = TextEditingController(text: server.name);
    final hostController = TextEditingController(text: server.address.split(':')[0]);
    final portController = TextEditingController(text: server.address.split(':')[1]);
    final defaultSchemaController = TextEditingController(text: server.defaultSchema ?? '');
    String editSelectedType = _dbTypes.contains(server.type) ? server.type : 'PostgreSQL';
    final store = Provider.of<ServerStore>(context, listen: false);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(intl.getString((l) => l.editServerInfo)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                        labelText: intl.getString((l) => l.serverName),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.dns))),
                const SizedBox(height: 16),
                TextField(
                  controller: hostController,
                  decoration: InputDecoration(
                      labelText: intl.getString((l) => l.hostAddress),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                      hintText: 'localhost'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: portController,
                  decoration: InputDecoration(
                      labelText: intl.getString((l) => l.port),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.numbers),
                      hintText: _defaultPorts[editSelectedType] ?? ''),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: editSelectedType,
                  decoration: InputDecoration(
                    labelText: intl.getString((l) => l.dbType),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.storage),
                  ),
                  items: _dbTypes.map((type) {
                    final enabled = _enabledDbTypes.contains(type);
                    return DropdownMenuItem<String>(
                      value: type,
                      enabled: enabled,
                      child: Row(
                        children: [
                          Text(type, style: TextStyle(color: enabled ? null : Colors.grey)),
                          if (!enabled) ...[
                            const SizedBox(width: 6),
                            const Text('(미지원)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null && _enabledDbTypes.contains(value)) {
                      setDialogState(() {
                        editSelectedType = value;
                        if (portController.text.isEmpty ||
                            _defaultPorts.values.contains(portController.text)) {
                          portController.text = _defaultPorts[value] ?? '';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: defaultSchemaController,
                  decoration: const InputDecoration(
                    labelText: '기본 스키마 (선택)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schema),
                    hintText: '비워두면 전체 스키마 표시',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(intl.getString((l) => l.cancel))),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final host = hostController.text.trim();
                final port = portController.text.trim();
                final defaultSchema = defaultSchemaController.text.trim();

                if (name.isEmpty || host.isEmpty || port.isEmpty) {
                  _showSnackbar(intl.getString((l) => l.requiredFields), color: Colors.red);
                  return;
                }

                final address = '$host:$port';
                final schema = defaultSchema.isEmpty ? null : defaultSchema;
                final isDuplicate = store.servers.any((s) =>
                    s.address == address &&
                    s.defaultSchema == schema &&
                    s.id != server.id);

                if (isDuplicate) {
                  _showSnackbar(intl.getString((l) => l.duplicateServer), color: Colors.red);
                  return;
                }

                final updatedServer = server.copyWith(
                  name: name,
                  address: address,
                  type: editSelectedType,
                  defaultSchema: defaultSchema.isEmpty ? null : defaultSchema,
                );

                await store.updateServer(updatedServer, _showSnackbar);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(intl.getString((l) => l.save)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteServerDialog(ServerModel server) async {
    final store = Provider.of<ServerStore>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(intl.getString((l) => l.deleteServer)),
        content: Text(intl.getStringWithParams(
          (l, serverName) => l.deleteServerConfirm(serverName),
          server.name
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(intl.getString((l) => l.cancel))),
          ElevatedButton(
            onPressed: () async {
              await store.deleteServer(server, _showSnackbar);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(intl.getString((l) => l.delete)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<ServerStore>(context, listen: false);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: buildAppBarWithSettings(context, intl.getString((l) => l.serverList)),
      body: Container(
        color: colorScheme.background,
        child: Observer(
          builder: (_) {
            if (store.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (store.error != null) {
              return Center(
                child: Text(intl.getStringWithParams(
                  (l, serverName) => l.deleteServerConfirm(serverName),
                  store.error)
                )
              );
            }
            debugPrint("[ServerSelection] 서버 개수: ${store.servers.length}");

            return Column(
              children: [
                // 서버 추가 폼 부분
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                intl.getString((l) => l.addServer),
                                style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold
                                ),
                              ),
                              Observer(
                                builder: (_) => IconButton(
                                  icon: Icon(
                                    store.isAddFormOpen
                                        ? Icons.close
                                        : Icons.add,
                                  ),
                                  onPressed: () {
                                    store.toggleAddForm();
                                    if (!store.isAddFormOpen) {
                                      store.setIsTestServer(false);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          Observer(
                            builder: (_) {
                              if (!store.isAddFormOpen) return const SizedBox.shrink();

                              return Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(intl.getString((l) => l.addTestServer),
                                        style: const TextStyle(fontSize: 16)),
                                      Observer(
                                        builder: (_) => Switch(
                                          value: store.isTestServer,
                                          onChanged: (value) {
                                            store.setIsTestServer(value);
                                            if (value) {
                                              _nameController.text = 'Test Server';
                                              _hostController.text = '127.0.0.1';
                                              _portController.text = '5432';
                                              setState(() => _selectedDbType = 'PostgreSQL');
                                            } else {
                                              _nameController.clear();
                                              _hostController.clear();
                                              _portController.clear();
                                              setState(() => _selectedDbType = 'PostgreSQL');
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                        labelText: intl.getString((l) => l.serverName),
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.dns)),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _hostController,
                                    decoration: InputDecoration(
                                        labelText: intl.getString((l) => l.hostAddress),
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.link),
                                        hintText: 'localhost'),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _portController,
                                    decoration: InputDecoration(
                                        labelText: intl.getString((l) => l.port),
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.numbers),
                                        hintText: _defaultPorts[_selectedDbType] ?? ''),
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedDbType,
                                    decoration: InputDecoration(
                                      labelText: intl.getString((l) => l.dbType),
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.storage),
                                    ),
                                    items: _dbTypes.map((type) {
                                      final enabled = _enabledDbTypes.contains(type);
                                      return DropdownMenuItem<String>(
                                        value: type,
                                        enabled: enabled,
                                        child: Row(
                                          children: [
                                            Text(
                                              type,
                                              style: TextStyle(
                                                color: enabled ? null : Colors.grey,
                                              ),
                                            ),
                                            if (!enabled) ...[
                                              const SizedBox(width: 6),
                                              const Text(
                                                '(미지원)',
                                                style: TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null && _enabledDbTypes.contains(value)) {
                                        setState(() {
                                          _selectedDbType = value;
                                          if (_portController.text.isEmpty ||
                                              _defaultPorts.values.contains(_portController.text)) {
                                            _portController.text = _defaultPorts[value] ?? '';
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _defaultSchemaController,
                                    decoration: const InputDecoration(
                                      labelText: '기본 스키마 (선택)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.schema),
                                      hintText: '비워두면 전체 스키마 표시',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        // 1. 입력값 가져오기 및 검증
                                        final name = _nameController.text.trim();
                                        final host = _hostController.text.trim();
                                        final port = _portController.text.trim();
                                        final type = _selectedDbType;
                                        final defaultSchema = _defaultSchemaController.text.trim();

                                        if (name.isEmpty || host.isEmpty || port.isEmpty) {
                                          _showSnackbar(intl.getString((l) => l.requiredFields), color: Colors.red);
                                          return;
                                        }

                                        // 2. address 조합 및 중복 체크
                                        final address = '$host:$port';

                                        // 2-1. 메모리(Store)에서 중복 체크 (address + defaultSchema 조합)
                                        final schema = defaultSchema.isEmpty ? null : defaultSchema;
                                        final isDuplicate = store.servers.any((s) =>
                                            s.address == address && s.defaultSchema == schema);
                                        if (isDuplicate) {
                                          _showSnackbar(intl.getString((l) => l.duplicateServer), color: Colors.red);
                                          return;
                                        }

                                        // 3. ServerModel 인스턴스 생성
                                        final newServer = ServerModel(
                                          id: null,
                                          name: name,
                                          address: address,
                                          type: type,
                                          isConnected: false,
                                          username: null,
                                          password: null,
                                          keyFilePath: null,
                                          notes: null,
                                          defaultSchema: defaultSchema.isEmpty ? null : defaultSchema,
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                        );

                                        try {
                                          // 4. Store를 통해 서버 추가
                                          final success = await store.addServer(newServer, _showSnackbar);

                                          if (success) {
                                            // 5. 성공 시 UI 정리
                                            _nameController.clear();
                                            _hostController.clear();
                                            _portController.clear();
                                            _defaultSchemaController.clear();
                                            setState(() => _selectedDbType = 'PostgreSQL');
                                            store.closeAddForm();
                                            store.setIsTestServer(false);

                                            // SSH/MySQL 등 인증이 필요하면 다이얼로그 띄우기
                                            if (type.toLowerCase().contains('ssh') ||
                                                type.toLowerCase().contains('mysql') ||
                                                type.toLowerCase().contains('sqlserver')) {
                                              if (context.mounted) {
                                                if (store.lastAddedServer != null) {
                                                  await _showAuthDialog(store.lastAddedServer!);
                                                }
                                              }
                                            }
                                          }

                                        } catch (e) {
                                          // addServer 내부에서 이미 showSnackbar 호출하므로 중복 방지
                                          debugPrint('서버 추가 중 오류: $e');
                                        }
                                      },
                                      icon: const Icon(Icons.add),
                                      label: Text(intl.getString((l) => l.addServer)),
                                      style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.all(16)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 3. 서버 목록 부분만 Observer로 감싸기
                Expanded(
                  child: _ServerListWidget(
                    onEditServer: _showEditServerDialog,
                    onEditAuth: _showAuthDialog,
                    onDeleteServer: _showDeleteServerDialog,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 설정 메뉴가 포함된 AppBar를 생성하는 헬퍼 함수
  AppBar buildAppBarWithSettings(BuildContext context, String title) {
    return AppBar(
      title: Text(title),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: intl.getString((l) => l.settings),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const SettingsDialog(),
            );
          },
        ),
      ],
    );
  }
}

// 3. 서버 목록만 별도 위젯으로 분리하여 리빌드 최적화
class _ServerListWidget extends StatelessWidget {
  final Function(ServerModel) onEditServer;
  final Function(ServerModel, {bool isInitialSetup}) onEditAuth;
  final Function(ServerModel) onDeleteServer;

  const _ServerListWidget({
    required this.onEditServer,
    required this.onEditAuth,
    required this.onDeleteServer,
  });

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<ServerStore>(context, listen: false);
    final theme = Theme.of(context);

    return Observer(
      builder: (_) {
        if (store.servers.isEmpty) {
          return Center(
            child: Text(
              intl.getString((l) => l.noServers),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          itemCount: store.servers.length,
          itemBuilder: (context, index) {
            final server = store.servers[index];
            final isTestServer = server.address == '127.0.0.1:5432';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: InkWell(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  ServerModel? targetServer = server;
                  final username = targetServer.username;
                  final password = targetServer.password;
                  bool needsAuth = (username?.isEmpty ?? true) &&
                      (password?.isEmpty ?? true);

                  if (needsAuth) {
                    targetServer = await onEditAuth(server, isInitialSetup: true);
                  }

                  if (!context.mounted || targetServer == null) return;

                  // 지원되는 DB 타입인 경우 DatabaseHandler 초기화
                  final supportedTypes = {'postgresql', 'mysql'};
                  if (supportedTypes.contains(targetServer.type.toLowerCase())) {
                    store.initializeDatabaseHandler();
                  }

                  navigator.pushNamed('/database-selection',
                      arguments: targetServer);
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isTestServer
                        ? theme.hintColor
                        : (server.isConnected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.error),
                    child: const Icon(Icons.dns, color: Colors.white),
                  ),
                  title: Text(server.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(server.defaultSchema != null && server.defaultSchema!.isNotEmpty
                      ? '${server.address}  •  ${server.defaultSchema}'
                      : server.address),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                          label: Text(server.type),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer)),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit_server') {
                            onEditServer(server);
                          } else if (value == 'edit_auth') {
                            onEditAuth(server, isInitialSetup: false);
                          } else if (value == 'delete') {
                            onDeleteServer(server);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                              value: 'edit_server',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(intl.getString((l) => l.editServerInfo), overflow: TextOverflow.ellipsis))
                                ],
                              )),
                          PopupMenuItem<String>(
                              value: 'edit_auth',
                              child: Row(
                                children: [
                                  const Icon(Icons.security, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(intl.getString((l) => l.editAuthInfo), overflow: TextOverflow.ellipsis))
                                ],
                              )),
                          PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(intl.getString((l) => l.delete),
                                    style: const TextStyle(color: Colors.red), overflow: TextOverflow.ellipsis))
                                ],
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}