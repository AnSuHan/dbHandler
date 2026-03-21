import 'package:db_handler/sqflite/models/server_model.dart';
import 'package:db_handler/stateManagement/bloc/setting_bloc.dart';
import 'package:db_handler/stateManagement/mobx/mobx_store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;  // provider 패키지 alias
import 'package:db_handler/views/splash.dart';
import 'package:db_handler/views/server_selection.dart';
import 'package:db_handler/views/database_selection.dart';
import 'package:db_handler/views/table_selection.dart';
import 'package:db_handler/views/data_editing.dart';

import 'l10n/LocalizationManager.dart';
import 'gen/app_localizations.dart';
import 'theme/app_theme.dart';

void main() {
  // Windows 키보드 이벤트 중복 발생 Flutter 프레임워크 버그 필터링
  FlutterError.onError = (details) {
    if (details.toString().contains('_pressedKeys.containsKey')) return;
    FlutterError.presentError(details);
  };

  // SettingsBloc 싱글턴 초기화 (앱 시작 시 미리 생성)
  final settingsBloc = SettingsBloc();

  runApp(
    ProviderScope(  // Riverpod
      child: provider_pkg.MultiProvider(  // MobX용 Provider (alias 사용)
        providers: [
          provider_pkg.Provider<ServerStore>(
            create: (_) => ServerStore(),
            dispose: (_, store) {
              // MobX store cleanup (필요 시)
              // store.dispose();  <-- 일반적으로 MobX store는 dispose 필요 없음
            },
          ),
          // BLoC Pattern - SettingsBloc (싱글턴)
          provider_pkg.Provider<SettingsBloc>.value(
            value: settingsBloc,
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // SettingsBloc에서 언어 설정 가져오기
    final settingsBloc = provider_pkg.Provider.of<SettingsBloc>(context, listen: false);

    return StreamBuilder<Locale>(
        stream: settingsBloc.localeStream,
        initialData: settingsBloc.currentLocale,
        builder: (context, snapshot) {
          final locale = snapshot.data ?? const Locale('en');

          return StreamBuilder<ThemeMode>(
              stream: settingsBloc.themeModeStream,
              initialData: settingsBloc.currentThemeMode,
              builder: (context, themeModeSnapshot) {
                final themeMode = themeModeSnapshot.data ?? ThemeMode.system;

                return MaterialApp(
                  navigatorKey: navigatorKey,
                  // 앱 제목을 국제화
                  onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,

                  // ===== 국제화 설정 시작 =====
                  locale: locale,  // BLoC에서 관리하는 locale 사용

                  // 지원하는 로케일 목록
                  supportedLocales: AppLocalizations.supportedLocales,
                  // 국제화 delegates 설정
                  localizationsDelegates: AppLocalizations.localizationsDelegates,

                  // 로케일 결정 로직 (선택사항)
                  localeResolutionCallback: (deviceLocale, supportedLocales) {
                    // BLoC에 저장된 locale이 있으면 그것을 우선 사용
                    if (supportedLocales.contains(locale)) {
                      return locale;
                    }
                    // 기기 언어가 지원 언어에 있는지 확인
                    for (var supportedLocale in supportedLocales) {
                      if (supportedLocale.languageCode == deviceLocale?.languageCode) {
                        return supportedLocale;
                      }
                    }
                    // 지원하지 않는 언어면 첫 번째 언어(영어) 반환
                    return supportedLocales.first;
                  },

                  // ===== LocalizationManager context 설정 =====
                  builder: (context, child) {
                    // 여기서 context를 LocalizationManager에 설정
                    intl.setContext(context);
                    return Listener(
                      onPointerDown: (event) {
                        if (event.buttons & kBackMouseButton != 0) {
                          navigatorKey.currentState?.maybePop();
                        }
                      },
                      child: child!,
                    );
                  },

                  // ===== 국제화 설정 끝 =====
                  title: intl.getString((l) => l.appTitle),

                  // ===== 테마 설정 =====
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,  // BLoC에서 관리하는 themeMode 사용

                  initialRoute: '/',
                  routes: {
                    '/': (context) => const SplashScreen(),
                    '/server-selection': (context) => const ServerSelectionScreen(),
                    '/database-selection': (context) {
                      final server = ModalRoute.of(context)!.settings.arguments as ServerModel;
                      return DatabaseSelectionScreen(server: server);
                    },
                    '/table-selection': (context) {
                      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                      final server = args['server'] as ServerModel;
                      final database = args['database'] as String;
                      return TableSelectionScreen(server: server, database: database);
                    },
                    '/data-editing': (context) {
                      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                      final server = args['server'] as ServerModel;
                      final database = args['database'] as String;
                      final table = args['table'] as String;
                      return DataEditingScreen(server: server, database: database, table: table);
                    },
                  },
                );
              }
          );
        }
    );
  }
}