import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/server_model.dart';

/// 웹 플랫폼용 저장소 (SharedPreferences 사용)
class WebStorageService {
  static const String _serversKey = 'servers';
  static const String _lastIdKey = 'lastServerId';

  // 싱글톤 + 초기화 완료를 추적하는 Completer
  static final WebStorageService _instance = WebStorageService._internal();
  factory WebStorageService() => _instance;
  WebStorageService._internal();

  static final Completer<void> _initCompleter = Completer<void>();
  static bool _hasTestData = false;

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
// WebStorageService 클래스 내부
  Future<int> insertServer(ServerModel server) async {
    await initialize(); // 초기화 보장

    final prefs = await SharedPreferences.getInstance();
    final servers = await getAllServers();
    final lastId = prefs.getInt(_lastIdKey) ?? 0;
    final newId = lastId + 1;

    final newServer = server.copyWith(
      id: newId,
      createdAt: server.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    servers.add(newServer);
    await _saveServers(servers);
    await prefs.setInt(_lastIdKey, newId);

    return newId; // 반드시 ID 반환!
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

  /// 앱 시작 시 반드시 한 번만 호출해야 하는 초기화 메서드
  /// main()에서 await WebStorageService().initialize(); 로 사용
  Future<void> initialize() async {
    // 이미 초기화 완료된 경우 바로 리턴
    if (_initCompleter.isCompleted) {
      return _initCompleter.future;
    }

    try {
      // SharedPreferences 인스턴스 강제 생성 (초기화 트리거)
      final prefs = await SharedPreferences.getInstance();

      // 서버 데이터가 하나도 없는 경우 → 초기 테스트 데이터 삽입
      final jsonString = prefs.getString(_serversKey);
      if (jsonString == null || jsonString.isEmpty || jsonString == '[]') {
        final testServer = ServerModel(
          id: null, // insertServer 내부에서 자동 생성
          name: 'Test Local Server',
          address: 'localhost:5432',
          type: 'PostgreSQL',
          isConnected: false,
          username: null,
          password: null,
          keyFilePath: null,
          notes: '테스트 서버입니다.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await insertServer(testServer);
        _hasTestData = true;
      }

      // 초기화 성공
      _initCompleter.complete();
    } catch (e, stack) {
      // 초기화 실패 시 에러 전파
      _initCompleter.completeError(e, stack);
      rethrow;
    }

    return _initCompleter.future;
  }
}

