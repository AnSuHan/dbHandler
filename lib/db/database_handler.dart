// lib/db/database_handler.dart
import 'package:db_handler/sqflite/models/server_model.dart';
import 'package:db_handler/stateManagement/setState/join_definition.dart';

abstract class DatabaseHandler {
  // 서버 관리 메서드
  Future<List<ServerModel>> getServers();
  Future<void> insertServer(ServerModel server);
  Future<void> updateServer(ServerModel server);
  Future<void> deleteServer(int serverId);

  // 데이터베이스 관리 메서드
  Future<List<Map<String, dynamic>>> getDatabases();
  Future<void> createDatabase(String dbName);
  Future<void> renameDatabase(String oldName, String newName);
  Future<void> deleteDatabase(String dbName);

  // 테이블 관리 메서드
  Future<List<Map<String, dynamic>>> getTables(String databaseName);
  Future<void> createTable(String tableName, Map<String, String> columns);
  Future<void> renameTable(String oldName, String newName, {String schema = 'public'});
  Future<void> deleteTable(String tableName, {String schema = 'public'});

  // 컬럼 관리 메서드
  Future<List<Map<String, dynamic>>> getColumns(String tableName);
  Future<String?> getPrimaryKey(String tableName);
  Future<void> addColumn(String tableName, String columnName, String dataType, String constraints);
  Future<void> modifyColumn(String tableName, String oldColumnName, String newColumnName, String newDataType, String newConstraints);
  Future<void> deleteColumn(String tableName, String columnName);

  // 데이터 조회/조작 메서드
  Future<List<Map<String, dynamic>>> getData(String tableName);
  Future<List<Map<String, dynamic>>> getDataWithFilters(
      String tableName, {
        List<Map<String, dynamic>>? filters,
        List<Map<String, dynamic>>? sorts,
        List<String>? groupByColumns,
      });
  Future<void> addRow(String tableName, Map<String, dynamic> data);
  Future<void> updateRow(String tableName, Map<String, dynamic> data, String pkColumn, dynamic pkValue);
  Future<void> updateCell(String tableName, String columnName, dynamic newValue, String pkColumn, dynamic pkValue);
  Future<void> deleteRow(String tableName, String pkColumn, dynamic pkValue);

  // 트랜잭션 메서드
  Future<void> runInTransaction(Future<void> Function() operation);

  // 캐시 관리 메서드
  void clearCache();

  // 특정 데이터베이스의 테이블 개수 조회
  Future<int> getTableCount(String databaseName);

  // JOIN 뷰 메서드

  /// DB가 지원하는 JOIN 타입 목록 (기본: 모두 지원)
  List<JoinType> get supportedJoinTypes => JoinType.values;

  Future<List<Map<String, dynamic>>> getJoinedColumns(JoinDefinition joinDef);
  Future<List<Map<String, dynamic>>> getJoinedData(JoinDefinition joinDef);
  Future<List<Map<String, dynamic>>> getJoinedDataWithFilters(
      JoinDefinition joinDef, {
        List<Map<String, dynamic>>? filters,
        List<Map<String, dynamic>>? sorts,
        List<String>? groupByColumns,
      });

  /// JOIN 뷰에서 셀 수정: 원본 테이블에 대해 UPDATE 실행
  Future<void> updateJoinedCell(
      String sourceTable, String sourceColumn, dynamic newValue,
      String pkColumn, dynamic pkValue);
}