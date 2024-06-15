import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fuzzy/search_view_model.dart';
import 'package:j_util/platform_finder.dart';
import 'pages/home_page.dart';

void main() {
  if (Platform.isWeb) registerImgElement();
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => SearchViewModel()),
        ],
        child: const HomePage(),
      ),
    ),
  );
}
