import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:postgres/postgres.dart';

import '../../l10n/LocalizationManager.dart';
import '../../sqflite/models/server_model.dart';

class TableSelectionController extends GetxController {
  final ServerModel server;
  final String database;

  final tables = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  TableSelectionController({
    required this.server,
    required this.database,
  });

  @override
  void onInit() {
    super.onInit();
    loadTables();
  }

  Future<PostgreSQLConnection> getConnection() async {
    final host = server.address.split(':')[0];
    final port = int.parse(server.address.split(':')[1]);
    final connection = PostgreSQLConnection(
      host,
      port,
      database,
      username: 'postgres',
      password: '0000',
    );
    await connection.open();
    return connection;
  }

  Future<void> loadRowCount(int index) async {
    final tableName = tables[index]['name'] as String;
    PostgreSQLConnection? connection;
    try {
      connection = await getConnection();
      final rowCountResult = await connection.query('SELECT COUNT(*) FROM "$tableName"');
      tables[index]['rows'] = rowCountResult.first[0] as int;
      tables.refresh();
    } catch (e) {
      tables[index]['rows'] = '오류';
      tables.refresh();
    } finally {
      await connection?.close();
    }
  }

  Future<void> loadAllRowCounts() async {
    List<Future> futures = [];
    for (int i = 0; i < tables.length; i++) {
      futures.add(loadRowCount(i));
    }
    await Future.wait(futures);
  }

  Future<void> loadTables() async {
    isLoading.value = true;

    try {
      final connection = await getConnection();
      final results = await connection.query('''
        SELECT
            t.table_name,
            COUNT(c.column_name) AS column_count
        FROM
            information_schema.tables AS t
        LEFT JOIN
            information_schema.columns AS c ON t.table_schema = c.table_schema AND t.table_name = c.table_name
        WHERE
            t.table_schema NOT IN ('pg_catalog', 'information_schema') AND t.table_type = 'BASE TABLE'
        GROUP BY
            t.table_name
        ORDER BY
            t.table_name;
      ''');

      tables.value = results.map((row) {
        return {
          'name': row[0] as String,
          'columns': row[1] as int,
          'rows': '조회 중...',
        };
      }).toList();

      isLoading.value = false;
      loadAllRowCounts();

      await connection.close();
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        intl.getString((l) => l.failedToLoadTable),
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> performTableOperation(
      Future<void> Function(PostgreSQLConnection) operation,
      String successMessage,
      String failureMessage,
      ) async {
    isLoading.value = true;

    try {
      final connection = await getConnection();
      await operation(connection);
      await connection.close();

      Get.snackbar(
        successMessage,
        '',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        failureMessage,
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }

    await loadTables();
  }

  Future<void> createTable(String tableName) async {
    await performTableOperation(
          (conn) => conn.query('CREATE TABLE "$tableName" (id SERIAL PRIMARY KEY);'),
      intl.getStringWithParams(((l, params) => l.tableCreationSuccess(params)), tableName),
      intl.getString((l) => l.tableCreationFailure),
    );
  }

  Future<void> renameTable(String oldName, String newName) async {
    await performTableOperation(
          (conn) => conn.query('ALTER TABLE "$oldName" RENAME TO "$newName"'),
      intl.getStringWithMultiParams(
            (l, params) => l.renameTableSuccess(params[0], params[1]),
        [oldName, newName],
      ),
      intl.getString((l) => l.renameTableFailure),
    );
  }

  Future<void> deleteTable(String tableName) async {
    await performTableOperation(
          (conn) => conn.query('DROP TABLE "$tableName"'),
      intl.getStringWithParams((l, param) => l.deleteTableSuccess(param), tableName),
      intl.getString((l) => l.deleteTableFailure),
    );
  }
}