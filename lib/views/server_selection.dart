// lib/views/server_selection.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _typeController = TextEditingController();

  // DB 포트 매핑 데이터
  Map<String, String> _portToDbMap = {};

  @override
  void initState() {
    super.initState();

    // JSON 파일 로드
    _loadPortMapping();
    // 포트 컨트롤러에 리스너 추가
    _portController.addListener(_onPortChanged);

    // 1. 앱 시작 시 저장된 서버 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = Provider.of<ServerStore>(context, listen: false);
      store.loadServers();
    });
  }

  Future<void> _loadPortMapping() async {
    try {
      final jsonString = await rootBundle.loadString('assets/file/defaultDBPort.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      setState(() {
        _portToDbMap = jsonData.map((key, value) => MapEntry(key, value.toString()));
      });
    } catch (e) {
      _portToDbMap = {};
    }
  }

  void _onPortChanged() {
    final port = _portController.text.trim();

    // DB 타입이 비어있거나 자동으로 설정된 값인 경우에만 업데이트
    debugPrint("[_onPortChanged] _portToDbMap: $_portToDbMap, port: $port");
    if (_portToDbMap.containsKey(port)) {
      final dbType = _portToDbMap[port]!;
      // 현재 타입이 비어있거나 매핑된 다른 값인 경우에만 변경
      if (_typeController.text.isEmpty || _portToDbMap.values.contains(_typeController.text)) {
        _typeController.text = dbType;
      }
    }
  }

  @override
  void dispose() {
    _portController.removeListener(_onPortChanged);
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _typeController.dispose();
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
      usernameController.text = 'postgres';
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
    final typeController = TextEditingController(text: server.type);
    final store = Provider.of<ServerStore>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                    hintText: '5432'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: InputDecoration(
                    labelText: intl.getString((l) => l.dbType),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.storage),
                    hintText: 'PostgreSQL'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(intl.getString((l) => l.cancel))),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final host = hostController.text.trim();
              final port = portController.text.trim();
              final type = typeController.text.trim().isEmpty
                  ? 'PostgreSQL'
                  : typeController.text.trim();

              if (name.isEmpty || host.isEmpty || port.isEmpty) {
                _showSnackbar(intl.getString((l) => l.requiredFields), color: Colors.red);
                return;
              }

              final address = '$host:$port';

              // 2. 수정 시에도 중복 체크 (자기 자신 제외)
              final isDuplicate = store.servers.any((s) =>
              s.address == address && s.id != server.id
              );

              if (isDuplicate) {
                _showSnackbar(intl.getString((l) => l.duplicateServer), color: Colors.red);
                return;
              }

              final updatedServer = server.copyWith(
                name: name,
                address: address,
                type: type,
              );

              await store.updateServer(updatedServer, _showSnackbar);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(intl.getString((l) => l.save)),
          ),
        ],
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              await store.deleteServer(server, _showSnackbar);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(intl.getString((l) => l.cancel)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<ServerStore>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(intl.getString((l) => l.serverList)),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6366F1), Color(0xFFF8F9FA)],
            stops: [0.0, 0.1],
          ),
        ),
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
                                              _typeController.text = 'PostgreSQL';
                                            } else {
                                              _nameController.clear();
                                              _hostController.clear();
                                              _portController.clear();
                                              _typeController.clear();
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
                                        hintText: '5432'),
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _typeController,
                                    decoration: InputDecoration(
                                        labelText: intl.getString((l) => l.dbType),
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.storage),
                                        hintText: 'PostgreSQL'),
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
                                        final type = _typeController.text.trim().isNotEmpty
                                            ? _typeController.text.trim()
                                            : 'PostgreSQL';

                                        if (name.isEmpty || host.isEmpty || port.isEmpty) {
                                          _showSnackbar(intl.getString((l) => l.requiredFields), color: Colors.red);
                                          return;
                                        }

                                        // 2. address 조합 및 중복 체크
                                        final address = '$host:$port';

                                        // 2-1. 메모리(Store)에서 중복 체크
                                        final isDuplicate = store.servers.any((s) => s.address == address);
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
                                            _typeController.clear();

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
                                          backgroundColor: const Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
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

                  // PostgreSQL 서버인 경우 DatabaseHandler 초기화
                  if (targetServer.type.toLowerCase() == 'postgresql') {
                    store.initializeDatabaseHandler();
                  }

                  navigator.pushNamed('/database-selection',
                      arguments: targetServer);
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isTestServer
                        ? Colors.grey
                        : (server.isConnected
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444)),
                    child: const Icon(Icons.dns, color: Colors.white),
                  ),
                  title: Text(server.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(server.address),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                          label: Text(server.type),
                          backgroundColor:
                          const Color(0xFFEDE9FE),
                          labelStyle: const TextStyle(
                              color: Color(0xFF6366F1))),
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
                                  Text(intl.getString((l) => l.editServerInfo))
                                ],
                              )),
                          PopupMenuItem<String>(
                              value: 'edit_auth',
                              child: Row(
                                children: [
                                  const Icon(Icons.security, size: 20),
                                  const SizedBox(width: 8),
                                  Text(intl.getString((l) => l.editAuthInfo))
                                ],
                              )),
                          PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(intl.getString((l) => l.delete),
                                    style: const TextStyle(color: Colors.red))
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