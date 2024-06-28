import 'dart:ui';

import 'package:flutter/material.dart';

class MyScrollBehavior extends ScrollBehavior {
  static const _dragDevices = {...PointerDeviceKind.values};
  @override
  Set<PointerDeviceKind> get dragDevices => _dragDevices;
}
