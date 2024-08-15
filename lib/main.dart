import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzy/intent.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/edit_post_page.dart';
import 'package:fuzzy/pages/pool_view_page.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:j_util/platform_finder.dart';
import 'package:j_util/serialization.dart' as storable;
import 'package:path_provider/path_provider.dart' as path;
import 'package:provider/provider.dart';
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
Map<String, String> tryParsePathToQuery(Uri u) => u.pathSegments.length > 1
    ? ({"id": u.pathSegments[1]}..addAll(u.queryParameters))
    : u.queryParameters;

/// TODO: https://pub.dev/packages/args
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  storable.Storable.beSilent = true;
  await lm.init().then((v) {
    lRecord = lm.generateLogger("main");
    lRRecord = lm.generateLogger("Routing");
  });
  initIntentHandling();
  if (Platform.isWeb) registerImgElement();
  pathSoundOff();
  await appDataPath.getItem() /* .ignore() */;
  await AppSettings.instance.then(
    (value) => print("Can Use AppSettings singleton"),
  );
  //.ignore();
  final searchText =
      (await CachedSearches.loadFromStorageAsync()).firstOrNull?.searchString;
  await E621AccessData.tryLoad(); //.ignore();
  CachedFavorites.fileFullPath.getItem().ignore();
  SavedDataE6.init();
  try {
    runApp(
      MaterialApp(
        // navigatorKey: _navigatorKey,
        onGenerateRoute: (settings) {
          if (settings.name != null) {
            final url = Uri.parse(settings.name!);
            switch ("/${url.pathSegments.firstOrNull}") {
              case HomePage.routeNameString when url.pathSegments.length == 1:
                return MaterialPageRoute(
                    builder: (ctx) => buildHomePageWithProviders(
                        searchText: url
                            .queryParameters["tags"]) /* const HomePage() */);
              case PoolViewPageBuilder.routeNameString:
                final parameters = tryParsePathToQuery(url);
                final t = int.tryParse(parameters["poolId"] ??
                    parameters["id"] ??
                    tryParsePathToQuery(url)["id"] ??
                    "");
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
              case PostViewPageLoader.routeNameString:
                final t = int.tryParse(url.queryParameters["postId"] ??
                    url.queryParameters["id"] ??
                    tryParsePathToQuery(url)["id"] ??
                    "");
                if (t != null) {
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (cxt) => PostViewPageLoader(
                      postId: t,
                    ),
                  );
                } else {
                  routeLogger
                      .severe("routing failure\nRoute: ${settings.name}");
                  return null;
                }
              case EditPostPageLoader.routeNameString:
                final t = int.tryParse(url.queryParameters["postId"] ??
                    url.queryParameters["id"] ??
                    tryParsePathToQuery(url)["id"] ??
                    "");
                if (t != null) {
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (cxt) => EditPostPageLoader(
                      postId: t,
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
          return MaterialPageRoute(
              builder: (ctx) =>
                  buildHomePageWithProviders() /* const HomePage() */);
        },
        theme: ThemeData.dark(),
        home: buildHomePageWithProviders(
            searchText: args.firstOrNull ?? searchText),
      ),
    );
  } catch (e, s) {
    logger.severe("FATAL ERROR", e, s);
  }
}

Widget buildHomePageWithProviders({
  String? searchText,
  int? limit,
  String? page,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => SearchViewModel(),
        ),
        ChangeNotifierProvider(
            create: (context) => ManagedPostCollectionSync(
                parameters: searchText?.isNotEmpty ?? false
                    ? PostSearchQueryRecord(tags: searchText!)
                    : null)),
        ChangeNotifierProvider(create: (context) => SearchResultsNotifier()),
        ChangeNotifierProvider(
            create: (context) => CachedFavorites.loadFromStorageSync()),
        // ChangeNotifierProvider(create: (context) => SavedDataE6.$),
      ],
      child: searchText == null
          // ? const HomePage()
          ? Selector<ManagedPostCollectionSync, Future?>(
              builder: (context, value, child) =>
                  HomePage(initialTags: searchText),
              selector: (cxt, p) => p.pr,
              shouldRebuild: (previous, next) => previous != next,
            )
          : Selector<ManagedPostCollectionSync, Future?>(
              builder: (context, value, child) =>
                  HomePage(initialTags: searchText),
              selector: (cxt, p) => p.pr,
              shouldRebuild: (previous, next) => previous != next,
            ),
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
