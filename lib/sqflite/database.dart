import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'platform_check.dart';

class AppDatabase {
  // 싱글턴 인스턴스
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;
  static bool _initialized = false;
  // 이미 존재하는 initializeFfi()와 중복되지 않도록 통합된 초기화
  static final _initCompleter = Completer<void>();

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  // 초기화 (한 번만 실행)
  static Future<void> initializeFfi() async {
    if (!_initialized && (PlatformCheck.isDesktop || PlatformCheck.isWeb)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _initialized = true;
    }
  }

  // 데이터베이스 인스턴스 가져오기
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 데이터베이스 초기화
  Future<Database> _initDatabase() async {
    String path;
    if (PlatformCheck.isWeb) {
      path = 'db_handler.db';
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, 'db_handler.db');
    }

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // 테이블 생성
  Future<void> _onCreate(Database db, int version) async {
    // 서버 테이블
    await db.execute('''
      CREATE TABLE servers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        type TEXT NOT NULL,
        isConnected INTEGER NOT NULL,
        username TEXT,
        password TEXT,
        keyFilePath TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // 초기 테스트 데이터 삽입
    await db.insert('servers', {
      'name': 'Test Local Server',
      'address': 'localhost:5432',
      'type': 'PostgreSQL',
      'isConnected': 0,
      'username': null,
      'password': null,
      'keyFilePath': null,
      'notes': '테스트 서버입니다.',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // 데이터베이스 업그레이드
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE servers ADD COLUMN keyFilePath TEXT');
    }
  }

  // 데이터베이스 닫기
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // 데이터베이스 삭제 (디버깅용)
  Future<void> deleteDatabase() async {
    String path;
    if (PlatformCheck.isWeb) {
      path = 'db_handler.db';
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, 'db_handler.db');
    }
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// 앱 시작 시 반드시 한 번만 호출해야 하는 전체 초기화 메서드
  /// - FFI 초기화 (데스크톱/모바일)
  /// - 데이터베이스 연결 준비
  Future<void> initialize() async {
    // 이미 초기화 중이거나 완료된 경우 바로 리턴 (중복 방지)
    if (_initCompleter.isCompleted) {
      return _initCompleter.future;
    }

    try {
      // 1. 플랫폼이 sqflite_ffi를 지원하는 경우에만 FFI 초기화
      await initializeFfi();

      // 2. 데이터베이스 미리 열어두기 (선택적 프리로딩)
      await _instance.database; // database getter 호출 → _initDatabase 실행

      // 초기화 완료 알림
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e, s) {
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, s);
      }
      rethrow;
    }

    return _initCompleter.future;
  }
}
