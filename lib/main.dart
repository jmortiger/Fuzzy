import 'package:flutter/material.dart';
import 'package:j_util/platform_finder.dart';
import 'pages/home_page.dart';

void main() {
  if (Platform.isWeb) registerImgElement();
  runApp(MaterialApp(
    theme: ThemeData.dark(),
    home: const HomePage(),
  ));
}
