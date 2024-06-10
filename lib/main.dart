import 'package:flutter/material.dart';
import 'package:j_util/platform_finder.dart';
import 'pages/home_page.dart';

void main() {
  // ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
  //   final html.Element htmlElement = html.DivElement()
  //     // ..other props
  //     ..style.width = '100%'
  //     ..style.height = '100%';
  //   // ...
  //   return htmlElement;
  // });
  if (Platform.isWeb) registerImgElement();
  runApp(MaterialApp(
    theme: ThemeData.dark(),
    home: const HomePage(),
  ));
}
