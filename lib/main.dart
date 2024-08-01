import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/pool_view_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:j_util/platform_finder.dart';
import 'package:j_util/serialization.dart' as storable;
import 'package:path_provider/path_provider.dart' as path;
import 'package:provider/provider.dart';

import 'models/search_cache.dart';
import 'pages/home_page.dart';
import 'web/e621/e621_access_data.dart';

// #region Logger
late final ({lm.FileLogger logger, lm.Printer print}) lRecord;
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;
late final ({lm.FileLogger logger, lm.Printer print}) lRRecord;
lm.Printer get routePrint => lRRecord.print;
lm.FileLogger get routeLogger => lRRecord.logger;
// #endregion Logger

// late final Map<String, Route<dynamic>? Function(RouteSettings)> routeJumpTable = {
//   PoolViewPageBuilder.routeNameString: (settings) =>
// };
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  storable.Storable.beSilent = true;
  await lm.init().then((v) {
    lRecord = lm.genLogger("main");
    lRRecord = lm.genLogger("Routing");
  });
  if (Platform.isWeb) registerImgElement();
  pathSoundOff();
  await appDataPath.getItem() /* .ignore() */;
  await AppSettings.instance.then(
    (value) => print("Can Use AppSettings singleton"),
  );
  //.ignore();
  CachedFavorites.fileFullPath.getItem().ignore();
  CachedSearches.loadFromStorageAsync();
  // SavedDataE6Legacy.$Safe;
  SavedDataE6.init();
  E621AccessData.tryLoad().ignore();
  try {
    runApp(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name != null) {
            final url = Uri.parse(settings.name!);
            switch (url.path) {
              case HomePage.routeNameString:
                return MaterialPageRoute(builder: (ctx) => const HomePage());
              case PoolViewPageBuilder.routeNameString:
                final t = int.tryParse(url.queryParameters["poolId"] ?? "");
                if (t != null) {
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (cxt) => PoolViewPageBuilder(
                      poolId: t,
                    ),
                  );
                } else {
                  routeLogger
                      .severe("routing failure\nRoute: ${settings.name}");
                  return null;
                }
              default:
                routeLogger.severe('No Route found for "${settings.name}"');
                return null;
            }
          }
          routeLogger.info("no settings.name found, defaulting to HomePage");
          return MaterialPageRoute(builder: (ctx) => const HomePage());
        },
        theme: ThemeData.dark(),
        home: buildHomePageWithProviders(),
      ),
    );
  } catch (e, s) {
    logger.severe("FATAL ERROR", e, s);
  }
}

Widget buildHomePageWithProviders({
  String? searchText,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => SearchViewModel(searchText: searchText),
        ),
        ChangeNotifierProvider<SearchCacheLegacy>(
            create: (context) => SearchCacheLegacy()),//ManagedPostCollection()),
        ChangeNotifierProvider(create: (context) => SearchResultsNotifier()),
        ChangeNotifierProvider(
            create: (context) => CachedFavorites.loadFromStorageSync()),
        // ChangeNotifierProvider(create: (context) => SavedDataE6.$),
      ],
      child: const HomePage(),
    );
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
