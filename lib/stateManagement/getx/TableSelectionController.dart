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

  Future<void> loadTables() async {
    isLoading.value = true;
    try {
      final results = await _dbHandler.getTables(database);

      tables.value = results.map((table) {
        return {
          'name': table['name'] as String,
          'columns': table['column_count'] as int,
          'rows': table['row_count'], // 이미 핸들러에서 가져온 값을 즉시 사용
        };
      }).toList();

      isLoading.value = false;
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