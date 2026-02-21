import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:db_handler/main.dart' as app;
import 'package:db_handler/views/splash.dart';

void main() {
  patrolTest(
    '앱 실행 및 초기 화면 로딩 테스트',
    nativeAutomation: true,
    ($) async {
      // 앱 실행
      app.main();
      
      // 앱 로딩 대기
      await $.pumpAndSettle();

      // 스플래시 화면 또는 초기 위젯이 존재하는지 확인
      expect($(SplashScreen), findsOneWidget);
    },
  );
}
