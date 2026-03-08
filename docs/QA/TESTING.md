# Automated Testing Guide (자동화 테스트 가이드)

이 프로젝트는 **Patrol** 프레임워크를 사용하여 모든 플랫폼(Android, iOS, Web, Windows, macOS, Linux)에 대한 UI 자동화 테스트를 지원합니다.

## 1. 테스트 구조
- **테스트 코드**: `integration_test/` 폴더 내의 `.dart` 파일
- **테스트 드라이버**: `test_driver/patrol_integration_test.dart`
- **설정**: `pubspec.yaml`의 `patrol` 및 `integration_test` 의존성

## 2. 사전 준비
모바일 플랫폼의 네이티브 기능을 테스트하기 위해 `patrol_cli` 설치가 필요합니다.

```bash
dart pub global activate patrol_cli
```

## 3. 플랫폼별 테스트 실행 방법

### 📱 모바일 (Android, iOS)
네이티브 권한이나 설정 제어가 포함된 경우 `patrol` 명령어를 사용합니다.

```bash
# 특정 테스트 실행
patrol test --target integration_test/app_test.dart

# 전체 테스트 실행
patrol test
```

### 💻 데스크톱 (Windows, macOS, Linux)
각 OS 환경에 맞는 디바이스 이름을 지정하여 실행합니다.

```bash
# Windows
flutter test integration_test/app_test.dart -d windows

# macOS
flutter test integration_test/app_test.dart -d macos

# Linux
flutter test integration_test/app_test.dart -d linux
```

### 🌐 웹 (Web)
Chrome 브라우저를 통해 테스트를 진행합니다.

```bash
flutter test integration_test/app_test.dart -d chrome
```

## 4. 새로운 테스트 작성 템플릿
새로운 테스트 시나리오를 작성할 때 아래 구조를 참조하세요.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:db_handler/main.dart' as app;

void main() {
  patrolTest(
    '테스트 시나리오 이름',
    nativeAutomation: true,
    ($) async {
      // 앱 초기화
      app.main();
      await $.pumpAndSettle();

      // 위젯 검증 및 동작
      // expect($(WidgetType), findsOneWidget);
      // await $(#widgetId).tap();
    },
  );
}
```

## 5. 참고 사항
- 애니메이션이 포함된 경우 `$.pumpAndSettle()`을 사용하여 화면이 안정화될 때까지 기다려야 합니다.
- 테스트 실행 전 해당 플랫폼의 에뮬레이터나 기기가 연결되어 있는지 확인하세요.
