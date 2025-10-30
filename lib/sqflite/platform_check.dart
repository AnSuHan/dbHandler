import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformCheck {
  static bool get isWeb => kIsWeb;
  static bool get supportsSqflite => !isWeb;
  static bool get isMouseAvailable {
    if (kIsWeb) {
      return true;
    }

    // 모바일 기기가 아니면 마우스 지원
    return !_isMobileOS;
  }

  static bool get _isMobileOS {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get isDesktop {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
}
