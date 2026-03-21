import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../models/server_model.dart';
import '../web_storage.dart';
import '../platform_check.dart';

class ServerDao {
  final AppDatabase _db = AppDatabase();
  late final WebStorageService _webStorage = WebStorageService();

  // 모든 서버 가져오기
  Future<List<ServerModel>> getAllServers() async {
    if (PlatformCheck.isWeb) {
      return await _webStorage.getAllServers();
    }

    final db = await _db.database;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'servers',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => ServerModel.fromJson(maps[i]));
  }

  // ID로 서버 가져오기
  Future<ServerModel?> getServerById(int id) async {
    if (PlatformCheck.isWeb) {
      final servers = await _webStorage.getAllServers();
      try {
        return servers.firstWhere((s) => s.id == id);
      } catch (e) {
        return null;
      }
    }

    final db = await _db.database;
    if (db == null) return null;

    final List<Map<String, dynamic>> maps = await db.query(
      'servers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ServerModel.fromJson(maps.first);
  }

  // 2. address + defaultSchema 조합으로 서버 존재 여부 확인 (중복 체크용)
  Future<bool> isServerExists(String address, String? defaultSchema) async {
    if (PlatformCheck.isWeb) {
      final servers = await _webStorage.getAllServers();
      return servers.any((s) =>
          s.address == address && s.defaultSchema == defaultSchema);
    }

    final db = await _db.database;
    if (db == null) return false;

    final List<Map<String, dynamic>> maps = await db.query(
      'servers',
      where: defaultSchema == null
          ? 'address = ? AND defaultSchema IS NULL'
          : 'address = ? AND defaultSchema = ?',
      whereArgs: defaultSchema == null ? [address] : [address, defaultSchema],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // 서버 추가 (중복 체크 포함)
  Future<int> insertServer(ServerModel server) async {
    // 2. 중복 체크
    final exists = await isServerExists(server.address, server.defaultSchema);
    if (exists) {
      throw Exception('동일한 주소와 스키마의 서버가 이미 존재합니다: ${server.address}');
    }

    // 웹 플랫폼
    if (PlatformCheck.isWeb) {
      return await _webStorage.insertServer(server);
    }

    // 모바일/데스크톱 (sqflite)
    final db = await _db.database;
    if (db == null) throw Exception('Database not initialized');

    // 중요: id 필드를 강제로 제거 → AUTOINCREMENT가 제대로 동작하게 함
    final Map<String, dynamic> data = server.toJson()..remove('id');

    final int newId = await db.insert(
      'servers',
      data,
      conflictAlgorithm: ConflictAlgorithm.abort, // 중복 시 에러 발생
    );

    return newId; // 이 값이 바로 방금 삽입된 서버의 ID!
  }

  // 서버 업데이트
  Future<int> updateServer(ServerModel server) async {
    if (PlatformCheck.isWeb) {
      return await _webStorage.updateServer(server);
    }

    final db = await _db.database;
    if (db == null) return 0;

    return await db.update(
      'servers',
      server.copyWith(updatedAt: DateTime.now()).toJson(),
      where: 'id = ?',
      whereArgs: [server.id],
    );
  }

  // 서버 삭제
  Future<int> deleteServer(int id) async {
    if (PlatformCheck.isWeb) {
      return await _webStorage.deleteServer(id);
    }

    final db = await _db.database;
    if (db == null) return 0;

    return await db.delete(
      'servers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 연결 상태 업데이트
  Future<int> updateConnectionStatus(int id, bool isConnected) async {
    if (PlatformCheck.isWeb) {
      return await _webStorage.updateConnectionStatus(id, isConnected);
    }

    final db = await _db.database;
    if (db == null) return 0;

    return await db.update(
      'servers',
      {
        'isConnected': isConnected ? 1 : 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 이름으로 서버 검색
  Future<List<ServerModel>> searchServers(String query) async {
    if (PlatformCheck.isWeb) {
      return await _webStorage.searchServers(query);
    }

    final db = await _db.database;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'servers',
      where: 'name LIKE ? OR address LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => ServerModel.fromJson(maps[i]));
  }

  Future<void> initialize() async {
    // 1) 웹인 경우: 로컬스토리지(WebStorageService) 초기화
    if (PlatformCheck.isWeb) {
      await _webStorage.initialize();
      print("✅ ServerDao (웹) 초기화 완료");
      return;
    }

    // 2) 앱(안드로이드/iOS/데스크톱)인 경우: SQLite(AppDatabase) 초기화
    await _db.initialize();

    // DB 핸들 가져오기
    final db = await _db.database;
    if (db == null) {
      print("❌ DB 초기화 실패: database is null");
      return;
    }

    // 3) 서버 테이블 생성
    await db.execute('''
    CREATE TABLE IF NOT EXISTS servers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      address TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'PostgreSQL',
      isConnected INTEGER NOT NULL DEFAULT 0,
      username TEXT,
      password TEXT,
      keyFilePath TEXT,
      notes TEXT,
      defaultSchema TEXT,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    );
  ''');

    // 4) address에 인덱스 추가 (중복 체크 성능 향상)
    await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_servers_address 
    ON servers(address);
  ''');

    print("✅ ServerDao (앱) 초기화 완료");
  }
}