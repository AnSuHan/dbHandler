// ignore_for_file: file_names
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../../db/database_handler.dart';
import '../../db/database_handler_factory.dart';
import '../../l10n/LocalizationManager.dart';
import '../../sqflite/models/server_model.dart';
import '../../stateManagement/setState/join_definition.dart';

class TableSelectionController extends GetxController {
  final ServerModel server;
  final String database;
  late final DatabaseHandler _dbHandler;

  final tables = <Map<String, dynamic>>[].obs;
  final joinDefinitions = <JoinDefinition>[].obs;
  final isLoading = true.obs;

  /// 숨길 실제 테이블 이름 집합
  final hiddenRealTables = <String>{}.obs;

  /// 숨길 가상 테이블(JOIN 뷰) 이름 집합
  final hiddenJoinViews = <String>{}.obs;

  /// 숨길 스키마 이름 집합 (해당 스키마의 모든 테이블 숨김)
  final hiddenSchemas = <String>{}.obs;

  final successMessage = Rxn<String>();
  final errorMessage = Rxn<String>();

  TableSelectionController({
    required this.server,
    required this.database,
  }) {
    _dbHandler = DatabaseHandlerFactory.createHandler(server, databaseName: database);
  }

  DatabaseHandler get dbHandler => _dbHandler;

  @override
  void onInit() {
    super.onInit();
    loadTables();
    _loadJoinDefinitions();
    _loadHiddenTables();
  }

  // ========== 가시성(숨김) 관리 ==========

  String get _hiddenPrefsKey => 'hidden_tables|${server.address}|$database';

  /// SharedPreferences에서 숨김 설정을 다시 읽어 메모리에 반영
  Future<void> reloadHiddenTables() => _loadHiddenTables();

  Future<void> _loadHiddenTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_hiddenPrefsKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        hiddenRealTables
          ..clear()
          ..addAll((map['hiddenRealTables'] as List<dynamic>? ?? []).cast<String>());
        hiddenJoinViews
          ..clear()
          ..addAll((map['hiddenJoinViews'] as List<dynamic>? ?? []).cast<String>());
        hiddenSchemas
          ..clear()
          ..addAll((map['hiddenSchemas'] as List<dynamic>? ?? []).cast<String>());
      }
    } catch (_) {}
  }

  Future<void> _persistHiddenTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'hiddenRealTables': hiddenRealTables.toList(),
        'hiddenJoinViews': hiddenJoinViews.toList(),
        'hiddenSchemas': hiddenSchemas.toList(),
      };
      await prefs.setString(_hiddenPrefsKey, jsonEncode(map));
    } catch (_) {}
  }

  void toggleRealTableVisibility(String tableName) {
    if (hiddenRealTables.contains(tableName)) {
      hiddenRealTables.remove(tableName);
    } else {
      hiddenRealTables.add(tableName);
    }
    _persistHiddenTables();
  }

  void toggleJoinViewVisibility(String name) {
    if (hiddenJoinViews.contains(name)) {
      hiddenJoinViews.remove(name);
    } else {
      hiddenJoinViews.add(name);
    }
    _persistHiddenTables();
  }

  void toggleSchemaVisibility(String schema) {
    if (hiddenSchemas.contains(schema)) {
      hiddenSchemas.remove(schema);
    } else {
      hiddenSchemas.add(schema);
    }
    _persistHiddenTables();
  }

  /// 모든 테이블·JOIN 뷰 숨기기
  void hideAll() {
    hiddenRealTables.addAll(tables.map((t) => t['name'] as String));
    hiddenJoinViews.addAll(joinDefinitions.map((j) => j.name));
    _persistHiddenTables();
  }

  /// 모든 숨김 해제 (스키마 포함)
  void showAll() {
    hiddenRealTables.clear();
    hiddenJoinViews.clear();
    hiddenSchemas.clear();
    _persistHiddenTables();
  }

  /// 현재 표시 중인 테이블 수 (숨김·스키마 제외)
  int get visibleTableCount {
    final visibleReal = tables.where((t) =>
        !hiddenSchemas.contains(t['schema'] as String? ?? 'public') &&
        !hiddenRealTables.contains(t['name'] as String)).length;
    final visibleJoin = joinDefinitions
        .where((j) => !hiddenJoinViews.contains(j.name))
        .length;
    return visibleReal + visibleJoin;
  }

  int get totalTableCount => tables.length + joinDefinitions.length;

  /// 이 서버의 모든 데이터베이스 숨김 설정을 읽어 반환
  Future<Map<String, Map<String, List<String>>>> _readAllServerHiddenConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'hidden_tables|${server.address}|';
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix));
    final result = <String, Map<String, List<String>>>{};
    for (final key in keys) {
      final db = key.substring(prefix.length);
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        result[db] = {
          'hiddenRealTables': (m['hiddenRealTables'] as List<dynamic>? ?? []).cast<String>(),
          'hiddenJoinViews': (m['hiddenJoinViews'] as List<dynamic>? ?? []).cast<String>(),
        };
      } catch (_) {}
    }
    return result;
  }

  /// 숨김 설정을 JSON 파일로 내보내기 (서버 단위)
  Future<void> exportHiddenConfig() async {
    try {
      final allConfigs = await _readAllServerHiddenConfigs();
      // 현재 DB가 아직 저장되지 않았어도 포함
      allConfigs[database] = {
        'hiddenRealTables': hiddenRealTables.toList(),
        'hiddenJoinViews': hiddenJoinViews.toList(),
      };

      final map = {
        'version': 2,
        'serverAddress': server.address,
        'databases': allConfigs,
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(map);

      final safeName = server.address.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '숨김 설정 내보내기',
        fileName: 'hidden_tables_$safeName.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (savePath != null) {
        await File(savePath).writeAsString(jsonStr, flush: true);
        successMessage.value = '숨김 설정 내보내기 완료 (${allConfigs.length}개 데이터베이스)';
      }
    } catch (e) {
      errorMessage.value = '내보내기 실패: $e';
    }
  }

  /// 숨김 설정을 JSON 파일에서 가져오기 (서버 단위 v2 및 스키마 단위 v1 호환)
  Future<void> importHiddenConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '숨김 설정 가져오기',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      final content = await File(path).readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;

      final version = map['version'] as int? ?? 1;

      if (version >= 2 && map.containsKey('databases')) {
        // 서버 단위 포맷: 현재 데이터베이스 항목 적용, 나머지도 저장
        final prefs = await SharedPreferences.getInstance();
        final databases = map['databases'] as Map<String, dynamic>;
        for (final entry in databases.entries) {
          final db = entry.key;
          final dbMap = entry.value as Map<String, dynamic>;
          final key = 'hidden_tables|${server.address}|$db';
          await prefs.setString(key, jsonEncode({
            'hiddenRealTables': dbMap['hiddenRealTables'] ?? [],
            'hiddenJoinViews': dbMap['hiddenJoinViews'] ?? [],
          }));
        }
        // 현재 DB 설정을 메모리에 반영
        final current = databases[database] as Map<String, dynamic>?;
        hiddenRealTables
          ..clear()
          ..addAll((current?['hiddenRealTables'] as List<dynamic>? ?? []).cast<String>());
        hiddenJoinViews
          ..clear()
          ..addAll((current?['hiddenJoinViews'] as List<dynamic>? ?? []).cast<String>());
        successMessage.value = '숨김 설정 가져오기 완료 (${databases.length}개 데이터베이스)';
      } else {
        // 이전 스키마 단위 포맷 (v1) 호환
        hiddenRealTables
          ..clear()
          ..addAll((map['hiddenRealTables'] as List<dynamic>? ?? []).cast<String>());
        hiddenJoinViews
          ..clear()
          ..addAll((map['hiddenJoinViews'] as List<dynamic>? ?? []).cast<String>());
        await _persistHiddenTables();
        successMessage.value = '숨김 설정 가져오기 완료';
      }
    } catch (e) {
      errorMessage.value = '가져오기 실패: $e';
    }
  }

  // ========== JOIN 정의 관리 ==========

  String get _joinPrefsKey => JoinDefinition.prefsKey(server.address, database);

  Future<void> _loadJoinDefinitions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_joinPrefsKey);
      joinDefinitions.value = JoinDefinition.fromPrefsString(raw);
    } catch (_) {}
  }

  Future<void> _persistJoinDefinitions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_joinPrefsKey, JoinDefinition.toPrefsString(joinDefinitions));
    } catch (_) {}
  }

  void addJoinDefinition(JoinDefinition def) {
    joinDefinitions.add(def);
    _persistJoinDefinitions();
  }

  void updateJoinDefinition(int index, JoinDefinition def) {
    if (index >= 0 && index < joinDefinitions.length) {
      joinDefinitions[index] = def;
      _persistJoinDefinitions();
    }
  }

  void removeJoinDefinition(int index) {
    if (index >= 0 && index < joinDefinitions.length) {
      joinDefinitions.removeAt(index);
      _persistJoinDefinitions();
    }
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
          'columns': (table['column_count'] as num?)?.toInt() ?? 0,
          'rows': (table['row_count'] as num?)?.toInt() ?? 0,
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