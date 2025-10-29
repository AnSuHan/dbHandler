import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'platform_check.dart';

class AppDatabase {
  // 싱글턴 인스턴스
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;
  static bool _initialized = false;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  // 초기화 (한 번만 실행)
  static Future<void> initializeFfi() async {
    if (!_initialized && PlatformCheck.supportsSqflite) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _initialized = true;
    }
  }

  // 데이터베이스 인스턴스 가져오기
  Future<Database?> get database async {
    // 웹 플랫폼에서는 null 반환
    if (PlatformCheck.isWeb) return null;
    
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 데이터베이스 초기화
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'db_handler.db');

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
    await db?.close();
    _database = null;
  }

  // 데이터베이스 삭제 (디버깅용)
  Future<void> deleteDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'db_handler.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
