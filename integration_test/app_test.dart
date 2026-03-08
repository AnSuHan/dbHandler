import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'scenarios/test_helpers.dart';
import 'scenarios/setup_scenario.dart';
import 'scenarios/server_scenario.dart';
import 'scenarios/database_scenario.dart';
import 'scenarios/cleanup_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End Idempotent Scenario Test', (WidgetTester tester) async {
    final config = TestConfig(DateTime.now().millisecondsSinceEpoch);
    Brightness initialBrightness = Brightness.light;

    try {
      // 1. 초기화 및 환경 설정
      initialBrightness = await runSetupScenario(tester);

      // 2. 서버 관리 시나리오 (추가 및 수정)
      await runServerScenario(tester, config);

      // 3. 데이터베이스 및 데이터 조작 시나리오
      await runDatabaseScenario(tester, config);

    } catch (e) {
      debugPrint('Test Failed during execution: $e');
      rethrow;
    } finally {
      // 4. 멱등성 보장을 위한 사후 정리
      await runCleanupScenario(tester, config, initialBrightness);
    }
  });
}
