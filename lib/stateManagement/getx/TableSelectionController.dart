// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:postgres/postgres.dart';

import '../../db/postgres_handler.dart';
import '../../l10n/LocalizationManager.dart';
import '../../sqflite/models/server_model.dart';

class TableSelectionController extends GetxController {
  final ServerModel server;
  final String database;
  late final PostgresHandler _dbHandler;

  final tables = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  final successMessage = Rxn<String>();
  final errorMessage = Rxn<String>();

  TableSelectionController({
    required this.server,
    required this.database,
  }) {
    _dbHandler = PostgresHandler(server, databaseName: database);
  }

  @override
  void onInit() {
    super.onInit();
    loadTables();
  }

  void refreshTables() {
    _dbHandler.clearCache();
    loadTables();
  }

  Future<Connection> getConnection() async {
    // 내부적으로 사용하거나, _dbHandler 내부 기능을 활용할 수 있습니다.
    final host = server.address.split(':')[0];
    final port = int.parse(server.address.split(':')[1]);
    final url = 'postgres://postgres:0000@$host:$port/$database?sslmode=disable';
    return await Connection.openFromUrl(url);
  }

  Future<void> loadRowCount(int index) async {
    Connection? conn;
    try {
      conn = await getConnection();
      final tableName = tables[index]['name'];
      final result = await conn.execute('SELECT COUNT(*) AS row_count FROM "$tableName";');
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
      futures.add(loadRowCount(i));
    }
    await Future.wait(futures);
  }

  Future<void> loadTables() async {
    isLoading.value = true;
    try {
      final results = await _dbHandler.getTables(database);

      tables.value = results.map((table) {
        return {
          'name': table['name'] as String,
          'columns': table['column_count'] as int,
          'rows': '조회 중...',
        };
      }).toList();

      isLoading.value = false;
      await loadAllRowCounts();
    } catch (e) {
      isLoading.value = false;
      debugPrint("[loadTables] error: $e");
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
    }
  }

  Future<void> performTableOperation(
    Future<void> Function() operation,
    String successMsg,
    String failureMsg,
  ) async {
    isLoading.value = true;
    try {
      await operation();
      successMessage.value = successMsg;
    } catch (e) {
      errorMessage.value = '$failureMsg: $e';
    } finally {
      isLoading.value = false;
    }
    await loadTables();
  }


  Future<void> createTable(String tableName) async {
    await performTableOperation(
          () => _dbHandler.createTable(tableName, {'id': 'SERIAL PRIMARY KEY'}),
      intl.getStringWithParams(((l, params) => l.tableCreationSuccess(params)), tableName),
      intl.getString((l) => l.tableCreationFailure),
    );
  }

  Future<void> renameTable(String oldName, String newName) async {
    await performTableOperation(
          () => _dbHandler.renameTable(oldName, newName),
      intl.getStringWithMultiParams(
            (l, params) => l.renameTableSuccess(params[0], params[1]),
        [oldName, newName],
      ),
      intl.getString((l) => l.renameTableFailure),
    );
  }

  Future<void> deleteTable(String tableName) async {
    await performTableOperation(
          () => _dbHandler.deleteTable(tableName),
      intl.getStringWithParams((l, param) => l.deleteTableSuccess(param), tableName),
      intl.getString((l) => l.deleteTableFailure),
    );
  }
}