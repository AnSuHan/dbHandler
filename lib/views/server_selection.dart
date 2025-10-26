import 'package:flutter/material.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
  final List<Server> servers = [
    Server(name: 'Local Server', address: 'localhost:5432', type: 'PostgreSQL', isConnected: true),
    Server(name: 'Production Server', address: '192.168.1.100:5432', type: 'PostgreSQL', isConnected: false),
    Server(name: 'Test Server', address: 'test.example.com:5432', type: 'MySQL', isConnected: false),
  ];

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
                      const Text(
                        '서버 추가',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: '서버 이름',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.dns),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: '호스트 주소',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: '포트',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // 서버 추가 로직
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('서버가 추가되었습니다.')),
                            );
                          },
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
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                itemCount: servers.length,
                itemBuilder: (context, index) {
                  final server = servers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
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
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/database-selection',
                                arguments: server,
                              );
                            },
                          ),
                        ],
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

class Server {
  final String name;
  final String address;
  final String type;
  final bool isConnected;

  Server({
    required this.name,
    required this.address,
    required this.type,
    required this.isConnected,
  });
}

