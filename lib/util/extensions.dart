extension Str on String {
  // ignore: unnecessary_late
  static late final onlyNumeric = RegExp(r"^[0123456789]+$");
  /// [true] if this contains only 0-9, [false] otherwise.
  bool get hasOnlyNumeric => onlyNumeric.hasMatch(this);
}
