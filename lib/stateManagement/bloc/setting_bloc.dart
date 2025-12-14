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
  final String _SETTINGS_VERSION = '0.0.1';

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

  // ========== 백업 및 복구 ==========
  Map<String, dynamic> _serializeSettings() {
    // BLoC에 저장된 모든 상태 변수(_current...)
    final settingsData = {
      'themeMode': _currentThemeMode.index,
      'locale': _currentLocale.toString(),
      'favoriteServers': _favoriteServers,
      'favoriteDatabases': _favoriteDatabases,
      'favoriteTables': _favoriteTables,
      'tableFilters': _tableFilters,
      'columnOrders': _columnOrders,
      // ... 모든 설정 변수를 여기에 추가 ...
    };

    // 메타데이터를 포함한 최종 구조 반환
    return {
      'metadata': {
        'version': _SETTINGS_VERSION,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'data': settingsData,
    };
  }

  Future<String> exportSettingsToFile() async {
    final settingsMap = _serializeSettings();
    final jsonString = jsonEncode(settingsMap);

    // 파일명 포맷: setting_export_yyyymmdd-hhmmss.json
    final now = DateTime.now();
    // DateFormat은 'package:intl/intl.dart' 필요
    final formatter = DateFormat('yyyyMMdd-HHmmss');
    final timestamp = formatter.format(now);
    final filename = 'setting_export_$timestamp.json';

    // 저장 경로 결정
    final directory = await getApplicationDocumentsDirectory();
    final exportPath = '${directory.path}/$filename';

    // 파일에 저장
    final file = File(exportPath);
    await file.writeAsString(jsonString);

    return exportPath; // 파일 경로 반환
  }

  Future<void> importSettingsFromFile() async {
    try {
      // 1. 파일 선택 UI 띄우기 (file_picker 사용)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return; // 사용자가 취소함
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);

      // 2. 파일 내용 읽기
      final jsonString = await file.readAsString();
      final settingsMap = jsonDecode(jsonString) as Map<String, dynamic>;

      // 3. 설정 값 디코딩 및 적용
      await _applyImportedSettings(settingsMap);

    } catch (e) {
      debugPrint('설정 불러오기 실패: $e');
      // 오류 처리
    }
  }

  /// 불러온 설정 맵을 실제 BLoC 상태에 적용하고 저장하는 도우미 메서드
  Future<void> _applyImportedSettings(Map<String, dynamic> settingsMap) async {
    // 1. 테마 모드 적용 및 저장
    final int? themeIndex = settingsMap['themeMode'];
    if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      final newThemeMode = ThemeMode.values[themeIndex];
      // BLoC의 setThemeMode를 사용하여 상태 변경 및 디스크 저장 로직을 재사용합니다.
      await setThemeMode(newThemeMode);
    }

    // 2. 언어 설정 적용 및 저장
    final String? localeString = settingsMap['locale'];
    if (localeString != null) {
      final parts = localeString.split('_');
      final newLocale = Locale(parts[0], parts.length > 1 ? parts[1] : null);
      // locale 설정 메서드를 재사용하여 상태 변경 및 디스크 저장을 수행합니다.
      // await setLocale(newLocale);
    }

    // 3. 즐겨찾기, 필터 등 나머지 모든 설정들을 여기에 추가하여 적용하고 저장합니다.

    // ... (나머지 설정 로직) ...

    // 모든 설정이 디스크에 반영된 후 BLoC의 모든 Stream에 최종 상태를 다시 한 번 전송하여
    // UI가 완전히 갱신되도록 할 수 있습니다. (선택 사항)
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