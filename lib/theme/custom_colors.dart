import 'package:flutter/material.dart';

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.neutral,
    required this.onSuccess,
    required this.onError,
    required this.onWarning,
    required this.onInfo,
    required this.onNeutral,
  });

  final Color? success;
  final Color? error;
  final Color? warning;
  final Color? info;
  final Color? neutral; // 회색 등 중립적인 색상
  final Color? onSuccess; // success 위에 올 글자색
  final Color? onError;
  final Color? onWarning;
  final Color? onInfo;
  final Color? onNeutral;

  @override
  CustomColors copyWith({
    Color? success,
    Color? error,
    Color? warning,
    Color? info,
    Color? neutral,
    Color? onSuccess,
    Color? onError,
    Color? onWarning,
    Color? onInfo,
    Color? onNeutral,
  }) {
    return CustomColors(
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
      onWarning: onWarning ?? this.onWarning,
      onInfo: onInfo ?? this.onInfo,
      onNeutral: onNeutral ?? this.onNeutral,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      success: Color.lerp(success, other.success, t),
      error: Color.lerp(error, other.error, t),
      warning: Color.lerp(warning, other.warning, t),
      info: Color.lerp(info, other.info, t),
      neutral: Color.lerp(neutral, other.neutral, t),
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t),
      onError: Color.lerp(onError, other.onError, t),
      onWarning: Color.lerp(onWarning, other.onWarning, t),
      onInfo: Color.lerp(onInfo, other.onInfo, t),
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t),
    );
  }
}
