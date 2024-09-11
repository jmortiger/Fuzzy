import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzy/background.dart' as bg;
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
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/web/e621/models/e6_models.dart';
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
lm.Printer get _print => lRecord.print;
lm.FileLogger get _logger => lRecord.logger;
late final ({lm.FileLogger logger, lm.Printer print}) lRRecord;
lm.FileLogger get routeLogger => lRRecord.logger;
// #endregion Logger
Map<String, String> tryParsePathToQuery(Uri u) => u.pathSegments.length > 1
    ? ({"id": u.pathSegments[1]}..addAll(u.queryParameters))
    : u.queryParameters;

/// TODO: https://pub.dev/packages/args
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) bg.init();
  storable.Storable.beSilent = true;
  await lm.init().then((v) {
    lRecord = lm.generateLogger("main");
    lRRecord = lm.generateLogger("Routing");
  });
  initIntentHandling();
  if (Platform.isWeb) registerImgElement();
  pathSoundOff();
  await util.appDataPath.getItem();
  await AppSettings.instance.then(
    (value) => _print("Can Use AppSettings singleton"),
  );
  final searchText =
      (await CachedSearches.loadFromStorageAsync()).lastOrNull?.searchString;
  await E621AccessData.tryLoad();
  CachedFavorites.fileFullPath.getItemAsync().ignore();
  SavedDataE6.init();
  try {
    runApp(
      MaterialApp(
        onGenerateRoute: generateRoute,
        theme: ThemeData.dark(),
        home: buildHomePageWithProviders(
            searchText: args.firstOrNull ?? searchText),
      ),
    );
  } catch (e, s) {
    _logger.severe("FATAL ERROR", e, s);
  }
}

Route<dynamic>? generateRoute(RouteSettings settings) {
  if (settings.name != null) {
    final url = Uri.parse(settings.name!);
    final parameters = tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["poolId"] ?? parameters["id"] ?? "");
    } catch (e) {
      id = int.tryParse(parameters["poolId"] ?? parameters["id"] ?? "");
    }
    switch ("/${url.pathSegments.firstOrNull}") {
      case HomePage.routeNameString when url.pathSegments.length == 1:
        return MaterialPageRoute(
            builder: (ctx) => buildHomePageWithProviders(
                searchText: url.queryParameters["tags"]));
      case PoolViewPageBuilder.routeNameString:
        try {
          try {
            final v = (settings.arguments as dynamic).pool!;
            return MaterialPageRoute(
              settings: settings,
              builder: (cxt) => PoolViewPage(pool: v),
            );
          } catch (e) {
            id ??= (settings.arguments as PostViewParameters?)?.id;
            if (id != null) {
              return MaterialPageRoute(
                settings: settings,
                builder: (cxt) => PoolViewPageBuilder(poolId: id!),
              );
            } else {
              routeLogger.severe(
                "Routing failure\n"
                "\tRoute: ${settings.name}\n"
                "\tId: $id\n"
                "\tArgs: ${settings.arguments}",
              );
              return null;
            }
          }
        } catch (e, s) {
          routeLogger.severe(
            "Routing failure\n"
            "\tRoute: ${settings.name}\n"
            "\tId: $id\n"
            "\tArgs: ${settings.arguments}",
            e,
            s,
          );
          return null;
        }
      case PostViewPageLoader.routeNameString when url.pathSegments.length != 1:
        try {
          try {
            final v = (settings.arguments as dynamic).post!;
            return MaterialPageRoute(
              settings: settings,
              builder: (cxt) => PostViewPage(postListing: v),
            );
          } catch (e) {
            id ??= (settings.arguments as PostViewParameters?)?.id ??
                int.tryParse(parameters["postId"] ?? "");
            if (id != null) {
              return MaterialPageRoute(
                settings: settings,
                builder: (cxt) => PostViewPageLoader(postId: id!),
              );
            } else {
              routeLogger.severe(
                "Routing failure\n"
                "\tRoute: ${settings.name}\n"
                "\tId: $id\n"
                "\tArgs: ${settings.arguments}",
              );
              return null;
            }
          }
        } catch (e, s) {
          routeLogger.severe(
            "Routing failure\n"
            "\tRoute: ${settings.name}\n"
            "\tId: $id\n"
            "\tArgs: ${settings.arguments}",
            e,
            s,
          );
          return null;
        }
      case PostViewPageLoader.routeNameString when url.pathSegments.length == 1:
        try {
          try {
            final v = (settings.arguments as dynamic)!;
            return MaterialPageRoute(
              settings: settings,
              builder: (cxt) => buildHomePageWithProviders(
                searchText: v.tags as String?,
                limit: v.limit as int?,
                page: v.page as String?,
              ),
            );
          } catch (e) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => buildHomePageWithProviders(
                searchText: url.queryParameters["tags"],
                limit: int.tryParse(url.queryParameters["limit"] ?? ""),
                page: url.queryParameters["page"],
              ),
            );
          }
        } catch (e, s) {
          routeLogger.severe(
            "Routing failure\n"
            "\tRoute: ${settings.name}\n"
            "\tId: $id\n"
            "\tArgs: ${settings.arguments}",
            e,
            s,
          );
          return null;
        }
      case "/post_sets" when url.pathSegments.length != 1:
        try {
          try {
            id ??= (settings.arguments as dynamic)!.id;
            int? limit;
            String? page;
            try {
              limit = (settings.arguments as dynamic)!.limit;
              page = (settings.arguments as dynamic)!.page;
            } catch (e) {}
            return MaterialPageRoute(
              settings: settings,
              builder: (cxt) => buildHomePageWithProviders(
                searchText: id != null ? "set:$id" : null,
                limit: limit,
                page: page,
              ),
            );
          } catch (e) {
            // id ??= (settings.arguments as PostViewParameters?)?.id;
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => buildHomePageWithProviders(
                searchText: id != null ? "set:$id" : null,
                limit: int.tryParse(url.queryParameters["limit"] ?? ""),
                page: url.queryParameters["page"],
              ),
            );
          }
        } catch (e, s) {
          routeLogger.severe(
            "Routing failure\n"
            "\tRoute: ${settings.name}\n"
            "\tId: $id\n"
            "\tArgs: ${settings.arguments}",
            e,
            s,
          );
          return null;
        }
      // editPostPage:
      case EditPostPageLoader.routeNameString:
        try {
          try {
            final v = (settings.arguments as dynamic)!.post as E6PostResponse;
            return MaterialPageRoute(
              settings: settings,
              builder: (cxt) => EditPostPage(post: v),
            );
          } catch (e) {
            id ??= (settings.arguments as PostViewParameters?)?.id ??
                int.tryParse(parameters["postId"] ?? "");
            if (id != null) {
              return MaterialPageRoute(
                settings: settings,
                builder: (cxt) => EditPostPageLoader(postId: id!),
              );
            } else {
              routeLogger.severe(
                "Routing failure\n"
                "\tRoute: ${settings.name}\n"
                "\tId: $id\n"
                "\tArgs: ${settings.arguments}",
              );
              return null;
            }
          }
        } catch (e, s) {
          routeLogger.severe(
            "Routing failure\n"
            "\tRoute: ${settings.name}\n"
            "\tId: $id\n"
            "\tArgs: ${settings.arguments}",
            e,
            s,
          );
          return null;
        }
      default:
        routeLogger.severe('No Route found for "${settings.name}"');
        return null;
    }
  }
  routeLogger.info("no settings.name found, defaulting to HomePage");
  return MaterialPageRoute(
    builder: (ctx) => buildHomePageWithProviders(),
  );
}

Widget buildHomePageWithProviders({
  // PostSearchQueryRecord? parameters,
  String? searchText,
  int? limit,
  String? page,
}) =>
    buildWithProviders(
      searchText: searchText,
      limit: limit,
      page: page,
      child: searchText == null
          ? const HomePage()
          : HomePage(initialTags: searchText),
    );
Widget buildWithProviders({
  // PostSearchQueryRecord? parameters,
  String? searchText,
  int? limit,
  String? page,
  Widget? child,
  TransitionBuilder? builder,
  ChangeNotifierProvider<ManagedPostCollectionSync>? mpcProvider,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => SearchViewModel(),
        ),
        mpcProvider ??
            ChangeNotifierProvider(
                create: (context) => ManagedPostCollectionSync(
                    parameters: searchText?.isNotEmpty ?? false
                        ? PostSearchQueryRecord(tags: searchText!)
                        : null)),
        ChangeNotifierProvider(create: (context) => SearchResultsNotifier()),
        ChangeNotifierProvider(
            create: (context) => CachedFavorites.loadFromStorageSync()),
      ],
      builder: builder,
      child: child,
    );
void pathSoundOff() {
  path
      .getApplicationCacheDirectory()
      .then((v) => _print("getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationDocumentsDirectory()
      .then(
          (v) => _print("getApplicationDocumentsDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationSupportDirectory()
      .then((v) => _print("getApplicationSupportDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getDownloadsDirectory()
      .then((v) => _print("getDownloadsDirectory: ${v?.absolute.path}"))
      .catchError((e, s) {});
  path
      .getExternalCacheDirectories()
      .then((v) => _print(
          "getExternalCacheDirectories: ${v?.fold("", (previousValue, element) => "$previousValue${element.absolute.path}")}"))
      .catchError((e, s) {});
  path
      .getTemporaryDirectory()
      .then((v) => _print("getTemporaryDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationCacheDirectory()
      .then((v) => _print("getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationCacheDirectory()
      .then((v) => _print("getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
}
