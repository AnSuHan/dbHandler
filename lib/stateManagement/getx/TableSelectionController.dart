// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../db/database_handler.dart';
import '../../db/database_handler_factory.dart';
import '../../l10n/LocalizationManager.dart';
import '../../sqflite/models/server_model.dart';

class TableSelectionController extends GetxController {
  final ServerModel server;
  final String database;
  late final DatabaseHandler _dbHandler;

  final tables = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  final successMessage = Rxn<String>();
  final errorMessage = Rxn<String>();

  TableSelectionController({
    required this.server,
    required this.database,
  }) {
    _dbHandler = DatabaseHandlerFactory.createHandler(server, databaseName: database);
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
          'schema': table['table_schema'] as String? ?? 'public',
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
    final idType = server.type == 'MySQL'
        ? 'INT AUTO_INCREMENT PRIMARY KEY'
        : 'SERIAL PRIMARY KEY';
    await performTableOperation(
          () => _dbHandler.createTable(tableName, {'id': idType}),
      intl.getStringWithParams(((l, params) => l.tableCreationSuccess(params)), tableName),
      intl.getString((l) => l.tableCreationFailure),
    );
  }

  Future<void> renameTable(String oldName, String newName, {String schema = 'public'}) async {
    await performTableOperation(
          () => _dbHandler.renameTable(oldName, newName, schema: schema),
      intl.getStringWithMultiParams(
            (l, params) => l.renameTableSuccess(params[0], params[1]),
        [oldName, newName],
      ),
      intl.getString((l) => l.renameTableFailure),
    );
  }

  Future<void> deleteTable(String tableName, {String schema = 'public'}) async {
    await performTableOperation(
          () => _dbHandler.deleteTable(tableName, schema: schema),
      intl.getStringWithParams((l, param) => l.deleteTableSuccess(param), tableName),
      intl.getString((l) => l.deleteTableFailure),
    );
  }
}