import 'dart:async';

import 'package:e621/e621.dart' as e621;
import 'package:flutter/material.dart';
import 'package:fuzzy/background.dart' as bg;
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/intent.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/selected_posts.dart';
import 'package:fuzzy/models/tag_subscription.dart';
import 'package:fuzzy/pages/edit_post_page.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/home_page.dart';
import 'package:fuzzy/pages/pool_view_page.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/pages/user_profile_page.dart';
import 'package:fuzzy/pages/wiki_page.dart';
import 'package:fuzzy/util/extensions.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/widget_lib.dart' as w
    show SimpleFutureBuilder, SearchSetRoute;
import 'package:fuzzy/widgets/w_image_result.dart' show PostInfoPaneItem;
import 'package:j_util/platform_finder.dart';
import 'package:j_util/serialization.dart' as storable;
import 'package:path_provider/path_provider.dart' as path;
import 'package:provider/provider.dart';
//3.24.3 from 3.22.2

// #region Logger
late final lm.FileLogger _logger;
late final lm.FileLogger routeLogger;
// #endregion Logger
Map<String, List<String>> tryParsePathToQueryOfList(Uri u) =>
    u.pathSegments.length > 1
        ? ({
            // (RegExp(r"^[0-9]+$").hasMatch(u.pathSegments[1]) ? "id" : "idOrName"):
            (RegExp(r"^[0-9]+$").hasMatch(u.pathSegments[1]) ? "id" : "name"): [
              u.pathSegments[1]
            ]
          }..addAll(u.queryParametersAll))
        : u.queryParametersAll;
Map<String, String> tryParsePathToQuery(Uri u) => u.pathSegments.length > 1
    ? ({
        // (RegExp(r"^[0-9]+$").hasMatch(u.pathSegments[1]) ? "id" : "idOrName"):
        (RegExp(r"^[0-9]+$").hasMatch(u.pathSegments[1]) ? "id" : "name"):
            u.pathSegments[1]
      }..addAll(u.queryParameters))
    : u.queryParameters;
late final List<String> args;
late final Future<String?> _initFuture;
bool initDone = false, initFailed = false;
late String? initialSearchText, initialRouteFromIntent;
const awaitAllInitializers = false;
const DEBUG_INTENT = null; //"https://e621.net/posts/1699321";

/// TODO: https://pub.dev/packages/args
void main(List<String> args_) async {
  args = args_;
  try {
    _initFuture = _init(args: args).then((v) {
      initDone = true;
      return initialSearchText = v;
    }) /* .onError((error, stackTrace) {
      initFailed = true;
      return initialSearchText = null;
    }) */
        ;
    runApp(
      MaterialApp(
        onGenerateRoute: generateRoute,
        // TODO: routes
        // routes: {
        //   "/" : (ctx) => buildHomePageWithProviders(),
        // },
        // TODO: onUnknownRoute
        // onUnknownRoute: ,
        theme: ThemeData.dark(),
        onGenerateInitialRoutes: onGenerateInitialRoutes,
      ),
    );
  } catch (e, s) {
    try {
      _logger.severe("FATAL ERROR", e, s);
    } catch (er, st) {
      // ignore: avoid_print
      print("FATAL ERROR\n$e\n\t$s\n$er\n\t$st");
    }
  }
}

// #region init
const _initSpinner =
    SafeArea(child: ColoredBox(color: Colors.black, child: util.spinnerFitted));

// #region _topOnError
void _topOnError(Object e, StackTrace s) {
  try {
    _logger.severe("INIT ERROR", e, s);
  } catch (er, st) {
    // ignore: avoid_print
    print("INIT ERROR\n$e\n\t$s\n$er\n\t$st");
  }
}

Never _topOnErrorNever(Object e, StackTrace s) {
  _topOnError(e, s);
  Error.throwWithStackTrace(e, s);
}

Null _topOnErrorNull(Object e, StackTrace s) {
  _topOnError(e, s);
}

String _topOnErrorString(Object e, StackTrace s) {
  _topOnError(e, s);
  return "";
}

List<T> _topOnErrorList<T>(Object e, StackTrace s) {
  _topOnError(e, s);
  return <T>[];
}

// #endregion _topOnError
Future<void> _initLogs([void _]) => lm.init().then<void>((v) {
      _logger = lm.generateLogger("main").logger;
      routeLogger = lm.generateLogger("Routing").logger;
      // ignore: avoid_print
    }).onError((error, stackTrace) => print("$error\n$stackTrace"));

/// Initializes [E621AccessData] (and by extension the developer access data, if available).
Future<void> _initAccessData([void _]) => E621AccessData.tryLoad().then((_) {
      e621.activeCredentials = E621AccessData.forcedUserDataSafe?.cred;
      e621.activeUserAgent = E621AccessData.forcedUserDataSafe?.userAgent;
    });

/// Initializes [AppSettings] and, if [AppSettings.autoLoadUserProfile] is true,
/// prefetches the saved user.
///
/// Dependant on [_initAccessData].
Future<void> _initCheckPreloadUser([void _]) =>
    Future.value(AppSettings.instance.then((v) => v.autoLoadUserProfile
        ? E621.retrieveUserMostSpecific(updateIfLoggedIn: true)
        : null));

/// Initializes
/// * If not on the web
///   * pathSoundOff & add user agent
///   * else registerImgElement & don't add user agent
/// * If android
///   * bg.init
/// * CachedFavorites.fileFullPath
/// * SavedDataE6.initAsync
/// * SubscriptionManager.initAndCheckSubscriptions
List<Future<dynamic>> _initMisc() {
  (e621.addUserAgent = !Platform.isWeb) ? pathSoundOff() : registerImgElement();
  return [
    if (Platform.isAndroid) bg.init().onError(_topOnError),
    CachedFavorites.fileFullPath.getItemAsync().onError(_topOnErrorString),
    // SavedDataE6.storageAsync,
    SavedDataE6.initAsync().onError(_topOnError),
    SubscriptionManager.initAndCheckSubscriptions().onError(_topOnError),
  ];
}

/// OPTIMIZE: Make core required block and non-dependent initializers run concurrently
Future<String?> _init({
  List<String> args = const [],
  bool awaitAll = awaitAllInitializers,
}) async {
  storable.Storable.beSilent = true;
  // Needed for paths
  WidgetsFlutterBinding.ensureInitialized();
  initialSearchText = (await _initLogs()
              .then(_initAccessData)
              .then(_initCheckPreloadUser)
              .then(CachedSearches.loadFromStorageAsync)
              .onError(_topOnErrorList))
          .lastOrNull
          ?.searchString ??
      args.firstOrNull;
  if (awaitAll) {
    await Future.wait(_initMisc());
  } else {
    _initMisc();
  }
  initialRouteFromIntent = Platform.isAndroid || Platform.isIOS
      ? await initIntentHandling()
      : DEBUG_INTENT;
  Future<void>.delayed(const Duration(seconds: 1), () {
    assert(
      PostInfoPaneItem.values.length == PostInfoPaneItem.valuesSet.length,
      "${PostInfoPaneItem.values.toSet().difference(PostInfoPaneItem.valuesSet)}"
      " not added to "
      "${(#PostInfoPaneItem.valuesSet).name}",
    );
  }).onError((e, s) => _logger.warning(e, e, s));
  return initialSearchText;
}
// #endregion init

const supportedFirstPathSegments = [
  "",
  "posts",
  "pools",
  "wiki_pages",
  "post_sets",
  "post_edit",
];
Route<dynamic>? generateRoute(RouteSettings settings) {
  final f = generateWidgetForRoute(settings);
  return MaterialPageRoute(
      settings: settings,
      builder: f != null ? (_) => f : (_) => buildHomePageWithProviders());
}

Widget? generateWidgetForRoute(final RouteSettings settings) {
  routeLogger.info("GENERATING ${settings.name}");
  if (settings.name != null) {
    final url = Uri.parse(settings.name!);
    final parameters = tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id;
    } catch (_) {}
    id ??= int.tryParse(parameters["id"] ?? "");
    routeLogger.info("encoded: ${IRoute.encodePath(settings)}");
    switch (IRoute.encodePath(settings)) {
      case SettingsPageRoute.routePathConst:
        return SettingsPageRoute.generateWidgetForRouteStatic(settings);
      case w.SearchSetRoute.routePathConst:
        // return w.SearchSetRoute.legacyBuilder(settings, id, url, parameters);
        return w.SearchSetRoute.generateWidgetForRouteStatic(settings);
      case UserProfilePage.routePathConst:
        // return UserProfilePage.legacyBuilder(settings, id, url, parameters);
        return UserProfilePage.generateWidgetForRouteStatic(settings);
      case WikiPageLoader.routePathConst:
        return WikiPageLoader.legacyBuilder(settings, id, url, parameters);
      case WikiPageByTitleRoute.routePathConst:
        return WikiPageByTitleRoute.legacyBuilder(
            settings, id, url, parameters);
      case PoolViewPageLoader.routePathConst:
        return PoolViewPageLoader.legacyBuilder(settings, id, url, parameters);
      case SetViewPageLoader.routePathConst:
        return SetViewPageLoader.legacyBuilder(settings, id, url, parameters);
      case PostViewPage.routePathConst when url.pathSegments.length != 1:
        return PostViewPage.legacyBuilder(settings, id, url, parameters);
      case PostViewPage.routePathConst when url.pathSegments.length == 1:
        return HomePage.legacyBuilder(settings, id, url);
      case EditPostPageLoader.routePathConst:
        return EditPostPageLoader.legacyBuilder(settings, id, url, parameters);
      case "/" /*  when url.pathSegments.length == 1 */ :
      case "/posts" /*  when url.pathSegments.length == 1 */ :
      case HomePage.routePathConst:
        return buildHomePageWithProviders(
          searchText: url.queryParameters["tags"],
          limit: int.tryParse(url.queryParameters["limit"] ?? ""),
          page: url.queryParameters["page"],
        );
      default:
        routeLogger.severe('No Route found for "${settings.name}"');
        return null;
    }
  }
  routeLogger.info("no settings.name found, defaulting to HomePage");
  return buildHomePageWithProviders();
}

@Deprecated("Use generateWidgetForRoute")
Widget? generateWidgetForRouteLegacy(final RouteSettings settings) {
  routeLogger.info("GENERATING ${settings.name}");
  if (settings.name != null) {
    final url = Uri.parse(settings.name!);
    final parameters = tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["id"] ?? "");
    } catch (_) {
      id = int.tryParse(parameters["id"] ?? "");
    }
    switch ("/${url.pathSegments.firstOrNull}") {
      case HomePage.routeNameConst when url.pathSegments.length == 1:
        return buildHomePageWithProviders(
            searchText: url.queryParameters["tags"]);
      case WikiPageLoader.routeNameConst:
        try {
          try {
            final v = (settings.arguments as dynamic).wikiPage!;
            return WikiPage(wikiPage: v);
          } catch (_) {
            id ??= (settings.arguments as WikiPageParameters?)?.id;
            if (id != null) {
              return WikiPageLoader.fromId(id: id);
            } else if ((url.queryParameters["search[title]"] ??
                    url.queryParameters["title"] ??
                    (settings.arguments as WikiPageParameters?)?.title) !=
                null) {
              return WikiPageLoader.fromTitle(
                title: url.queryParameters["search[title]"] ??
                    url.queryParameters["title"] ??
                    (settings.arguments as WikiPageParameters).title!,
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
      case PoolViewPageLoader.routeNameConst:
        try {
          try {
            final v = (settings.arguments as dynamic).pool!;
            return ChangeNotifierProvider(
              create: (_) => SelectedPosts(),
              child: PoolViewPage(
                  pool: v is PoolModel ? v : PoolModel.fromInstance(v)),
            );
          } catch (e) {
            id ??= (settings.arguments as PoolViewParameters?)?.id;
            if (id != null) {
              return ChangeNotifierProvider(
                  create: (_) => SelectedPosts(),
                  child: PoolViewPageLoader(id: id));
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
      case SetViewPageLoader.routeNameConst:
        try {
          try {
            final v = (settings.arguments as dynamic).set!;
            return SetViewPage(
                set: v is SetModel ? v : SetModel.fromInstance(v));
          } catch (e) {
            id ??= (settings.arguments as SetViewParameters?)?.id;
            if (id != null) {
              return SetViewPageLoader(id: id);
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
      case PostViewPage.routeNameConst when url.pathSegments.length != 1:
        try {
          try {
            final v = (settings.arguments as dynamic).post!;
            return PostViewPage(postListing: v);
          } catch (e) {
            id ??= (settings.arguments as PostViewParameters?)?.id ??
                int.tryParse(parameters["postId"] ?? "");
            if (id != null) {
              return PostViewPageLoader(postId: id);
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
      case PostViewPage.routeNameConst when url.pathSegments.length == 1:
        try {
          try {
            final v = (settings.arguments as dynamic)!;
            return buildHomePageWithProviders(
              searchText: v.tags as String?,
              limit: v.limit as int?,
              page: v.page as String?,
            );
          } catch (e) {
            return buildHomePageWithProviders(
              searchText: url.queryParameters["tags"],
              limit: int.tryParse(url.queryParameters["limit"] ?? ""),
              page: url.queryParameters["page"],
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
      case EditPostPageLoader.routeNameConst:
        try {
          try {
            final v = (settings.arguments as dynamic)!.post as E6PostResponse;
            return EditPostPage(post: v);
          } catch (e) {
            id ??= (settings.arguments as PostViewParameters?)?.id ??
                int.tryParse(parameters["postId"] ?? "");
            if (id != null) {
              return EditPostPageLoader(postId: id);
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
  return buildHomePageWithProviders();
}

MultiProvider buildHomePageWithProviders({
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
MultiProvider buildWithProviders({
  // PostSearchQueryRecord? parameters,
  String? searchText,
  int? limit,
  String? page,
  Widget? child,
  TransitionBuilder? builder,
  Widget? Function(BuildContext context, Widget? child)? builderFallback,
  ChangeNotifierProvider<ManagedPostCollectionSync>? mpcProvider,
}) =>
    MultiProvider(
      providers: [
        // ChangeNotifierProvider(create: (context) => SearchViewModel()),
        mpcProvider ??
            ChangeNotifierProvider(
                create: (context) => ManagedPostCollectionSync(
                    parameters: searchText?.isNotEmpty ?? false
                        ? PostSearchQueryRecord(tags: searchText!)
                        : null)),
        ChangeNotifierProvider(create: (context) => SelectedPosts()),
        ChangeNotifierProvider(
            create: (context) => CachedFavorites.loadFromStorageSync()),
      ],
      builder: builder ??
          (builderFallback != null
              ? (a, b) =>
                  builderFallback(a, b) ??
                  child ??
                  (searchText == null
                      ? const HomePage()
                      : HomePage(initialTags: searchText))
              : null),
      child: child,
    );
void pathSoundOff() {
  const lm.LogLevel level = lm.LogLevel.FINEST;
  path
      .getApplicationCacheDirectory()
      .then((v) => _logger.log(
          level, "getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationDocumentsDirectory()
      .then((v) => _logger.log(
          level, "getApplicationDocumentsDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationSupportDirectory()
      .then((v) => _logger.log(
          level, "getApplicationSupportDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getDownloadsDirectory()
      .then((v) =>
          _logger.log(level, "getDownloadsDirectory: ${v?.absolute.path}"))
      .catchError((e, s) {});
  path
      .getExternalCacheDirectories()
      .then((v) => _logger.log(level,
          "getExternalCacheDirectories: ${v?.map((e) => e.absolute.path).join(", ")}"))
      .catchError((e, s) {});
  path
      .getTemporaryDirectory()
      .then((v) =>
          _logger.log(level, "getTemporaryDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationCacheDirectory()
      .then((v) => _logger.log(
          level, "getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
  path
      .getApplicationCacheDirectory()
      .then((v) => _logger.log(
          level, "getApplicationCacheDirectory: ${v.absolute.path}"))
      .catchError((e, s) {});
}

// #region Initial Route
bool _secondRouteManaged = false;
List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
  return [
    MaterialPageRoute(
      settings: const RouteSettings(name: "/"),
      builder: (_) => initDone
          ? _initHomePage()
          : w.SimpleFutureBuilder(
              afterCompletionBuilder: (_, __) => _initHomePage(),
              beforeCompletionChild: _initSpinner,
              onErrorBuilder: _errorBuilder,
              future: _initFuture,
            ),
    ),
    MaterialPageRoute(
      settings:
          initDone ? _initRS(initialRoute) : RouteSettings(name: initialRoute),
      builder: (_) => initDone
          ? buildWithProviders(
              searchText: args.firstOrNull ?? initialSearchText,
              builderFallback: (_, __) =>
                  generateWidgetForRoute(_initRS(initialRoute)),
            )
          : w.SimpleFutureBuilder(
              beforeCompletionChild: _initSpinner,
              future: _initFuture,
              afterCompletionBuilder: (context, _) {
                if (!_secondRouteManaged) {
                  _secondRouteManaged = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pop(context);
                    final r = (initialRouteFromIntent ?? initialRoute) != "/"
                        ? generateRoute(_initRS(initialRoute))
                        : null;
                    if (r != null) Navigator.push(context, r);
                  });
                }
                return _initSpinner;
              },
              onErrorBuilder: _errorBuilder,
            ),
    ),
  ];
}

Widget Function(BuildContext, Object?, StackTrace) get _errorBuilder =>
    (_, e, s) => ErrorPage(error: e, stackTrace: s, logger: _logger);
Widget _initHomePage() => buildHomePageWithProviders(
        searchText: args.firstOrNull ?? initialSearchText)
    .wrapIf((c) => IntentRouter(child: c), Platform.isAndroid);
RouteSettings _initRS(String initialRoute) =>
    RouteSettings(name: initialRouteFromIntent ?? initialRoute);
// #endregion Initial Route
