import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestConfig {
  final int timestamp;
  final String serverName;
  final String updatedServerName;
  final String tableName;
  static const String targetAddress = '127.0.0.1:5432';
  static const String testUsername = 'postgres';
  static const String testPassword = '0000';

  TestConfig(this.timestamp)
      : serverName = 'Human Test $timestamp',
        updatedServerName = 'Final Server $timestamp',
        tableName = 'human_users_$timestamp';
}

Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  throw 'Timeout waiting for: ${finder.description}';
}

Future<void> waitForNoLoading(WidgetTester tester, {Duration timeout = const Duration(seconds: 25)}) async {
  await tester.pump(const Duration(milliseconds: 500));
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> actAndWait(WidgetTester tester, Future<void> Function() action) async {
  await action();
  await tester.pumpAndSettle();
  await waitForNoLoading(tester);
}

Future<void> enterTextHelper(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  
  // 텍스트 필드 포커스 유도 및 기존 텍스트 삭제
  await tester.enterText(finder, ''); 
  await tester.pump();
  
  // 실제 텍스트 입력
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Finder findFirstAvailable(List<Finder> finders) {
  for (final f in finders) if (f.evaluate().isNotEmpty) return f;
  return finders.first;
}

Future<void> runStep(String desc, Future<void> Function() action) async {
  debugPrint('--- [STEP START] $desc ---');
  try {
    await action();
    debugPrint('--- [STEP SUCCESS] $desc ---');
  } catch (e) {
    debugPrint('--- [STEP FAILED] $desc: $e ---');
    rethrow;
  }
}

extension FinderOr on Finder {
  Finder or(Finder other) => this.evaluate().isNotEmpty ? this : other;
}
