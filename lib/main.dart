import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/util/util.dart';
import 'package:provider/provider.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:j_util/platform_finder.dart';
import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWeb) registerImgElement();
  appDataPath.getItem();
  AppSettings.instance.then(
    (value) => print("Can Use AppSettings singleton"),
  );
  CachedFavorites.fileFullPath.getItem();
  SavedDataE6.$Async;
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => SearchViewModel()),
          ChangeNotifierProvider(create: (context) => SearchCache()),
          ChangeNotifierProvider(
              create: (context) => CachedFavorites.loadFromStorageSync()),
          // ChangeNotifierProvider(create: (context) => SavedDataE6.$),
        ],
        child: const HomePage(),
      ),
    ),
  );
}
