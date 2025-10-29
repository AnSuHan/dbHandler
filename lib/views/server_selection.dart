import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../sqflite/models/server_model.dart';
import '../sqflite/dao/server_dao.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
  final ServerDao _serverDao = ServerDao();
  List<ServerModel> _servers = [];
  bool _isLoading = true;
  bool _showAddForm = false;
  bool _isTestServer = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    try {
      final servers = await _serverDao.getAllServers();
      setState(() {
        _servers = servers;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('서버 목록 로딩 실패: $e')));
      }
    }
  }

  Future<void> _addServer() async {
    final name = _nameController.text.trim();
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    final type = _typeController.text.trim().isEmpty ? 'PostgreSQL' : _typeController.text.trim();

    if (name.isEmpty || host.isEmpty || port.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이름, 호스트, 포트는 필수입니다.'), backgroundColor: Colors.red));
      }
      return;
    }

    final address = '$host:$port';
    if (_servers.any((s) => s.address == address)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 동일한 주소의 서버가 존재합니다.'), backgroundColor: Colors.orange));
      }
      return;
    }

    final newServer = ServerModel(name: name, address: address, type: type, isConnected: false);

    try {
      final newId = await _serverDao.insertServer(newServer);
      final createdServer = await _serverDao.getServerById(newId);

      _nameController.clear();
      _hostController.clear();
      _portController.clear();
      _typeController.clear();

      setState(() {
        _showAddForm = false;
        _isTestServer = false;
      });

      await _loadServers();

      if (mounted && createdServer != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버가 추가되었습니다.'), backgroundColor: Colors.green));
        await _showAuthDialog(createdServer, isTest: _isTestServer);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('서버 추가 실패: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<ServerModel?> _showAuthDialog(ServerModel server, {bool isTest = false}) async {
    final usernameController = TextEditingController(text: server.username);
    final passwordController = TextEditingController(text: server.password);
    final keyFilePathController = TextEditingController(text: server.keyFilePath);

    if (isTest && server.username == null) {
      usernameController.text = 'postgres';
      passwordController.text = '0000';
    }

    return await showDialog<ServerModel?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('계정 정보 입력'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: usernameController, decoration: const InputDecoration(labelText: '계정', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 16),
              TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: keyFilePathController, decoration: const InputDecoration(labelText: '키 파일 경로', border: OutlineInputBorder(), prefixIcon: Icon(Icons.vpn_key)))),
                  IconButton(icon: const Icon(Icons.attach_file), onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles();
                    if (result != null) {
                      keyFilePathController.text = result.files.single.path ?? '';
                    }
                  }),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, null), child: const Text('건너뛰기')),
          ElevatedButton(
            onPressed: () async {
              final updatedServer = server.copyWith(
                username: usernameController.text.trim(),
                password: passwordController.text.trim(),
                keyFilePath: keyFilePathController.text.trim(),
              );
              await _serverDao.updateServer(updatedServer);
              await _loadServers();
              if (dialogContext.mounted) Navigator.pop(dialogContext, updatedServer);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditServerDialog(ServerModel server) async {
    final nameController = TextEditingController(text: server.name);
    final hostController = TextEditingController(text: server.address.split(':')[0]);
    final portController = TextEditingController(text: server.address.split(':')[1]);
    final typeController = TextEditingController(text: server.type);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('서버 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '서버 이름', border: OutlineInputBorder(), prefixIcon: Icon(Icons.dns))),
              const SizedBox(height: 16),
              TextField(controller: hostController, decoration: const InputDecoration(labelText: '호스트 주소', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link), hintText: 'localhost')),
              const SizedBox(height: 16),
              TextField(controller: portController, decoration: const InputDecoration(labelText: '포트', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers), hintText: '5432'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(controller: typeController, decoration: const InputDecoration(labelText: 'DB 타입', border: OutlineInputBorder(), prefixIcon: Icon(Icons.storage), hintText: 'PostgreSQL')),
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
              final type = typeController.text.trim().isEmpty ? 'PostgreSQL' : typeController.text.trim();

              if (name.isEmpty || host.isEmpty || port.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이름, 호스트, 포트는 필수입니다.'), backgroundColor: Colors.red));
                }
                return;
              }

              final address = '$host:$port';
              final updatedServer = server.copyWith(name: name, address: address, type: type);

              try {
                await _serverDao.updateServer(updatedServer);
                _loadServers();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버 정보가 수정되었습니다.'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('서버 정보 수정 실패: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteServerDialog(ServerModel server) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('서버 삭제'),
        content: Text('${server.name} 서버를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _serverDao.deleteServer(server.id!);
                _loadServers();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버가 삭제되었습니다.'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('서버 삭제 중 오류: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('서버 선택'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6366F1), Color(0xFFF8F9FA)], stops: [0.0, 0.1]),
        ),
        child: Column(
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
                          const Text('서버 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: Icon(_showAddForm ? Icons.close : Icons.add),
                            onPressed: () {
                              setState(() {
                                _showAddForm = !_showAddForm;
                                if (!_showAddForm) {
                                  _isTestServer = false;
                                  _nameController.clear();
                                  _hostController.clear();
                                  _portController.clear();
                                  _typeController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (_showAddForm) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('테스트 서버 추가', style: TextStyle(fontSize: 16)),
                            Switch(
                              value: _isTestServer,
                              onChanged: (value) {
                                setState(() {
                                  _isTestServer = value;
                                  if (_isTestServer) {
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
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(controller: _nameController, decoration: const InputDecoration(labelText: '서버 이름', border: OutlineInputBorder(), prefixIcon: Icon(Icons.dns))),
                        const SizedBox(height: 16),
                        TextField(controller: _hostController, decoration: const InputDecoration(labelText: '호스트 주소', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link), hintText: 'localhost')),
                        const SizedBox(height: 16),
                        TextField(controller: _portController, decoration: const InputDecoration(labelText: '포트', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers), hintText: '5432'), keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        TextField(controller: _typeController, decoration: const InputDecoration(labelText: 'DB 타입', border: OutlineInputBorder(), prefixIcon: Icon(Icons.storage), hintText: 'PostgreSQL')),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addServer,
                            icon: const Icon(Icons.add),
                            label: const Text('서버 추가'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                          ),
                        ),
                      ],
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
                      itemCount: _servers.length,
                      itemBuilder: (context, index) {
                        final server = _servers[index];
                        final isTestServer = server.address == '127.0.0.1:5432';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: InkWell(
                            onTap: () async {
                              ServerModel? targetServer = server;
                              bool needsAuth = (targetServer.username == null || targetServer.username!.isEmpty) && (targetServer.password == null || targetServer.password!.isEmpty);

                              if (needsAuth) {
                                targetServer = await _showAuthDialog(server, isTest: isTestServer);
                              }

                              if (!mounted || targetServer == null) return;

                              Navigator.pushNamed(context, '/database-selection', arguments: targetServer.toMap());
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isTestServer ? Colors.grey : (server.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                child: const Icon(Icons.dns, color: Colors.white),
                              ),
                              title: Text(server.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(server.address),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(label: Text(server.type), backgroundColor: const Color(0xFFEDE9FE), labelStyle: const TextStyle(color: Color(0xFF6366F1))),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) async {
                                      if (value == 'edit_server') {
                                        _showEditServerDialog(server);
                                      } else if (value == 'edit_auth') {
                                        _showAuthDialog(server);
                                      } else if (value == 'delete') {
                                        _showDeleteServerDialog(server);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem<String>(value: 'edit_server', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('서버 정보 수정')])),
                                      const PopupMenuItem<String>(value: 'edit_auth', child: Row(children: [Icon(Icons.security, size: 20), SizedBox(width: 8), Text('인증 정보 수정')])),
                                      const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('삭제', style: TextStyle(color: Colors.red))])),
                                    ],
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
}
