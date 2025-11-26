import 'package:db_handler/sqflite/models/server_model.dart';
import 'package:db_handler/stateManagement/mobx/mobx_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;  // provider 패키지 alias
import 'package:db_handler/views/splash.dart';
import 'package:db_handler/views/server_selection.dart';
import 'package:db_handler/views/database_selection.dart';
import 'package:db_handler/views/table_selection.dart';
import 'package:db_handler/views/data_editing.dart';

import 'l10n/LocalizationManager.dart';
import 'l10n/app_localizations.dart';

void main() {
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
          // 다른 DB 타입 사용 예시:
          // provider_pkg.Provider<ServerSelectionStore>(
          //   create: (_) => ServerSelectionStore(dbType: 'MySQL'),
          // ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 앱 제목을 국제화
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,

      // ===== 국제화 설정 시작 =====

      // 지원하는 로케일 목록
      supportedLocales: AppLocalizations.supportedLocales,
      // 국제화 delegates 설정
      localizationsDelegates: AppLocalizations.localizationsDelegates,

      // 로케일 결정 로직 (선택사항)
      localeResolutionCallback: (locale, supportedLocales) {
        // 기기 언어가 지원 언어에 있는지 확인
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
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
        return child!;
      },

      // ===== 국제화 설정 끝 =====
      title: intl.getString((l) => l.appTitle),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
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
}