# 자동화 테스트 가이드 (Automated Testing Guide)

이 문서는 `db_handler` 프로젝트에서 **Patrol** 및 **Integration Test**를 사용하여 모든 플랫폼(Android, iOS, Web, Desktop)에서 자동화 테스트를 실행하는 방법을 설명합니다.

## 1. 개요

이 프로젝트는 UI 테스트와 네이티브 기능(권한 팝업, 설정 변경 등)을 모두 지원하기 위해 **Patrol** 프레임워크를 사용합니다.

- **테스트 디렉토리**: `integration_test/`
- **테스트 드라이버**: `test_driver/patrol_integration_test.dart`
- **주요 기능**: 모든 플랫폼 지원, 네이티브 자동화, 직관적인 위젯 탐색기(Finders).

---

## 2. 사전 준비 (Prerequisites)

### 2.1 Patrol CLI 설치
모바일(Android/iOS) 테스트 시 네이티브 기능을 제어하기 위해 `patrol_cli`가 필요합니다. 터미널에서 다음 명령어를 실행하여 설치합니다.

```bash
dart pub global activate patrol_cli
```

### 2.2 플랫폼별 환경 설정
- **Android**: Android Emulator 또는 실제 기기가 연결되어 있어야 합니다.
- **iOS**: Xcode와 iOS Simulator가 설치되어 있어야 합니다.
- **Web**: Chrome 또는 Edge 브라우저가 필요합니다.
- **Desktop**: 해당 OS의 빌드 환경(Visual Studio, Xcode, CMake 등)이 필요합니다.

---

## 3. 테스트 실행 방법

### 3.1 모바일 (Android/iOS)
네이티브 기능 테스트가 포함된 경우 `patrol` 명령어를 사용합니다.

```bash
# 특정 테스트 파일 실행
patrol test --target integration_test/example_test.dart

# 전체 테스트 실행
patrol test
```

### 3.2 데스크톱 (Windows, macOS, Linux)
표준 Flutter 테스트 명령어를 사용하여 실행할 수 있습니다.

```bash
# Windows
flutter test integration_test/example_test.dart -d windows

# macOS
flutter test integration_test/example_test.dart -d macos

# Linux
flutter test integration_test/example_test.dart -d linux
```

### 3.3 웹 (Web)
브라우저 기반 테스트를 실행합니다.

```bash
flutter test integration_test/example_test.dart -d chrome
```

---

## 4. 새로운 테스트 작성하기

`integration_test/` 디렉토리에 새로운 `.dart` 파일을 생성하고 아래 템플릿을 사용하세요.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:db_handler/main.dart' as app;
import 'package:db_handler/views/splash.dart';

void main() {
  patrolTest(
    '시나리오 제목: 기능 설명',
    nativeAutomation: true, // 네이티브 기능을 사용할 경우 true
    ($) async {
      // 1. 앱 실행
      app.main();
      
      // 2. 화면 렌더링 대기
      await $.pumpAndSettle();

      // 3. 위젯 찾기 및 검증 (Finders)
      // 타입으로 찾기
      expect($(SplashScreen), findsOneWidget);
      
      // 텍스트로 찾기
      // expect($('로그인'), findsOneWidget);

      // 4. 동작 수행
      // await $(#loginButton).tap();
    },
  );
}
```

---

## 5. 주요 팁
- **$.pumpAndSettle()**: 애니메이션이나 비동기 작업이 완료될 때까지 대기합니다.
- **nativeAutomation**: 모바일에서 시스템 권한 팝업(위치 정보, 카메라 등)을 자동으로 승인하려면 이 옵션을 활성화하고 `$.native.grantPermissionWhenInUse()` 등을 사용합니다.
- **Hot Restart**: 테스트 도중 코드를 수정하고 싶을 때, 지원되는 IDE 환경에서 일반 디버깅처럼 활용 가능합니다.
