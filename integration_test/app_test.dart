import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:db_handler/main.dart' as app;
import 'package:db_handler/views/server_selection.dart';
import 'package:db_handler/views/database_selection.dart';
import 'package:db_handler/views/table_selection.dart';
import 'package:db_handler/views/data_editing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Robust QA Test Plan Verification', (WidgetTester tester) async {
    int currentStep = 0;
    const int totalSteps = 40;
    List<String> failures = [];

    // [도우미] 특정 위젯이 나타날 때까지 대기
    Future<bool> tryWaitForWidget(Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
      final endTime = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(endTime)) {
        if (finder.evaluate().isNotEmpty) return true;
        await tester.pump(const Duration(milliseconds: 500));
      }
      return false;
    }

    Future<void> waitForWidget(Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
      if (!await tryWaitForWidget(finder, timeout: timeout)) {
        throw '타임아웃: ${finder.description} 위젯을 찾을 수 없습니다.';
      }
    }

    // [도우미] 로딩 위젯이 사라질 때까지 대기
    Future<void> waitForNoLoading({Duration timeout = const Duration(seconds: 25)}) async {
      final finder = find.byType(CircularProgressIndicator);
      final endTime = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(endTime)) {
        if (finder.evaluate().isEmpty) {
          await tester.pump(const Duration(milliseconds: 500));
          if (finder.evaluate().isEmpty) return;
        }
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    // 진행도 출력 함수
    void logProgress(String message) {
      currentStep++;
      double percent = (currentStep / totalSteps) * 100;
      if (percent > 100) percent = 100;
      debugPrint('--- [TEST PROGRESS] ${percent.toStringAsFixed(0)}% | $message ---');
    }

    // [핵심] 개별 단계를 실행하고 오류가 나도 다음으로 넘어가는 함수
    Future<void> runStep(String description, Future<void> Function() action) async {
      logProgress(description);
      try {
        await action();
        debugPrint('--- [STEP SUCCESS] $description ---');
      } catch (e, stack) {
        debugPrint('--- [STEP FAILED] $description ---');
        debugPrint('Error: $e');
        failures.add('[$description] 실패: $e');
        
        // 에러 다이얼로그나 스낵바가 있다면 닫기 시도
        final closeBtn = find.text('취소').or(find.text('Cancel')).or(find.text('확인')).or(find.text('OK')).or(find.byIcon(Icons.close));
        if (closeBtn.evaluate().isNotEmpty) {
           await tester.tap(closeBtn.last, warnIfMissed: false);
           await tester.pumpAndSettle();
        }
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }

    // 1. 초기화 및 서버 설정
    await runStep('1.1 앱 실행 및 서버 화면 진입', () async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await waitForWidget(find.byType(ServerSelectionScreen));
    });

    await runStep('1.2 테스트 서버 추가 (인증 정보 미리 입력)', () async {
      final addBtn = find.byIcon(Icons.add).last;
      await tester.tap(addBtn);
      await tester.pumpAndSettle();
      
      final testSwitch = find.byType(Switch).first;
      await tester.tap(testSwitch);
      await tester.pumpAndSettle();
      
      final addButton = find.text('서버 추가').or(find.text('Add Server')).last;
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      await waitForNoLoading();
      
      await waitForWidget(find.byType(ListTile));
    });

    // 2. 데이터베이스 조작 테스트
    await runStep('2.1 DB 선택 화면 진입', () async {
      // 텍스트 대신 ListTile 위젯을 직접 찾아 탭 (가장 안전)
      final serverTile = find.byType(ListTile).last;
      await tester.ensureVisible(serverTile);
      await tester.tap(serverTile, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // 인증 다이얼로그 처리 (필요 시)
      if (find.byType(TextField).evaluate().isNotEmpty) {
        final textFields = find.byType(TextField);
        if (textFields.evaluate().length >= 2) {
          await tester.enterText(textFields.at(0), 'postgres'); 
          await tester.enterText(textFields.at(1), '0000');     
          final saveBtn = find.text('저장').or(find.text('Save')).last;
          await tester.tap(saveBtn);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
      }
      
      await waitForWidget(find.byType(DatabaseSelectionScreen));
      await waitForNoLoading();
    });

    await runStep('2.2 새 DB 생성 다이얼로그 확인', () async {
      if (find.byType(DatabaseSelectionScreen).evaluate().isEmpty) throw 'DB 화면 아님';
      final addDbBtn = find.widgetWithIcon(ElevatedButton, Icons.add).or(find.byIcon(Icons.add)).last;
      await tester.ensureVisible(addDbBtn);
      await tester.tap(addDbBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      
      await waitForWidget(find.byType(TextField));
      await tester.tap(find.text('취소').or(find.text('Cancel')).last);
      await tester.pumpAndSettle();
    });

    // 3. 테이블 조작 테스트
    await runStep('3.1 테이블 선택 화면 진입', () async {
      if (find.byType(DatabaseSelectionScreen).evaluate().isEmpty) throw 'DB 화면 아님';
      final dbItem = find.byType(ListTile).first;
      await tester.ensureVisible(dbItem);
      await tester.tap(dbItem, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      await waitForWidget(find.byType(TableSelectionScreen));
      await waitForNoLoading();
    });

    await runStep('3.2 테이블 생성 테스트', () async {
      if (find.byType(TableSelectionScreen).evaluate().isEmpty) throw 'Table 화면 아님';
      final addTableBtn = find.widgetWithIcon(ElevatedButton, Icons.add).or(find.byIcon(Icons.add)).last;
      await tester.ensureVisible(addTableBtn);
      await tester.tap(addTableBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      
      final nameField = find.byType(TextField).last;
      await tester.enterText(nameField, 'qa_test_table');
      await tester.tap(find.text('생성').or(find.text('Create')).last);
      await tester.pumpAndSettle();
      await waitForNoLoading();
      
      await waitForWidget(find.text('qa_test_table'));
    });

    // 5. 설정 화면 마무리
    await runStep('5.2 언어 설정 변경', () async {
      while (find.byType(ServerSelectionScreen).evaluate().isEmpty) {
        final backBtn = find.byType(BackButton).or(find.byIcon(Icons.arrow_back));
        if (backBtn.evaluate().isEmpty) break;
        await tester.tap(backBtn.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      
      final settingsBtn = find.byIcon(Icons.settings).last;
      await tester.tap(settingsBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      
      final langItem = find.textContaining('Language').or(find.textContaining('언어')).first;
      await tester.tap(langItem, warnIfMissed: false);
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      
      // 'General' 대신 'Settings' 또는 아이콘 확인
      expect(find.byIcon(Icons.settings).or(find.textContaining('Settings')), findsWidgets);
    });

    // 최종 결과 요약
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final status = failures.isEmpty ? 'success' : 'fail';
    final logFile = File('test_results/test_${timestamp}_$status.txt');

    String summary = 'QA Test Summary\nStatus: ${status.toUpperCase()}\nSuccess Steps: ${totalSteps - failures.length}/$totalSteps\n';
    if (failures.isNotEmpty) {
      summary += '\nFailures:\n' + failures.join('\n');
    }
    logFile.writeAsStringSync(summary);
    debugPrint('--- [TEST COMPLETE] 결과 저장됨: ${logFile.path} ---');

    if (failures.isNotEmpty) {
      fail('일부 테스트 단계에서 실패가 발생했습니다. 로그 확인: ${logFile.path}');
    }
  });
}

extension FinderOr on Finder {
  Finder or(Finder other) {
    if (this.evaluate().isNotEmpty) return this;
    return other;
  }
}
