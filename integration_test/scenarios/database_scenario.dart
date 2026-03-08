import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/views/database_selection.dart';
import 'package:db_handler/views/table_selection.dart';
import 'package:db_handler/views/data_editing.dart';
import 'package:db_handler/views/server_selection.dart';
import 'test_helpers.dart';

Future<void> runDatabaseScenario(WidgetTester tester, TestConfig config) async {
  await runStep('5. DB 접속 및 테이블 생성', () async {
    final targetServer = find.text(config.updatedServerName).first;
    await tester.ensureVisible(targetServer);
    await actAndWait(tester, () => tester.tap(targetServer));
    
    if (find.byType(TextField).evaluate().isNotEmpty) {
      final fields = find.byType(TextField);
      if (fields.evaluate().length >= 2) {
        await enterTextHelper(tester, fields.at(0), TestConfig.testUsername);
        await enterTextHelper(tester, fields.at(1), TestConfig.testPassword);
        await actAndWait(tester, () => tester.tap(findFirstAvailable([find.text('저장'), find.text('Save')]).last));
      }
    }
    
    await waitFor(tester, find.byType(DatabaseSelectionScreen));
    await waitForNoLoading(tester);

    final dbTile = find.widgetWithText(ListTile, 'postgres').or(find.byType(ListTile).first);
    await actAndWait(tester, () => tester.tap(dbTile));
    
    await waitFor(tester, find.byType(TableSelectionScreen));
    await waitForNoLoading(tester);

    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    await enterTextHelper(tester, find.byType(TextField).first, config.tableName);
    await actAndWait(tester, () => tester.tap(findFirstAvailable([find.text('생성'), find.text('Create')]).last));
    await waitFor(tester, find.widgetWithText(ListTile, config.tableName));
  });

  await runStep('6. 데이터 편집 및 설정 변경', () async {
    await actAndWait(tester, () => tester.tap(find.text(config.tableName)));
    await waitFor(tester, find.byType(DataEditingScreen));
    
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(findFirstAvailable([find.text('저장'), find.text('Save')]).last);
      await waitForNoLoading(tester);
    }

    while (find.byType(ServerSelectionScreen).evaluate().isEmpty) {
      final backBtn = findFirstAvailable([find.byTooltip('Back'), find.byIcon(Icons.arrow_back)]);
      if (backBtn.evaluate().isEmpty) break;
      await tester.tap(backBtn.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    final settingsBtn = find.byIcon(Icons.settings).last;
    await tester.ensureVisible(settingsBtn);
    await tester.tap(settingsBtn, warnIfMissed: false);
    await tester.pumpAndSettle();
    
    await tester.tap(find.byIcon(Icons.dark_mode).first); 
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
  });
}
