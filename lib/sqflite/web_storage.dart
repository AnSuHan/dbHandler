import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/server_model.dart';

/// 웹 플랫폼용 저장소 (SharedPreferences 사용)
class WebStorageService {
  static const String _serversKey = 'servers';
  static const String _lastIdKey = 'lastServerId';

  // 모든 서버 가져오기
  Future<List<ServerModel>> getAllServers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_serversKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      // 초기 테스트 데이터
      final testServer = ServerModel(
        id: 1,
        name: 'Test Local Server',
        address: 'localhost:5432',
        type: 'PostgreSQL',
        isConnected: false,
        notes: '테스트 서버입니다.',
      );
      await insertServer(testServer);
      return [testServer];
    }
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => ServerModel.fromJson(json)).toList();
  }

  // 서버 추가
  Future<int> insertServer(ServerModel server) async {
    final prefs = await SharedPreferences.getInstance();
    final servers = await getAllServers();
    final lastId = prefs.getInt(_lastIdKey) ?? 0;
    final newId = lastId + 1;
    
    final newServer = server.copyWith(id: newId);
    servers.add(newServer);
    
    await _saveServers(servers);
    await prefs.setInt(_lastIdKey, newId);
    return newId;
  }

  // 서버 업데이트
  Future<int> updateServer(ServerModel server) async {
    final servers = await getAllServers();
    final index = servers.indexWhere((s) => s.id == server.id);
    
    if (index != -1) {
      servers[index] = server.copyWith(updatedAt: DateTime.now());
      await _saveServers(servers);
      return 1;
    }
    return 0;
  }

  // 서버 삭제
  Future<int> deleteServer(int id) async {
    final servers = await getAllServers();
    servers.removeWhere((s) => s.id == id);
    await _saveServers(servers);
    return 1;
  }

  // 내부: 서버 목록 저장
  Future<void> _saveServers(List<ServerModel> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(servers.map((s) => s.toJson()).toList());
    await prefs.setString(_serversKey, jsonString);
  }

  // 연결 상태 업데이트
  Future<int> updateConnectionStatus(int id, bool isConnected) async {
    final servers = await getAllServers();
    final index = servers.indexWhere((s) => s.id == id);
    
    if (index != -1) {
      servers[index] = servers[index].copyWith(
        isConnected: isConnected,
        updatedAt: DateTime.now(),
      );
      await _saveServers(servers);
      return 1;
    }
    return 0;
  }

  // 이름으로 서버 검색
  Future<List<ServerModel>> searchServers(String query) async {
    final servers = await getAllServers();
    final lowerQuery = query.toLowerCase();
    return servers.where((server) {
      return server.name.toLowerCase().contains(lowerQuery) ||
          server.address.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

