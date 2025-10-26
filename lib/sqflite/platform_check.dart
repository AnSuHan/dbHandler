import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformCheck {
  static bool get isWeb => kIsWeb;
  static bool get supportsSqflite => !isWeb;
}
