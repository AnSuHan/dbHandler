import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정 관리를 위한 BLoC 패턴 싱글턴 클래스
class SettingsBloc {
  // 싱글턴 인스턴스
  static final SettingsBloc _instance = SettingsBloc._internal();

  // Factory 생성자 - 항상 같은 인스턴스 반환
  factory SettingsBloc() => _instance;

  // Private 생성자
  SettingsBloc._internal() {
    _initialize();
  }

  // SharedPreferences 인스턴스
  SharedPreferences? _prefs;

  // ========== 스트림 컨트롤러 ==========
  // 설정 파일
  // 설정 구조의 현재 버전 정의 (필요에 따라 변경)
  final String _SETTINGS_VERSION = '0.0.2';

  // 언어 설정
  final _localeController = StreamController<Locale>.broadcast();
  Stream<Locale> get localeStream => _localeController.stream;
  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  // 테마 설정
  final _themeModeController = StreamController<ThemeMode>.broadcast();
  Stream<ThemeMode> get themeModeStream => _themeModeController.stream;
  ThemeMode _currentThemeMode = ThemeMode.system;
  ThemeMode get currentThemeMode => _currentThemeMode;
  final String _keyThemeMode = 'theme_mode_index'; // 추가 필요

  // 즐겨찾기 서버 목록
  final _favoriteServersController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get favoriteServersStream => _favoriteServersController.stream;
  List<String> _favoriteServers = [];
  List<String> get favoriteServers => List.unmodifiable(_favoriteServers);

  // 즐겨찾기 데이터베이스 목록 (서버별)
  final _favoriteDatabasesController = StreamController<Map<String, List<String>>>.broadcast();
  Stream<Map<String, List<String>>> get favoriteDatabasesStream => _favoriteDatabasesController.stream;
  Map<String, List<String>> _favoriteDatabases = {};
  Map<String, List<String>> get favoriteDatabases => Map.unmodifiable(_favoriteDatabases);

  // 즐겨찾기 테이블 목록 (데이터베이스별)
  final _favoriteTablesController = StreamController<Map<String, List<String>>>.broadcast();
  Stream<Map<String, List<String>>> get favoriteTablesStream => _favoriteTablesController.stream;
  Map<String, List<String>> _favoriteTables = {};
  Map<String, List<String>> get favoriteTables => Map.unmodifiable(_favoriteTables);

  // 테이블별 저장된 필터 목록
  final _tableFiltersController = StreamController<Map<String, List<Map<String, dynamic>>>>.broadcast();
  Stream<Map<String, List<Map<String, dynamic>>>> get tableFiltersStream => _tableFiltersController.stream;
  Map<String, List<Map<String, dynamic>>> _tableFilters = {};
  Map<String, List<Map<String, dynamic>>> get tableFilters => Map.unmodifiable(_tableFilters);

  // 테이블별 컬럼 순서
  final _columnOrdersController = StreamController<Map<String, List<String>>>.broadcast();
  Stream<Map<String, List<String>>> get columnOrdersStream => _columnOrdersController.stream;
  Map<String, List<String>> _columnOrders = {};
  Map<String, List<String>> get columnOrders => Map.unmodifiable(_columnOrders);

  // ========== SharedPreferences 키 상수 ==========
  static const String _keyLocale = 'app_locale';
  static const String _keyFavoriteServers = 'favorite_servers';
  static const String _keyFavoriteDatabases = 'favorite_databases';
  static const String _keyFavoriteTables = 'favorite_tables';
  static const String _keyTableFilters = 'table_filters';
  static const String _keyColumnOrders = 'column_orders';

  // ========== 초기화 ==========

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    // --- 언어 설정 로드 ---
    final localeString = _prefs!.getString(_keyLocale);
    if (localeString != null) {
      final parts = localeString.split('_');
      _currentLocale = Locale(parts[0], parts.length > 1 ? parts[1] : null);
      _localeController.add(_currentLocale);
    }

    // --- 테마 설정 로드 (추가된 부분) ---
    // ThemeMode는 enum이므로 저장된 index를 불러옵니다.
    final themeIndex = _prefs!.getInt(_keyThemeMode); // _keyThemeMode는 상수여야 합니다.
    if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      _currentThemeMode = ThemeMode.values[themeIndex];
      _themeModeController.add(_currentThemeMode);
    }
    // _currentThemeMode와 _themeModeController는 이미 클래스 멤버 변수로 정의되어 있다고 가정합니다.

    // --- 즐겨찾기 서버 로드 ---
    final serversJson = _prefs!.getString(_keyFavoriteServers);
    if (serversJson != null) {
      _favoriteServers = List<String>.from(jsonDecode(serversJson));
      _favoriteServersController.add(_favoriteServers);
    }

    // --- 즐겨찾기 데이터베이스 로드 ---
    final databasesJson = _prefs!.getString(_keyFavoriteDatabases);
    if (databasesJson != null) {
      final decoded = jsonDecode(databasesJson) as Map<String, dynamic>;
      _favoriteDatabases = decoded.map((key, value) =>
          MapEntry(key, List<String>.from(value))
      );
      _favoriteDatabasesController.add(_favoriteDatabases);
    }

    // --- 즐겨찾기 테이블 로드 ---
    final tablesJson = _prefs!.getString(_keyFavoriteTables);
    if (tablesJson != null) {
      final decoded = jsonDecode(tablesJson) as Map<String, dynamic>;
      _favoriteTables = decoded.map((key, value) =>
          MapEntry(key, List<String>.from(value))
      );
      _favoriteTablesController.add(_favoriteTables);
    }

    // --- 테이블 필터 로드 ---
    final filtersJson = _prefs!.getString(_keyTableFilters);
    if (filtersJson != null) {
      final decoded = jsonDecode(filtersJson) as Map<String, dynamic>;
      _tableFilters = decoded.map((key, value) =>
          MapEntry(key, List<Map<String, dynamic>>.from(
              (value as List).map((item) => Map<String, dynamic>.from(item))
          ))
      );
      _tableFiltersController.add(_tableFilters);
    }

    // --- 컬럼 순서 로드 ---
    final ordersJson = _prefs!.getString(_keyColumnOrders);
    if (ordersJson != null) {
      final decoded = jsonDecode(ordersJson) as Map<String, dynamic>;
      _columnOrders = decoded.map((key, value) =>
          MapEntry(key, List<String>.from(value))
      );
      _columnOrdersController.add(_columnOrders);
    }
  }

  // ========== SharedPreferences 접두사 상수 ==========
  static const String _prefixCellStructures = 'cell_structures|';
  static const String _prefixColumnWidths = 'column_widths|';
  static const String _prefixColumnWidthsDisplay = 'column_widths_display|';

  // ========== 백업 및 복구 ==========

  /// SharedPreferences에서 특정 접두사로 시작하는 모든 항목을 Map으로 수집
  Map<String, dynamic> _collectPrefixedEntries(String prefix) {
    if (_prefs == null) return {};
    final result = <String, dynamic>{};
    for (final key in _prefs!.getKeys()) {
      if (key.startsWith(prefix)) {
        final raw = _prefs!.getString(key);
        if (raw != null) {
          try {
            result[key] = jsonDecode(raw);
          } catch (_) {
            result[key] = raw;
          }
        }
      }
    }
    return result;
  }

  Map<String, dynamic> _serializeSettings() {
    final settingsData = {
      'themeMode': _currentThemeMode.index,
      'locale': _currentLocale.toString(),
      'favoriteServers': _favoriteServers,
      'favoriteDatabases': _favoriteDatabases,
      'favoriteTables': _favoriteTables,
      'tableFilters': _tableFilters,
      'columnOrders': _columnOrders,
      // 셀 구조 (테이블별)
      'cellStructures': _collectPrefixedEntries(_prefixCellStructures),
      // 컬럼 폭 (테이블별 - 일반 + 구조모드)
      'columnWidths': _collectPrefixedEntries(_prefixColumnWidths),
      'columnWidthsDisplay': _collectPrefixedEntries(_prefixColumnWidthsDisplay),
    };

    return {
      'metadata': {
        'version': _SETTINGS_VERSION,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'data': settingsData,
    };
  }

  Future<String?> exportSettingsToFile(void Function(String, {Color? color}) showSnackBar) async {
    try {
      final settingsMap = _serializeSettings();
      final jsonString = const JsonEncoder.withIndent('  ').convert(settingsMap);

      final now = DateTime.now();
      final formatter = DateFormat('yyyyMMdd-HHmmss');
      final timestamp = formatter.format(now);
      final filename = 'setting_export_$timestamp.json';

      final directory = await getApplicationDocumentsDirectory();
      final exportPath = '${directory.path}/$filename';

      final file = File(exportPath);
      await file.writeAsString(jsonString);

      return exportPath;
    } catch (e) {
      debugPrint('설정 내보내기 실패: $e');
      return null;
    }
  }

  Future<void> importSettingsFromFile(
      void Function(String, {Color? color}) showSnackBar,
      {required String processingMsg,
      required String successMsg,
      required String failMsg}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      showSnackBar(processingMsg);

      final filePath = result.files.single.path!;
      final file = File(filePath);

      final jsonString = await file.readAsString();
      final settingsMap = jsonDecode(jsonString) as Map<String, dynamic>;

      await _applyImportedSettings(settingsMap);

      showSnackBar(successMsg, color: Colors.green);
    } catch (e) {
      debugPrint('설정 불러오기 실패: $e');
      showSnackBar(failMsg, color: Colors.red);
    }
  }

  /// 불러온 설정 맵을 실제 BLoC 상태에 적용하고 저장하는 도우미 메서드
  Future<void> _applyImportedSettings(Map<String, dynamic> settingsMap) async {
    // metadata 래핑 여부 처리 (data 키가 있으면 그 안의 데이터 사용)
    final data = settingsMap.containsKey('data')
        ? settingsMap['data'] as Map<String, dynamic>
        : settingsMap;

    // 1. 테마 모드
    final int? themeIndex = data['themeMode'] as int?;
    if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      await setThemeMode(ThemeMode.values[themeIndex]);
    }

    // 2. 언어 설정
    final String? localeString = data['locale'] as String?;
    if (localeString != null) {
      final parts = localeString.split('_');
      await setLocale(Locale(parts[0], parts.length > 1 ? parts[1] : null));
    }

    // 3. 즐겨찾기 서버
    if (data['favoriteServers'] != null) {
      _favoriteServers = List<String>.from(data['favoriteServers'] as List);
      _favoriteServersController.add(_favoriteServers);
      await _prefs?.setString(_keyFavoriteServers, jsonEncode(_favoriteServers));
    }

    // 4. 즐겨찾기 데이터베이스
    if (data['favoriteDatabases'] != null) {
      final decoded = data['favoriteDatabases'] as Map<String, dynamic>;
      _favoriteDatabases = decoded.map((key, value) =>
          MapEntry(key, List<String>.from(value as List)));
      _favoriteDatabasesController.add(_favoriteDatabases);
      await _prefs?.setString(_keyFavoriteDatabases, jsonEncode(_favoriteDatabases));
    }

    // 5. 즐겨찾기 테이블
    if (data['favoriteTables'] != null) {
      final decoded = data['favoriteTables'] as Map<String, dynamic>;
      _favoriteTables = decoded.map((key, value) =>
          MapEntry(key, List<String>.from(value as List)));
      _favoriteTablesController.add(_favoriteTables);
      await _prefs?.setString(_keyFavoriteTables, jsonEncode(_favoriteTables));
    }

    // 6. 테이블 필터
    if (data['tableFilters'] != null) {
      final decoded = data['tableFilters'] as Map<String, dynamic>;
      _tableFilters = decoded.map((key, value) =>
          MapEntry(key, List<Map<String, dynamic>>.from(
              (value as List).map((item) => Map<String, dynamic>.from(item as Map))
          )));
      _tableFiltersController.add(_tableFilters);
      await _prefs?.setString(_keyTableFilters, jsonEncode(_tableFilters));
    }

    // 7. 컬럼 순서
    if (data['columnOrders'] != null) {
      final decoded = data['columnOrders'] as Map<String, dynamic>;
      _columnOrders = decoded.map((key, value) =>
          MapEntry(key, List<String>.from(value as List)));
      _columnOrdersController.add(_columnOrders);
      await _prefs?.setString(_keyColumnOrders, jsonEncode(_columnOrders));
    }

    // 8. 셀 구조 (테이블별 SharedPreferences 키 단위로 복원)
    if (data['cellStructures'] != null) {
      final entries = data['cellStructures'] as Map<String, dynamic>;
      for (final entry in entries.entries) {
        await _prefs?.setString(entry.key, jsonEncode(entry.value));
      }
    }

    // 9. 컬럼 폭 - 일반모드 (테이블별 SharedPreferences 키 단위로 복원)
    if (data['columnWidths'] != null) {
      final entries = data['columnWidths'] as Map<String, dynamic>;
      for (final entry in entries.entries) {
        await _prefs?.setString(entry.key, jsonEncode(entry.value));
      }
    }

    // 10. 컬럼 폭 - 구조모드 (테이블별 SharedPreferences 키 단위로 복원)
    if (data['columnWidthsDisplay'] != null) {
      final entries = data['columnWidthsDisplay'] as Map<String, dynamic>;
      for (final entry in entries.entries) {
        await _prefs?.setString(entry.key, jsonEncode(entry.value));
      }
    }
  }

  // ========== 언어 설정 ==========

  Future<void> setLocale(Locale locale) async {
    _currentLocale = locale;
    _localeController.add(_currentLocale);

    final localeString = locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    await _prefs?.setString(_keyLocale, localeString);
  }

  // ========== 테마 설정 ==========
  /// 테마 모드 변경 메서드
  Future<void> setThemeMode(ThemeMode newThemeMode) async {
    // 1. 중복 호출 방지
    if (_currentThemeMode == newThemeMode) return;

    // 2. 메모리 상의 상태 즉시 업데이트 및 스트림 전송
    // (UI를 먼저 바꿔서 사용자에게 빠른 반응성을 제공합니다)
    _currentThemeMode = newThemeMode;
    _themeModeController.sink.add(_currentThemeMode);

    try {
      // 3. 비동기로 로컬 저장소에 테마 설정 저장
      final prefs = await SharedPreferences.getInstance();

      // ThemeMode는 열거형(enum)이므로 index나 이름을 저장합니다.
      await prefs.setInt('theme_mode_index', newThemeMode.index);

      debugPrint("테마 설정이 저장되었습니다: $newThemeMode");
    } catch (e) {
      // 저장 실패 시 에러 처리 (필요에 따라 롤백 로직 추가 가능)
      debugPrint("테마 저장 중 오류 발생: $e");
    }
  }

  // ========== 즐겨찾기 서버 관리 ==========

  Future<void> addFavoriteServer(String serverId) async {
    if (!_favoriteServers.contains(serverId)) {
      _favoriteServers.add(serverId);
      _favoriteServersController.add(_favoriteServers);
      await _prefs?.setString(_keyFavoriteServers, jsonEncode(_favoriteServers));
    }
  }

  Future<void> removeFavoriteServer(String serverId) async {
    if (_favoriteServers.remove(serverId)) {
      _favoriteServersController.add(_favoriteServers);
      await _prefs?.setString(_keyFavoriteServers, jsonEncode(_favoriteServers));
    }
  }

  bool isFavoriteServer(String serverId) {
    return _favoriteServers.contains(serverId);
  }

  // ========== 즐겨찾기 데이터베이스 관리 ==========

  Future<void> addFavoriteDatabase(String serverId, String databaseName) async {
    _favoriteDatabases.putIfAbsent(serverId, () => []);
    if (!_favoriteDatabases[serverId]!.contains(databaseName)) {
      _favoriteDatabases[serverId]!.add(databaseName);
      _favoriteDatabasesController.add(_favoriteDatabases);
      await _prefs?.setString(_keyFavoriteDatabases, jsonEncode(_favoriteDatabases));
    }
  }

  Future<void> removeFavoriteDatabase(String serverId, String databaseName) async {
    if (_favoriteDatabases[serverId]?.remove(databaseName) ?? false) {
      _favoriteDatabasesController.add(_favoriteDatabases);
      await _prefs?.setString(_keyFavoriteDatabases, jsonEncode(_favoriteDatabases));
    }
  }

  bool isFavoriteDatabase(String serverId, String databaseName) {
    return _favoriteDatabases[serverId]?.contains(databaseName) ?? false;
  }

  List<String> getFavoriteDatabases(String serverId) {
    return List.unmodifiable(_favoriteDatabases[serverId] ?? []);
  }

  // ========== 즐겨찾기 테이블 관리 ==========

  String _getTableKey(String serverId, String databaseName, String tableName) {
    return '$serverId:$databaseName:$tableName';
  }

  Future<void> addFavoriteTable(String serverId, String databaseName, String tableName) async {
    final key = _getTableKey(serverId, databaseName, tableName);
    _favoriteTables.putIfAbsent(key, () => []);
    if (!_favoriteTables[key]!.contains(tableName)) {
      _favoriteTables[key]!.add(tableName);
      _favoriteTablesController.add(_favoriteTables);
      await _prefs?.setString(_keyFavoriteTables, jsonEncode(_favoriteTables));
    }
  }

  Future<void> removeFavoriteTable(String serverId, String databaseName, String tableName) async {
    final key = _getTableKey(serverId, databaseName, tableName);
    if (_favoriteTables[key]?.remove(tableName) ?? false) {
      _favoriteTablesController.add(_favoriteTables);
      await _prefs?.setString(_keyFavoriteTables, jsonEncode(_favoriteTables));
    }
  }

  bool isFavoriteTable(String serverId, String databaseName, String tableName) {
    final key = _getTableKey(serverId, databaseName, tableName);
    return _favoriteTables[key]?.contains(tableName) ?? false;
  }

  List<String> getFavoriteTables(String serverId, String databaseName) {
    final key = _getTableKey(serverId, databaseName, '');
    return _favoriteTables.entries
        .where((e) => e.key.startsWith(key))
        .expand((e) => e.value)
        .toList();
  }

  // ========== 테이블 필터 관리 ==========

  Future<void> saveTableFilters(String serverId, String databaseName, String tableName,
      List<Map<String, dynamic>> filters) async {
    final key = _getTableKey(serverId, databaseName, tableName);
    _tableFilters[key] = filters;
    _tableFiltersController.add(_tableFilters);
    await _prefs?.setString(_keyTableFilters, jsonEncode(_tableFilters));
  }

  List<Map<String, dynamic>> getTableFilters(String serverId, String databaseName, String tableName) {
    final key = _getTableKey(serverId, databaseName, tableName);
    return List.unmodifiable(_tableFilters[key] ?? []);
  }

  Future<void> clearTableFilters(String serverId, String databaseName, String tableName) async {
    final key = _getTableKey(serverId, databaseName, tableName);
    _tableFilters.remove(key);
    _tableFiltersController.add(_tableFilters);
    await _prefs?.setString(_keyTableFilters, jsonEncode(_tableFilters));
  }

  // ========== 컬럼 순서 관리 ==========

  Future<void> saveColumnOrder(String serverId, String databaseName, String tableName,
      List<String> columnOrder) async {
    final key = _getTableKey(serverId, databaseName, tableName);
    _columnOrders[key] = columnOrder;
    _columnOrdersController.add(_columnOrders);
    await _prefs?.setString(_keyColumnOrders, jsonEncode(_columnOrders));
  }

  List<String> getColumnOrder(String serverId, String databaseName, String tableName) {
    final key = _getTableKey(serverId, databaseName, tableName);
    return List.unmodifiable(_columnOrders[key] ?? []);
  }

  Future<void> clearColumnOrder(String serverId, String databaseName, String tableName) async {
    final key = _getTableKey(serverId, databaseName, tableName);
    _columnOrders.remove(key);
    _columnOrdersController.add(_columnOrders);
    await _prefs?.setString(_keyColumnOrders, jsonEncode(_columnOrders));
  }

  // ========== 전체 설정 초기화 ==========

  Future<void> clearAllSettings() async {
    _currentLocale = const Locale('en');
    _favoriteServers.clear();
    _favoriteDatabases.clear();
    _favoriteTables.clear();
    _tableFilters.clear();
    _columnOrders.clear();

    _localeController.add(_currentLocale);
    _favoriteServersController.add(_favoriteServers);
    _favoriteDatabasesController.add(_favoriteDatabases);
    _favoriteTablesController.add(_favoriteTables);
    _tableFiltersController.add(_tableFilters);
    _columnOrdersController.add(_columnOrders);

    // SharedPreferences 전체 초기화 (셀 구조, 컬럼 폭 포함)
    await _prefs?.clear();
  }

  // ========== Dispose ==========

  void dispose() {
    _localeController.close();
    _themeModeController.close();
    _favoriteServersController.close();
    _favoriteDatabasesController.close();
    _favoriteTablesController.close();
    _tableFiltersController.close();
    _columnOrdersController.close();
  }
}