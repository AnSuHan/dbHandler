// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:postgres/postgres.dart';

import '../../l10n/LocalizationManager.dart';
import '../../sqflite/models/server_model.dart';

class TableSelectionController extends GetxController {
  final ServerModel server;
  final String database;

  final tables = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  final successMessage = Rxn<String>();
  final errorMessage = Rxn<String>();

  TableSelectionController({
    required this.server,
    required this.database,
  });

  @override
  void onInit() {
    super.onInit();
    loadTables();
  }

  Future<Connection> getConnection() async {
    final host = server.address.split(':')[0];
    final port = int.parse(server.address.split(':')[1]);

    // Postgres URL 구성 (SSL 비활성화)
    final url = 'postgres://postgres:0000@$host:$port/$database?sslmode=disable';

    // Connection.openFromUrl() 사용
    final conn = await Connection.openFromUrl(url);

    return conn;
  }

  Future<void> loadRowCount(int index) async {
    Connection? conn;

    try {
      conn = await getConnection();

      final tableName = tables[index]['name'];

      final result = await conn.execute(
          'SELECT COUNT(*) AS row_count FROM "$tableName";'
      );

      final map = result.first.toColumnMap();

      tables[index]['rows'] = (map['row_count'] is BigInt)
          ? (map['row_count'] as BigInt).toInt()
          : (map['row_count'] as int);

    } catch (_) {
      tables[index]['rows'] = 'ERR';
    } finally {
      await conn?.close();
    }
  }

  Future<void> loadAllRowCounts() async {
    final futures = <Future>[];

    for (int i = 0; i < tables.length; i++) {
      futures.add(loadRowCount(i));   // loadRowCount 내부에서 getConnection() 호출됨
    }

    await Future.wait(futures);
  }

  Future<void> loadTables() async {
    isLoading.value = true;

    Connection? connection;

    try {
      connection = await getConnection();

      final results = await connection.execute('''
      SELECT
          t.table_name AS name,
          COUNT(c.column_name) AS column_count
      FROM
          information_schema.tables AS t
      LEFT JOIN
          information_schema.columns AS c
          ON t.table_schema = c.table_schema
          AND t.table_name = c.table_name
      WHERE
          t.table_schema NOT IN ('pg_catalog', 'information_schema')
          AND t.table_type = 'BASE TABLE'
      GROUP BY
          t.table_name
      ORDER BY
          t.table_name;
    ''');

      tables.value = results.map((row) {
        final map = row.toColumnMap();

        return {
          'name': map['name'] as String,
          'columns': (map['column_count'] is BigInt)
              ? (map['column_count'] as BigInt).toInt()
              : (map['column_count'] as int),
          'rows': '조회 중...',
        };
      }).toList();

      isLoading.value = false;

      // Connection 닫기 전에 실행해야 함!!
      await loadAllRowCounts();

    } catch (e) {
      isLoading.value = false;
      debugPrint("[loadTables] error: $e");
      // Overlay가 준비된 후 스낵바 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.isSnackbarOpen) Get.closeAllSnackbars();

        Get.snackbar(
          intl.getString((l) => l.failedToLoadTable),
          e.toString(),
          backgroundColor: Colors.red,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      });
    } finally {
      await connection?.close();
    }
  }

  Future<void> performTableOperation(
    Future<void> Function(Connection) operation,  // 타입 변경
    String successMsg,
    String failureMsg,
  ) async {
    isLoading.value = true;

    try {
      final connection = await getConnection();  // Connection 반환 (이미 수정됨)
      await operation(connection);               // query() → execute()는 호출자에서 처리
      await connection.close();

      successMessage.value = successMsg;
    } catch (e) {
      errorMessage.value = '$failureMsg: $e';
    } finally {
      isLoading.value = false;  // 추가: 로딩 상태 정리
    }

    await loadTables();
  }


  Future<void> createTable(String tableName) async {
    await performTableOperation(
          (conn) => conn.execute('CREATE TABLE "$tableName" (id SERIAL PRIMARY KEY);'),
      intl.getStringWithParams(((l, params) => l.tableCreationSuccess(params)), tableName),
      intl.getString((l) => l.tableCreationFailure),
    );
  }

  Future<void> renameTable(String oldName, String newName) async {
    await performTableOperation(
          (conn) => conn.execute('ALTER TABLE "$oldName" RENAME TO "$newName"'),
      intl.getStringWithMultiParams(
            (l, params) => l.renameTableSuccess(params[0], params[1]),
        [oldName, newName],
      ),
      intl.getString((l) => l.renameTableFailure),
    );
  }

  Future<void> deleteTable(String tableName) async {
    await performTableOperation(
          (conn) => conn.execute('DROP TABLE "$tableName"'),
      intl.getStringWithParams((l, param) => l.deleteTableSuccess(param), tableName),
      intl.getString((l) => l.deleteTableFailure),
    );
  }
}