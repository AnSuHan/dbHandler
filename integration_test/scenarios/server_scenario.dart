import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_helpers.dart';

Future<void> runServerScenario(WidgetTester tester, TestConfig config) async {
  await runStep('3. 서버 추가', () async {
    final addBtn = find.byIcon(Icons.add).last;
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();
    
    await tester.tap(find.byType(Switch).first); 
    await tester.pumpAndSettle();
    
    // 추가 폼에서의 TextField들
    final nameField = find.byType(TextField).at(0);
    await enterTextHelper(tester, nameField, config.serverName);
    
    await actAndWait(tester, () => tester.tap(findFirstAvailable([find.text('서버 추가'), find.text('Add Server')]).last));
    
    await waitFor(tester, find.text(config.serverName));
  });

  await runStep('4. 서버 수정', () async {
    final tile = find.widgetWithText(ListTile, config.serverName).first;
    await tester.tap(find.descendant(of: tile, matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    
    final editMenu = find.textContaining('수정').or(find.textContaining('Edit')).last;
    await tester.tap(editMenu);
    await tester.pumpAndSettle();
    
    // 수정 다이얼로그 내부에서 현재 이름을 가지고 있는 TextField를 찾음
    // 이것이 가장 확실한 방법임
    final nameField = find.widgetWithText(TextField, config.serverName);
    if (nameField.evaluate().isEmpty) {
      // 못 찾으면 첫 번째 TextField 시도
      await enterTextHelper(tester, find.byType(TextField).first, config.updatedServerName);
    } else {
      await enterTextHelper(tester, nameField, config.updatedServerName);
    }
    
    await actAndWait(tester, () => tester.tap(findFirstAvailable([find.text('저장'), find.text('Save')]).last));
    
    // UI 반영 대기
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // 바뀐 이름이 존재하는지 확인
    await waitFor(tester, find.text(config.updatedServerName));
  });
}
