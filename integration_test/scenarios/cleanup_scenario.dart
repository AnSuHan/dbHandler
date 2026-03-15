import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/views/server_selection.dart';
import 'package:db_handler/views/database_selection.dart';
import 'package:db_handler/views/table_selection.dart';
import 'test_helpers.dart';

Future<void> runCleanupScenario(WidgetTester tester, TestConfig config, Brightness initialBrightness) async {
  debugPrint('--- [IDEMPOTENCY CLEANUP START] ---');

  // 1. 테마 원복
  try {
    final settingsBtn = find.byIcon(Icons.settings);
    if (settingsBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(settingsBtn.last);
      await tester.tap(settingsBtn.last, warnIfMissed: false);
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
  } catch (e) { debugPrint('Cleanup Error (Theme): $e'); }

  // 2. 생성된 테이블 삭제
  try {
    while (find.byType(ServerSelectionScreen).evaluate().isEmpty) {
      final backBtn = findFirstAvailable([find.byTooltip('Back'), find.byIcon(Icons.arrow_back)]);
      if (backBtn.evaluate().isEmpty) break;
      await tester.tap(backBtn.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    final server = find.widgetWithText(ListTile, config.updatedServerName)
        .or(find.widgetWithText(ListTile, config.serverName));
    if (server.evaluate().isNotEmpty) {
      await actAndWait(tester, () => tester.tap(server.first));
      await waitFor(tester, find.byType(DatabaseSelectionScreen));
      
      final dbTile = find.widgetWithText(ListTile, 'postgres').or(find.byType(ListTile).first);
      await actAndWait(tester, () => tester.tap(dbTile));
      await waitFor(tester, find.byType(TableSelectionScreen));
      
      final tableItem = find.widgetWithText(ListTile, config.tableName);
      if (tableItem.evaluate().isNotEmpty) {
        final moreBtn = find.descendant(of: tableItem.first, matching: find.byIcon(Icons.more_vert));
        if (moreBtn.evaluate().isNotEmpty) {
          await tester.tap(moreBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(findFirstAvailable([find.textContaining('삭제'), find.textContaining('Delete')]).last);
          await tester.pumpAndSettle();
          await tester.tap(findFirstAvailable([find.text('삭제'), find.text('Delete')]).last);
          await waitForNoLoading(tester);
        }
      }
    }
  } catch (e) { debugPrint('Cleanup Error (Table): $e'); }

  // 3. 생성된 서버 삭제
  try {
    while (find.byType(ServerSelectionScreen).evaluate().isEmpty) {
      final backBtn = findFirstAvailable([find.byTooltip('Back'), find.byIcon(Icons.arrow_back)]);
      if (backBtn.evaluate().isEmpty) break;
      await tester.tap(backBtn.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    
    final server = find.widgetWithText(ListTile, config.updatedServerName)
        .or(find.widgetWithText(ListTile, config.serverName));
    if (server.evaluate().isNotEmpty) {
      final moreBtn = find.descendant(of: server.first, matching: find.byIcon(Icons.more_vert)).first;
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();
      await tester.tap(findFirstAvailable([find.textContaining('삭제'), find.textContaining('Delete')]).last);
      await tester.pumpAndSettle();
      await tester.tap(findFirstAvailable([find.text('삭제'), find.text('Delete')]).last);
      await waitForNoLoading(tester);
    }
  } catch (e) { debugPrint('Cleanup Error (Server): $e'); }
  
  debugPrint('--- [IDEMPOTENCY CLEANUP COMPLETED] ---');
}
