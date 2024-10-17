import 'package:flutter/material.dart';

extension Str on String {
  // ignore: unnecessary_late
  static late final onlyNumeric = RegExp(r"^[0123456789]+$");

  /// [true] if this contains only 0-9, [false] otherwise.
  bool get hasOnlyNumeric => onlyNumeric.hasMatch(this);
}

// extension Constants on num {
//   int get maxDouble => 179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368;
// }
extension Ite<T> on Iterable<T> {
  /// If this is of type Set<T>, will return this without editing; otherwise, will call [toSet].
  Set<T> asSet() => this is Set<T> ? this as Set<T> : toSet();

  /// If this is of type List<T>, will return this without editing; otherwise, will call [toList].
  List<T> asList({bool growable = true}) =>
      this is List<T> ? this as List<T> : toList(growable: growable);

  /// If this is of type Set<T>, will return this without editing; otherwise, will throw.
  Set<T> isSet() => this as Set<T>;

  /// If this is of type List<T>, will return this without editing; otherwise, will throw.
  List<T> isList() => this as List<T>;
}

extension Wid<T extends Widget> on T {
  Widget wrapIf<P extends Widget>(
          P Function(T child) parentBuilder, bool condition) =>
      condition ? parentBuilder(this) : this;
}
