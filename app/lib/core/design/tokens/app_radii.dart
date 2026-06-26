import 'package:flutter/widgets.dart';

/// Corner-radius tokens.
///
/// Surfaces use a consistent, slightly rounded language; [pill] is reserved for
/// fully-rounded elements like the primary button and chips.
abstract final class AppRadii {
  /// 8 — inputs and small chips.
  static const double sm = 8;

  /// 12 — default for cards and tiles.
  static const double md = 12;

  /// 16 — sheets and large containers.
  static const double lg = 16;

  /// Fully rounded (pill / circle).
  static const double pill = 999;

  /// [BorderRadius] for [md], the most common case.
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
}
