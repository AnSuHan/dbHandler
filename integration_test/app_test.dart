import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:db_handler/main.dart' as app;
import 'package:db_handler/views/server_selection.dart';
import 'package:db_handler/views/database_selection.dart';
import 'package:db_handler/views/table_selection.dart';
import 'package:db_handler/views/data_editing.dart';
import 'package:db_handler/views/splash.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Idempotent E2E User Scenario Test', (WidgetTester tester) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final serverName = 'Human Test $timestamp';
    final updatedServerName = 'Final Server $timestamp';
    final tableName = 'human_users_$timestamp';
    const targetAddress = '127.0.0.1:5432';

    Brightness? initialBrightness;

    // --- Helper Functions ---
    
    Future<void> waitFor(Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        if (finder.evaluate().isNotEmpty) {
          await tester.pumpAndSettle();
          return;
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
      throw 'Timeout: ${finder.description}';
    }

    Future<void> waitForNoLoading({Duration timeout = const Duration(seconds: 20)}) async {
      await tester.pump(const Duration(milliseconds: 300));
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          await tester.pumpAndSettle();
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return; 
        }
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> actAndWait(Future<void> Function() action) async {
      await action();
      await tester.pumpAndSettle();
      await waitForNoLoading();
    }

    Future<void> enterTextHelper(Finder finder, String text) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await tester.enterText(finder, text);
      await tester.pumpAndSettle();
    }

    // --- Steps ---

    Future<void> runStep(String desc, Future<void> Function() action) async {
      debugPrint('--- [STEP] $desc ---');
      await action();
    }

    try {
      await runStep('1. 앱 실행 및 초기 테마 저장', () async {
        app.main();
        await tester.pump();
        await waitFor(find.byType(ServerSelectionScreen));
        initialBrightness = Theme.of(tester.element(find.byType(ServerSelectionScreen))).brightness;
      });

      await runStep('2. 환경 정리', () async {
        final existingTile = find.widgetWithText(ListTile, targetAddress);
        if (existingTile.evaluate().isNotEmpty) {
          final moreBtn = find.descendant(of: existingTile.first, matching: find.byIcon(Icons.more_vert)).first;
          await tester.tap(moreBtn);
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('삭제').or(find.textContaining('Delete')).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('삭제').or(find.text('Delete')).last);
          await waitForNoLoading();
        }
      });

      await runStep('3. 서버 추가', () async {
        await tester.tap(find.byIcon(Icons.add).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch).first); 
        await tester.pumpAndSettle();
        await enterTextHelper(find.byType(TextField).at(0), serverName);
        await actAndWait(() => tester.tap(find.text('서버 추가').or(find.text('Add Server')).last));
        await waitFor(find.widgetWithText(ListTile, serverName));
      });

      await runStep('4. 서버 수정', () async {
        final tile = find.widgetWithText(ListTile, serverName).first;
        await tester.tap(find.descendant(of: tile, matching: find.byIcon(Icons.more_vert)));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('수정').or(find.textContaining('Edit')).first);
        await tester.pumpAndSettle();
        await enterTextHelper(find.byType(TextField).at(0), updatedServerName);
        await actAndWait(() => tester.tap(find.text('저장').or(find.text('Save')).last));
        await waitFor(find.widgetWithText(ListTile, updatedServerName));
      });

      await runStep('5. DB 접속 및 테이블 생성', () async {
        await actAndWait(() => tester.tap(find.text(updatedServerName)));
        if (find.byType(TextField).evaluate().isNotEmpty) {
          await enterTextHelper(find.byType(TextField).at(0), 'postgres');
          await enterTextHelper(find.byType(TextField).at(1), '0000');
          await actAndWait(() => tester.tap(find.text('저장').or(find.text('Save')).last));
        }
        await waitFor(find.byType(DatabaseSelectionScreen));
        
        // 텍스트 매칭 실패를 대비하여 목록의 첫 번째 ListTile 선택 (보통 postgres)
        final dbTile = find.byType(ListTile).first;
        await waitFor(dbTile);
        await actAndWait(() => tester.tap(dbTile));
        
        await waitFor(find.byType(TableSelectionScreen));
        await tester.tap(find.byIcon(Icons.add).last);
        await tester.pumpAndSettle();
        await enterTextHelper(find.byType(TextField).first, tableName);
        await actAndWait(() => tester.tap(find.text('생성').or(find.text('Create')).last));
        await waitFor(find.text(tableName));
      });

      await runStep('6. 데이터 편집 및 설정 변경', () async {
        await actAndWait(() => tester.tap(find.text(tableName)));
        await waitFor(find.byType(DataEditingScreen));
        
        await tester.tap(find.byIcon(Icons.add).last);
        await tester.pumpAndSettle();
        if (find.byType(AlertDialog).evaluate().isNotEmpty) {
          await tester.tap(find.text('저장').or(find.text('Save')).last);
          await waitForNoLoading();
        }

        while (find.byType(ServerSelectionScreen).evaluate().isEmpty) {
          final back = find.byTooltip('Back').or(find.byIcon(Icons.arrow_back));
          if (back.evaluate().isEmpty) break;
          await tester.tap(back.first);
          await tester.pumpAndSettle();
        }

        await tester.tap(find.byIcon(Icons.settings).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.dark_mode).first); 
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close).first);
        await tester.pumpAndSettle();
      });

    } finally {
      // --- 완벽한 사후 정리 (멱등성) ---
      debugPrint('--- [IDEMPOTENCY CLEANUP] ---');

      // 1. 테마 원복
      try {
        final settingsBtn = find.byIcon(Icons.settings);
        if (settingsBtn.evaluate().isNotEmpty) {
          await tester.tap(settingsBtn.last);
          await tester.pumpAndSettle();
          final targetIcon = initialBrightness == Brightness.light ? Icons.light_mode : Icons.settings_suggest;
          final themeIcon = find.byIcon(targetIcon);
          if (themeIcon.evaluate().isNotEmpty) {
            await tester.tap(themeIcon.first);
            await tester.pumpAndSettle();
          }
          final closeBtn = find.byIcon(Icons.close);
          if (closeBtn.evaluate().isNotEmpty) {
            await tester.tap(closeBtn.first);
            await tester.pumpAndSettle();
          }
        }
      } catch (_) {}

      // 2. 생성된 테이블 삭제
      try {
        while (find.byType(ServerSelectionScreen).evaluate().isEmpty) {
          final back = find.byTooltip('Back').or(find.byIcon(Icons.arrow_back));
          if (back.evaluate().isEmpty) break;
          await tester.tap(back.first);
          await tester.pumpAndSettle();
        }

        final server = find.widgetWithText(ListTile, updatedServerName);
        if (server.evaluate().isNotEmpty) {
          await actAndWait(() => tester.tap(server.first));
          await waitFor(find.byType(DatabaseSelectionScreen));
          await actAndWait(() => tester.tap(find.text('postgres').first));
          await waitFor(find.byType(TableSelectionScreen));
          
          final tableItem = find.widgetWithText(ListTile, tableName);
          if (tableItem.evaluate().isNotEmpty) {
            final moreBtn = find.descendant(of: tableItem.first, matching: find.byIcon(Icons.more_vert));
            if (moreBtn.evaluate().isNotEmpty) {
              await tester.tap(moreBtn.first);
              await tester.pumpAndSettle();
              await tester.tap(find.textContaining('삭제').or(find.textContaining('Delete')).first);
              await tester.pumpAndSettle();
              await tester.tap(find.text('삭제').or(find.text('Delete')).last);
              await waitForNoLoading();
            }
          }
        }
      } catch (_) {}

      // 3. 생성된 서버 삭제
      try {
        while (find.byType(ServerSelectionScreen).evaluate().isEmpty) {
          final back = find.byTooltip('Back').or(find.byIcon(Icons.arrow_back));
          if (back.evaluate().isEmpty) break;
          await tester.tap(back.first);
          await tester.pumpAndSettle();
        }
        
        final server = find.widgetWithText(ListTile, updatedServerName);
        if (server.evaluate().isNotEmpty) {
          final moreBtn = find.descendant(of: server.first, matching: find.byIcon(Icons.more_vert)).first;
          await tester.tap(moreBtn);
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('삭제').or(find.textContaining('Delete')).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('삭제').or(find.text('Delete')).last);
          await waitForNoLoading();
        }
      } catch (_) {}
      
      debugPrint('--- [IDEMPOTENCY COMPLETED] ---');
    }
  });
}

extension FinderOr on Finder {
  Finder or(Finder other) => this.evaluate().isNotEmpty ? this : other;
}
