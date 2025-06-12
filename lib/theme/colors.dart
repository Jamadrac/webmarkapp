import 'package:flutter/material.dart';

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.blue,
    required this.green,
    required this.yellow,
    required this.orange,
    required this.purple,
    required this.coolGray,
  });

  final Color? blue;
  final Color? green;
  final Color? yellow;
  final Color? orange;
  final Color? purple;
  final Color? coolGray;

  @override
  CustomColors copyWith({
    Color? blue,
    Color? green,
    Color? yellow,
    Color? orange,
    Color? purple,
    Color? coolGray,
  }) {
    return CustomColors(
      blue: blue ?? this.blue,
      green: green ?? this.green,
      yellow: yellow ?? this.yellow,
      orange: orange ?? this.orange,
      purple: purple ?? this.purple,
      coolGray: coolGray ?? this.coolGray,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      blue: Color.lerp(blue, other.blue, t),
      green: Color.lerp(green, other.green, t),
      yellow: Color.lerp(yellow, other.yellow, t),
      orange: Color.lerp(orange, other.orange, t),
      purple: Color.lerp(purple, other.purple, t),
      coolGray: Color.lerp(coolGray, other.coolGray, t),
    );
  }
}
