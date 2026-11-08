import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Layout and shape scale shared by Vecinal's production screens.
///
/// Color remains sourced from Material's semantic [ColorScheme], whose seed and
/// contrast are owned by the accessible theme.
@immutable
class VecinalTokens extends ThemeExtension<VecinalTokens> {
  const VecinalTokens({
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.space2xl,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusCard,
    required this.choiceTileHeight,
  });

  static const standard = VecinalTokens(
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 12,
    spaceLg: 16,
    spaceXl: 24,
    space2xl: 32,
    radiusSm: 4,
    radiusMd: 8,
    radiusLg: 12,
    radiusXl: 16,
    radiusCard: 20,
    choiceTileHeight: 144,
  );

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double space2xl;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusCard;
  final double choiceTileHeight;

  @override
  VecinalTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? space2xl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusCard,
    double? choiceTileHeight,
  }) => VecinalTokens(
    spaceXs: spaceXs ?? this.spaceXs,
    spaceSm: spaceSm ?? this.spaceSm,
    spaceMd: spaceMd ?? this.spaceMd,
    spaceLg: spaceLg ?? this.spaceLg,
    spaceXl: spaceXl ?? this.spaceXl,
    space2xl: space2xl ?? this.space2xl,
    radiusSm: radiusSm ?? this.radiusSm,
    radiusMd: radiusMd ?? this.radiusMd,
    radiusLg: radiusLg ?? this.radiusLg,
    radiusXl: radiusXl ?? this.radiusXl,
    radiusCard: radiusCard ?? this.radiusCard,
    choiceTileHeight: choiceTileHeight ?? this.choiceTileHeight,
  );

  @override
  VecinalTokens lerp(ThemeExtension<VecinalTokens>? other, double t) {
    if (other is! VecinalTokens) return this;
    return VecinalTokens(
      spaceXs: lerpDouble(spaceXs, other.spaceXs, t)!,
      spaceSm: lerpDouble(spaceSm, other.spaceSm, t)!,
      spaceMd: lerpDouble(spaceMd, other.spaceMd, t)!,
      spaceLg: lerpDouble(spaceLg, other.spaceLg, t)!,
      spaceXl: lerpDouble(spaceXl, other.spaceXl, t)!,
      space2xl: lerpDouble(space2xl, other.space2xl, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t)!,
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t)!,
      choiceTileHeight: lerpDouble(choiceTileHeight, other.choiceTileHeight, t)!,
    );
  }
}

extension VecinalTokensContext on BuildContext {
  VecinalTokens get vecinalTokens => Theme.of(this).extension<VecinalTokens>()!;
}
