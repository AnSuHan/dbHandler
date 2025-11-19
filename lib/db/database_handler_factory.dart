import 'package:db_handler/sqflite/models/server_model.dart';

import 'database_handler.dart';
import 'postgres_handler.dart';

// 핸들러 팩토리 메소드 구현
class DatabaseHandlerFactory {
  static DatabaseHandler createHandler(ServerModel server) {
    switch (server.type) {
      case 'PostgreSQL':
        return PostgresHandler(server);
    // 다른 DB 핸들러도 여기에 추가
      default:
        throw UnsupportedError('지원하지 않는 DB 타입입니다: ${server.type}');
    }
  }
}