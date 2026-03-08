import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:db_handler/main.dart' as app;
import 'package:db_handler/views/server_selection.dart';
import 'package:db_handler/views/database_selection.dart';
import 'package:db_handler/views/table_selection.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA Test Plan Implementation - Full App Flow (Windows)', (WidgetTester tester) async {
    int currentStep = 0;
    const int totalSteps = 25;
    List<String> failures = [];

    // [도우미] 특정 위젯이 나타날 때까지 대기
    Future<void> waitForWidget(Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
      final endTime = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(endTime)) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 500));
      }
      if (finder.evaluate().isEmpty) {
        throw '타임아웃: ${finder.description} 위젯을 찾을 수 없습니다.';
      }
    }

    // [도우미] 로딩 위젯이 사라질 때까지 대기
    Future<void> waitForNoLoading({Duration timeout = const Duration(seconds: 15)}) async {
      final finder = find.byType(CircularProgressIndicator);
      final endTime = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(endTime)) {
        if (finder.evaluate().isEmpty) return;
        await tester.pump(const Duration(milliseconds: 500));
      }
      if (finder.evaluate().isNotEmpty) {
        debugPrint('경고: 로딩 위젯이 사라지지 않았으나 다음 단계로 진행합니다.');
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
        debugPrint('Stack: $stack');
        failures.add('[$description] 실패: $e');
        // 오류를 다시 던지지(rethrow) 않음으로써 다음 단계로 진행 보장
      }
      // 각 단계 후 화면 갱신
      await tester.pumpAndSettle();
    }

    // 1. 앱 초기 실행
    await runStep('1. 앱 실행 및 서버 선택 화면 대기', () async {
      app.main();
      await waitForWidget(find.byType(ServerSelectionScreen));
      await waitForNoLoading();
    });

    // 2. 서버 추가 테스트
    await runStep('2.1 서버 추가 폼 열기', () async {
      final addBtn = find.byIcon(Icons.add).last;
      await tester.tap(addBtn);
      await tester.pumpAndSettle();
      await waitForWidget(find.byType(Switch));
    });

    await runStep('2.2 테스트 서버 정보 입력', () async {
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Test Server'), findsOneWidget);
    });

    await runStep('2.3 서버 등록 완료', () async {
      final addButton = find.widgetWithText(ElevatedButton, '서버 추가')
          .or(find.text('서버 추가'))
          .or(find.widgetWithText(ElevatedButton, 'Add Server'))
          .or(find.text('Add Server')).last;
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      await waitForWidget(find.text('Test Server'));
    });

    // 3. 중복 서버 테스트
    await runStep('3.1 중복 서버 추가 시도', () async {
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();
      await waitForWidget(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      
      final addButton = find.widgetWithText(ElevatedButton, '서버 추가')
          .or(find.text('서버 추가'))
          .or(find.widgetWithText(ElevatedButton, 'Add Server'))
          .or(find.text('Add Server')).last;
      await tester.tap(addButton);
      
      await tester.pumpAndSettle();
      await waitForWidget(find.textContaining('이미 존재합니다').or(find.textContaining('already exists')));
      
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });

    // 4. 서버 수정 테스트
    await runStep('4.1 서버 정보 수정창 열기', () async {
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      
      // 팝업 메뉴가 나타날 때까지 대기
      final editOptionText = find.text('서버 정보 수정')
          .or(find.text('Edit Server Info'))
          .or(find.text('Edit Server Information'));
      await waitForWidget(editOptionText);
      
      await tester.tap(editOptionText.last);
      await tester.pumpAndSettle();
      await waitForWidget(find.byType(TextField));
    });

    await runStep('4.2 서버 이름 수정 및 저장', () async {
      await tester.enterText(find.byType(TextField).first, 'Updated Test Server');
      final saveButton = find.text('저장').or(find.text('Save')).last;
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      await waitForWidget(find.text('Updated Test Server'));
    });

    // 5. DB 화면 진입 테스트
    await runStep('5.1 데이터베이스 선택 화면 진입', () async {
      final serverItem = find.ancestor(
        of: find.text('Updated Test Server').last,
        matching: find.byType(InkWell),
      ).last;
      await tester.tap(serverItem, warnIfMissed: false);
      await tester.pumpAndSettle();
      
      // 화면 전환 및 로딩 완료 대기
      await waitForWidget(find.byType(DatabaseSelectionScreen));
      await waitForNoLoading();
      
      if (find.text('계정 정보 입력').or(find.text('Account Information')).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField).first, 'postgres');
        await tester.enterText(find.byType(TextField).last, '0000');
        final authSaveButton = find.text('저장').or(find.text('Save')).last;
        await tester.tap(authSaveButton);
        await tester.pumpAndSettle();
        await waitForNoLoading();
      }
      expect(find.byType(DatabaseSelectionScreen), findsOneWidget);
    });

    // 6. 설정 화면 테스트
    await runStep('6.1 설정 다이얼로그 열기', () async {
      final backButton = find.byType(BackButton).or(find.byIcon(Icons.arrow_back)).last;
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      
      await waitForWidget(find.byType(ServerSelectionScreen));
      
      await tester.tap(find.byIcon(Icons.settings).last);
      await tester.pumpAndSettle();
      await waitForWidget(find.textContaining('Settings').or(find.textContaining('설정')));
    });

    await runStep('6.2 테마 및 언어 변경 테스트', () async {
      final darkOption = find.text('다크 모드').or(find.text('Dark Mode')).last;
      await tester.tap(darkOption);
      await tester.pumpAndSettle();
      
      final langOption = find.text('언어').or(find.text('Language')).last;
      await tester.tap(langOption);
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.settings).or(find.textContaining('Settings')), findsWidgets);
      
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });

    // 7. 최종 결과 요약 및 테스트 종료
    logProgress('모든 QA 테스트 완료');
    
    // 파일 저장을 위한 정보 준비
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final status = failures.isNotEmpty ? 'failure' : 'success';
    final logDir = Directory('test_results');
    if (!logDir.existsSync()) {
      logDir.createSync();
    }
    final logFile = File('test_results/test_${timestamp}_$status.txt');

    String logContent = '--- [TEST SUMMARY] ---\n';
    logContent += '상태: ${status.toUpperCase()}\n';
    logContent += '종료 시간: ${DateTime.now().toIso8601String()}\n\n';

    if (failures.isNotEmpty) {
      debugPrint('--- [TEST SUMMARY] 총 ${failures.length}개의 단계에서 오류 발생 ---');
      logContent += '총 ${failures.length}개의 단계에서 오류 발생:\n';
      for (var f in failures) {
        debugPrint('  - $f');
        logContent += '  - $f\n';
      }
      logFile.writeAsStringSync(logContent);
      debugPrint('--- 테스트 결과가 파일로 저장되었습니다: ${logFile.path} ---');
      
      // 마지막에 명시적으로 실패 처리
      fail('일부 테스트 단계에서 실패가 발생했습니다. 로그를 확인하세요: ${logFile.path}');
    } else {
      debugPrint('--- [TEST SUMMARY] 모든 단계 성공! ---');
      logContent += '모든 단계가 성공적으로 완료되었습니다.\n';
      logFile.writeAsStringSync(logContent);
      debugPrint('--- 테스트 결과가 파일로 저장되었습니다: ${logFile.path} ---');
    }
  });
}

extension FinderOr on Finder {
  Finder or(Finder other) {
    if (this.evaluate().isNotEmpty) return this;
    return other;
  }
}
