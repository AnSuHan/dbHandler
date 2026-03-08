import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/main.dart' as app;
import 'package:db_handler/views/server_selection.dart';
import 'test_helpers.dart';

Future<Brightness> runSetupScenario(WidgetTester tester) async {
  Brightness initialBrightness = Brightness.light;

  await runStep('1. 앱 실행 및 초기화', () async {
    app.main();
    await tester.pumpAndSettle();
    await waitFor(tester, find.byType(ServerSelectionScreen));
    initialBrightness = Theme.of(tester.element(find.byType(ServerSelectionScreen))).brightness;
  });

  await runStep('2. 환경 정리 (중복 서버 삭제)', () async {
    final existingTile = find.widgetWithText(ListTile, TestConfig.targetAddress);
    if (existingTile.evaluate().isNotEmpty) {
      final moreBtn = find.descendant(of: existingTile.first, matching: find.byIcon(Icons.more_vert)).first;
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();
      await tester.tap(findFirstAvailable([find.textContaining('삭제'), find.textContaining('Delete')]).last);
      await tester.pumpAndSettle();
      await tester.tap(findFirstAvailable([find.text('삭제'), find.text('Delete')]).last);
      await waitForNoLoading(tester);
    }
  });

  return initialBrightness;
}
