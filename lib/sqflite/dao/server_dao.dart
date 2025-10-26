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
      return servers.firstWhere((s) => s.id == id);
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

  // 서버 추가
  Future<int> insertServer(ServerModel server) async {
    if (PlatformCheck.isWeb) {
      return await _webStorage.insertServer(server);
    }
    
    final db = await _db.database;
    if (db == null) return 0;
    
    return await db.insert('servers', server.toJson());
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
}
