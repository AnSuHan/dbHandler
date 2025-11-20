// lib/views/server_selection.dart
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
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

  @override
  void dispose() {
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
            title: const Text('계정 정보 입력'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                        labelText: '계정',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: isPasswordObscured,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
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
                          decoration: const InputDecoration(
                              labelText: '키 파일 경로',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.vpn_key)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: () async {
                          FilePickerResult? result =
                          await FilePicker.platform.pickFiles();
                          if (result != null) {
                            keyFilePathController.text =
                                result.files.single.path ?? '';
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
                child: Text(isInitialSetup ? '건너뛰기' : '취소'),
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
                child: const Text('저장'),
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
        title: const Text('서버 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: '서버 이름',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns))),
              const SizedBox(height: 16),
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                    labelText: '호스트 주소',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    hintText: 'localhost'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                    labelText: '포트',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                    hintText: '5432'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                    labelText: 'DB 타입',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storage),
                    hintText: 'PostgreSQL'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final host = hostController.text.trim();
              final port = portController.text.trim();
              final type = typeController.text.trim().isEmpty
                  ? 'PostgreSQL'
                  : typeController.text.trim();

              if (name.isEmpty || host.isEmpty || port.isEmpty) {
                _showSnackbar('이름, 호스트, 포트는 필수입니다.', color: Colors.red);
                return;
              }

              final address = '$host:$port';
              final updatedServer = server.copyWith(
                name: name,
                address: address,
                type: type,
              );

              await store.updateServer(updatedServer, _showSnackbar);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
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
        title: const Text('서버 삭제'),
        content: Text('${server.name} 서버를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              await store.deleteServer(server, _showSnackbar);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
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
        title: const Text('서버 목록'),
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
              return Center(child: Text('서버 목록 로딩 실패: ${store.error}'));
            }
            debugPrint("서버 개수: ${store.servers.length}");

            return Column(
              children: [
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
                              const Text(
                                '서버 추가',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
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
                                      const Text('테스트 서버 추가',
                                          style: TextStyle(fontSize: 16)),
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
                                    decoration: const InputDecoration(
                                        labelText: '서버 이름',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.dns)),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _hostController,
                                    decoration: const InputDecoration(
                                        labelText: '호스트 주소',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.link),
                                        hintText: 'localhost'),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _portController,
                                    decoration: const InputDecoration(
                                        labelText: '포트',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.numbers),
                                        hintText: '5432'),
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _typeController,
                                    decoration: const InputDecoration(
                                        labelText: 'DB 타입',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.storage),
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
                                          _showSnackbar('서버 이름, 호스트, 포트는 필수입니다.', color: Colors.red);
                                          return;
                                        }

                                        // 2. address 조합
                                        final address = '$host:$port';

                                        // 3. ServerModel 인스턴스 생성 (정확한 필드 사용!)
                                        final newServer = ServerModel(
                                          id: null,                    // 저장 시 자동 생성
                                          name: name,
                                          address: address,
                                          type: type,
                                          isConnected: false,          // 처음엔 연결 안 됨
                                          username: null,
                                          password: null,
                                          keyFilePath: null,
                                          notes: null,
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                        );

                                        try {
                                          // 4. Store를 통해 서버 추가 (ServerModel 전달)
                                          await store.addServer(newServer, _showSnackbar);

                                          // 5. 성공 시 UI 정리
                                          _nameController.clear();
                                          _hostController.clear();
                                          _portController.clear();
                                          _typeController.clear();

                                          store.toggleAddForm();
                                          store.setIsTestServer(false);
                                          store.isAddFormOpen = false;

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

                                        } catch (e) {
                                          // addServer 내부에서 이미 showSnackbar 호출하므로 중복 방지
                                          // 필요 시 여기서 추가 처리
                                        }
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('서버 추가'),
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
                Expanded(
                  child: Observer(
                    builder: (_) {
                      if (store.servers.isEmpty) {
                        return const Center(
                          child: Text(
                            '서버가 없습니다. + 버튼을 눌러 서버를 추가해주세요.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
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
                                final username = targetServer?.username;
                                final password = targetServer?.password;
                                bool needsAuth = (username?.isEmpty ?? true) &&
                                    (password?.isEmpty ?? true);

                                if (needsAuth && targetServer != null) {
                                  targetServer = await _showAuthDialog(server,
                                      isTest: isTestServer,
                                      isInitialSetup: true);
                                }

                                if (!mounted || targetServer == null) return;

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
                                          _showEditServerDialog(server);
                                        } else if (value == 'edit_auth') {
                                          _showAuthDialog(server,
                                              isInitialSetup: false);
                                        } else if (value == 'delete') {
                                          _showDeleteServerDialog(server);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem<String>(
                                            value: 'edit_server',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 20),
                                                SizedBox(width: 8),
                                                Text('서버 정보 수정')
                                              ],
                                            )),
                                        const PopupMenuItem<String>(
                                            value: 'edit_auth',
                                            child: Row(
                                              children: [
                                                Icon(Icons.security, size: 20),
                                                SizedBox(width: 8),
                                                Text('인증 정보 수정')
                                              ],
                                            )),
                                        const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete,
                                                    size: 20, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('삭제',
                                                    style: TextStyle(
                                                        color: Colors.red))
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