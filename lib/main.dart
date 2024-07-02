import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/platform_finder.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lm.init().then((v) => print = lm.genPrint("main"));
  if (Platform.isWeb) registerImgElement();
  pathSoundOff();
  appDataPath.getItem();
  AppSettings.instance.then(
    (value) => print("Can Use AppSettings singleton"),
  );
  CachedFavorites.fileFullPath.getItem();
  CachedSearches.loadFromStorageAsync();
  SavedDataE6.$Safe;
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => SearchViewModel()),
          ChangeNotifierProvider(create: (context) => SearchCache()),
          ChangeNotifierProvider(create: (context) => SearchResultsNotifier()),
          ChangeNotifierProvider(
              create: (context) => CachedFavorites.loadFromStorageSync()),
          // ChangeNotifierProvider(create: (context) => SavedDataE6.$),
        ],
        child: const HomePage(),
      ),
    ),
  );
}

late final print;
void pathSoundOff() {
  path
      .getApplicationCacheDirectory()
      .then((v) => print("getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationDocumentsDirectory()
      .then(
          (v) => print("getApplicationDocumentsDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationSupportDirectory()
      .then((v) => print("getApplicationSupportDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getDownloadsDirectory()
      .then((v) => print("getDownloadsDirectory: ${v?.absolute.path}"))
      .catchError((e, s) {});
  path
      .getExternalCacheDirectories()
      .then((v) => print(
          "getExternalCacheDirectories: ${v?.fold("", (previousValue, element) => "$previousValue${element.absolute.path}")}"))
      .catchError((e, s) {});
  path
      .getTemporaryDirectory()
      .then((v) => print("getTemporaryDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationCacheDirectory()
      .then((v) => print("getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationCacheDirectory()
      .then((v) => print("getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
}
