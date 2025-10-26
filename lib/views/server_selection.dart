import 'package:flutter/material.dart';
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

  // 폼 입력 컨트롤러
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
    setState(() {
      _isLoading = true;
    });
    try {
      final servers = await _serverDao.getAllServers();
      setState(() {
        _servers = servers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 목록을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _showEditServerDialog(ServerModel server) async {
    final nameController = TextEditingController(text: server.name);
    final hostController = TextEditingController(text: server.address.split(':')[0]);
    final portController = TextEditingController(text: server.address.split(':')[1]);
    final typeController = TextEditingController(text: server.type);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('서버 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '서버 이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: '호스트 주소',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: '포트',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: '데이터베이스 타입',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final host = hostController.text.trim();
              final port = portController.text.trim();
              final type = typeController.text.trim();

              if (name.isEmpty || host.isEmpty || port.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('모든 필드를 입력해주세요.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              final address = '$host:$port';
              final updatedServer = server.copyWith(
                name: name,
                address: address,
                type: type,
                updatedAt: DateTime.now(),
              );

              try {
                await _serverDao.updateServer(updatedServer);
                _loadServers();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('서버가 수정되었습니다.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('서버 수정 중 오류가 발생했습니다: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _serverDao.deleteServer(server.id!);
                _loadServers();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('서버가 삭제되었습니다.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('서버 삭제 중 오류가 발생했습니다: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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

  Future<void> _addServer() async {
    // 입력값 가져오기
    final name = _nameController.text.trim();
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    final type = _typeController.text.trim().isEmpty 
        ? 'PostgreSQL' 
        : _typeController.text.trim();

    // 유효성 검사
    if (name.isEmpty || host.isEmpty || port.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 필드를 입력해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 주소 생성
    final address = '$host:$port';

    // 중복 체크
    final isDuplicate = _servers.any((server) => server.address == address);
    
    if (isDuplicate) {
      // 알림 다이얼로그 표시
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('서버 추가 실패'),
            content: const Text('이미 같은 주소와 포트의 서버가 존재합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 서버 추가
    final newServer = ServerModel(
      name: name,
      address: address,
      type: type,
      isConnected: false,
    );

    try {
      await _serverDao.insertServer(newServer);
      
      // 입력 필드 초기화
      _nameController.clear();
      _hostController.clear();
      _portController.clear();
      _typeController.clear();

      // 폼 숨김
      setState(() {
        _showAddForm = false;
      });

      // 목록 새로고침
      _loadServers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버가 추가되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('서버 추가 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6366F1), Color(0xFFF8F9FA)],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '서버 추가',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_showAddForm)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _showAddForm = false;
                                  _nameController.clear();
                                  _hostController.clear();
                                  _portController.clear();
                                  _typeController.clear();
                                });
                              },
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                setState(() {
                                  _showAddForm = true;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_showAddForm) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: '서버 이름',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.dns),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: '호스트 주소 (IP 또는 도메인)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                            hintText: 'localhost',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: '포트',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                            hintText: '5432',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: '데이터베이스 타입',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.storage),
                            hintText: 'PostgreSQL',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addServer,
                            icon: const Icon(Icons.add),
                            label: const Text('서버 추가'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
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
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: InkWell(
                            onTap: () {
                              // 카드 전체를 클릭하면 데이터베이스 선택 페이지로 이동
                              Navigator.pushNamed(
                                context,
                                '/database-selection',
                                arguments: server.toMap(),
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: server.isConnected
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                child: const Icon(
                                  Icons.dns,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                server.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(server.address),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(server.type),
                                    backgroundColor: const Color(0xFFEDE9FE),
                                    labelStyle: const TextStyle(color: Color(0xFF6366F1)),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        _showEditServerDialog(server);
                                      } else if (value == 'delete') {
                                        _showDeleteServerDialog(server);
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
