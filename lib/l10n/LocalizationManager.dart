import 'package:flutter/material.dart';

import 'app_localizations.dart';

/// Localization을 관리하는 싱글턴 클래스
/// context 없이 어디서든 localization 문자열에 접근 가능
class LocalizationManager {
  // 싱글턴 인스턴스
  static final LocalizationManager _instance = LocalizationManager._internal();

  // private 생성자
  LocalizationManager._internal();

  // 싱글턴 인스턴스 getter
  factory LocalizationManager() => _instance;

  // BuildContext를 저장할 변수
  BuildContext? _context;

  /// context를 설정하는 메서드
  /// MaterialApp의 builder나 최상위 위젯에서 호출
  void setContext(BuildContext context) {
    _context = context;
  }

  /// context를 초기화하는 메서드
  void clearContext() {
    _context = null;
  }

  /// AppLocalizations 인스턴스를 반환
  /// context가 없거나 localizations를 찾을 수 없으면 null 반환
  AppLocalizations? get _localizations {
    if (_context == null) return null;
    return AppLocalizations.of(_context!);
  }

  /// 문자열을 안전하게 가져오는 메서드
  /// localizations가 없으면 빈 문자열 반환
  String getString(String Function(AppLocalizations) getter) {
    final localizations = _localizations;
    if (localizations == null) return '@undefined@';
    return getter(localizations);
  }

  // === 편의 메서드들 (자주 사용하는 문자열용) ===
  // String get appTitle => getString((l) => l.appTitle);

  /// 매개변수가 있는 문자열을 가져오는 메서드
  String getStringWithParams(
      String Function(AppLocalizations, dynamic) getter,
      dynamic param,
      ) {
    final localizations = _localizations;
    if (localizations == null) return '@undefined@';
    return getter(localizations, param);
  }

  /// 여러 매개변수가 있는 문자열을 가져오는 메서드
  String getStringWithMultiParams(
      String Function(AppLocalizations, List<dynamic>) getter,
      List<dynamic> params,
      ) {
    final localizations = _localizations;
    if (localizations == null) return '@undefined@';
    return getter(localizations, params);
  }
}

/// 전역에서 쉽게 접근할 수 있도록 하는 getter
final intl = LocalizationManager();