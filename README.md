# dbHandler
Flutter 3.35.6 • channel stable • https://github.com/flutter/flutter.git
Tools • Dart 3.9.2 • DevTools 2.48.0

## 기본 명령어
fvm flutter clean
fvm flutter pub get

---

## 웹 실행 방법

### 1. Chrome 직접 실행 (권장)
fvm flutter run -d chrome

### 2. web-server로 실행 (Chrome 직접 실행 실패 시)
`fvm flutter run -d web-server` 명령어를 실행하면 웹 서버가 시작됩니다.
콘솔에 출력된 `http://localhost:<PORT>` 주소를 복사하여 직접 Chrome 브라우저에서 여세요.

```bash
# 1. 웹 서버 실행
fvm flutter run -d web-server

# 2. 콘솔에 나온 주소(예: http://localhost:55343)를 브라우저에 붙여넣기
```

### 3. 빈 화면 문제 해결 (디버깅)
만약 브라우저에 빈 화면만 표시된다면, 브라우저의 개발자 도구 콘솔에서 오류를 확인해야 합니다.

1. `fvm flutter run -d web-server`를 실행합니다.
2. Chrome에서 `http://localhost:<PORT>` 주소로 접속합니다.
3. 페이지에서 마우스 오른쪽 버튼을 클릭하고 **검사(Inspect)**를 선택합니다.
4. **콘솔(Console)** 탭으로 이동하여 오류 메시지가 있는지 확인하고 알려주세요.

---

## 데스크톱 및 모바일 실행

### Windows
```bash
fvm flutter run -d windows
```

### macOS
```bash
fvm flutter run -d macos
```

### iOS
```bash
fvm flutter run -d ios
```

### Android
기본적으로 연결된 Android 기기에서 앱을 실행합니다.
```bash
fvm flutter run -d android
```

만약 여러 기기가 연결되어 있거나 특정 기기를 선택하고 싶다면, 기기 ID를 사용해야 합니다.
먼저 `fvm flutter devices` 명령어로 연결된 기기와 ID를 확인합니다.
```bash
# 예시: SM G981N 기기의 ID가 R3CN40CQQVA일 경우
fvm flutter run -d R3CN40CQQVA
```
---
postgreSQL 로컬
PostgreSQL Version: 18.0
http://localhost:5432

user: postgres
password: 0000
접속 명령: psql -U postgres -h 127.0.0.1