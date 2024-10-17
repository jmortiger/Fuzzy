import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/main.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/selected_posts.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/dtext_formatter.dart' as dt;
import 'package:fuzzy/web/e621/e6_actions.dart' as esa;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widget_lib.dart' as w;

import 'package:e621/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

// TODO: Add pool:### & set:## support to blacklist
class PoolViewPage extends StatefulWidget with IRoute<PoolViewPage> {
  // #region Routing
  static const routeNameConst = "/pools",
      routeSegmentsConst = ["pools", IRoute.idPathParameter],
      routePathConst = "/pools/${IRoute.idPathParameter}",
      hasStaticPathConst = false;
  @override
  get routeName => routeNameConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeSegmentsFolded => routePathConst;
  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);

  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final url = Uri.parse(settings.name!);
    final parameters = tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["id"] ?? "");
    } catch (_) {
      id = int.tryParse(parameters["id"] ?? "");
    }
    return PoolViewPageLoader.legacyBuilder(settings, id, url, parameters)!;
  }

  final PoolModel pool;
  const PoolViewPage({super.key, required this.pool});
  // #endregion Routing

  @override
  State<PoolViewPage> createState() => _PoolViewPageState();
}

var forcePostUniqueness = true;

class _PoolViewPageState extends State<PoolViewPage> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("PoolViewPage").logger;
  PoolModel get pool => widget.pool;
  List<E6PostResponse> posts = [];
  Future<List<E6PostResponse>>? loadingPosts;
  int currentPage = 1;
  JPureEvent rebuild = JPureEvent();
  String get searchString =>
      (SearchView.i.preferPoolName ? widget.pool.searchByName : null) ??
      widget.pool.searchById;
  @override
  void initState() {
    super.initState();
    if (widget.pool.posts.isAssigned) {
      posts = widget.pool.posts.$;
    } else {
      loadingPosts = widget.pool.posts.getItemAsync()
        ..then((data) {
          logger.finest("Done loading");
          setState(() {
            if (posts.isNotEmpty) {
              posts.addAll(data);
              logger.finer(
                "posts.length before set conversion: ${posts.length}",
              );
              posts = posts.toSet().toList();
              logger.finer(
                "posts.length after set conversion: ${posts.length}",
              );
            } else {
              posts = data;
            }
            loadingPosts = null;
          });
        }).ignore();
    }
    currentPage = 1;
    rebuild = JPureEvent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SelectableText.rich(
          TextSpan(
              text: "Pool ${widget.pool.id}: ${widget.pool.namePretty} by ",
              children: [
                WidgetSpan(
                    child: w.UserIdentifier(
                  id: pool.creatorId,
                  name: pool.creatorName,
                ))
                // WidgetSpan(
                //     child: Tooltip(
                //   message: "Open User #${pool.creatorId}",
                //   // TODO: Linkify
                //   // child: SelectableText(pool.creatorName),
                //   child: GestureDetector(
                //     onTap: () => defaultTryLaunchE6Url(
                //         context: context,
                //         url: e621.baseUri
                //             .replace(path: "users/${pool.creatorId}")),
                //     child: Text(pool.creatorName),
                //   ),
                // ))
              ]),
          maxLines: 1,
        ),
        actions: [
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: StatefulBuilder(builder: (context, setState) {
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  /* if ((widget.pool.searchByName != null
                            ? !esa.isInSavedSearches(widget.pool.searchByName!)
                            : true) &&
                        !esa.isInSavedSearches(widget.pool.searchById)) */
                  TextButton(
                    onPressed: () => esa
                        .addToSavedSearches(
                          text: searchString,
                          context: context,
                          parent: "Pool",
                          title: widget.pool.namePretty,
                        )
                        .then((v) => v != null ? setState(() {}) : ""),
                    child: const Text("Add to Saved Searches"),
                  ),
                  // else if (esa.isInSavedSearches(searchString))
                  //   TextButton(
                  //     onPressed: () => esa.removeFromSavedSearches(
                  //       text: searchString,
                  //       context: context,
                  //       parent: "Pool",
                  //       title: widget.pool.namePretty,
                  //     ),
                  //     child: const Text("Add to Saved Searches"),
                  //   ),
                  TextButton(
                    onPressed: () => esa.addToASavedSearch(
                      text: searchString,
                      context: context,
                    ),
                    child: const Text("Add to a Saved Search"),
                  ),
                  if ((widget.pool.searchByName != null
                          ? !esa.isSubscribed(widget.pool.searchByName!)
                          : true) &&
                      !esa.isSubscribed(widget.pool.searchById))
                    TextButton(
                      onPressed: () => esa
                          .addSubscription(
                            searchString,
                            widget.pool.postIds.last,
                            context,
                            false,
                          )
                          .then((v) => v ? setState(() {}) : ""),
                      child: const Text("Subscribe"),
                    )
                  else
                    TextButton(
                      onPressed: () => esa
                          .removeSubscription(
                            searchString,
                            widget.pool.postIds.last,
                            context,
                            false,
                          )
                          .then((v) => v ? setState(() {}) : ""),
                      child: const Text("Unsubscribe"),
                    ),
                ]);
              }))
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.pool.description.isNotEmpty)
              ExpansionTile(
                title: const Text("Description"),
                dense: true,
                initiallyExpanded: true,
                children: [
                  SelectableText.rich(
                      dt.parse(widget.pool.description) as TextSpan)
                ],
              ),
            if (posts.isNotEmpty)
              Expanded(
                child: WPostSearchResults(
                  posts: E6PostsSync(posts: posts),
                  expectedCount: posts.length,
                  disallowSelections: true,
                  stripToGridView: true,
                  useProviderForPosts: false,
                  fireRebuild: rebuild,
                ),
              ),
            if (loadingPosts != null) spinnerExpanded,
            Center(
              child: Text(
                "Loaded ${posts.length}/${widget.pool.postCount} posts",
              ),
            ),
            if (widget.pool.postCount > posts.length && loadingPosts == null)
              TextButton(
                onPressed: () => setState(() {
                  loadingPosts = widget.pool.getPosts(page: ++currentPage)
                    ..then((data) {
                      logger.info("Done loading");
                      setState(() {
                        if (posts.isNotEmpty) {
                          posts.addAll(data);
                          if (forcePostUniqueness) {
                            logger.finer(
                              "posts.length before set conversion: ${posts.length}",
                            );
                            posts = posts.toSet().toList();
                            logger.finer(
                              "posts.length after set conversion: ${posts.length}",
                            );
                          }
                        } else {
                          posts = data;
                        }
                        loadingPosts = null;
                        rebuild.invoke();
                      });
                    });
                }),
                child: const Text("Load More"),
              ),
          ],
        ),
      ),
    );
  }
}

typedef PoolViewParameters = ({e621.Pool? pool, int? id});

/// TODO: Add support for using pool name
class PoolViewPageLoader extends StatelessWidget
    with IRoute<PoolViewPageLoader> {
  // #region Routing
  static const routeNameConst = "/pools",
      routePathConst = "/pools/${IRoute.idPathParameter}",
      routeSegmentsConst = ["pools", IRoute.idPathParameter],
      hasStaticPathConst = false;
  @override
  get routeName => routeNameConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeSegmentsFolded => routePathConst;
  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);
  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final url = Uri.parse(settings.name!);
    final parameters = tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["id"] ?? "");
    } catch (_) {
      id = int.tryParse(parameters["id"] ?? "");
    }
    return PoolViewPageLoader.legacyBuilder(settings, id, url, parameters)!;
  }

  static Widget? legacyBuilder(RouteSettings settings, int? id, Uri url,
      Map<String, String> parameters) {
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
  }
  // #endregion Routing

  final int id;

  const PoolViewPageLoader({
    required this.id,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: e621.sendRequest(e621.initPoolGet(id)).then((v) => PoolViewPage(
            pool: PoolModel.fromRawJson(v.body),
          )),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          try {
            return snapshot.data!;
          } catch (e, s) {
            return Scaffold(
              appBar: AppBar(),
              body: Text(
                  "$e\n$s\n${snapshot.data}\n${snapshot.error}\n${snapshot.stackTrace}"),
            );
          }
        } else if (snapshot.hasError) {
          return ErrorPage(
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
            logger: _PoolViewPageState.logger,
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: Text("Pool $id")),
            body: const Column(children: [spinnerExpanded]),
          );
        }
      },
    );
  }
}

class SetViewPage extends StatefulWidget with IRoute<SetViewPage> {
  // #region Routing
  // static const routeNameConst = "/setView",
  static const routeNameConst = "/post_sets",
      routePathConst = "/post_sets/${IRoute.idPathParameter}",
      routeSegmentsConst = ["post_sets", IRoute.idPathParameter],
      hasStaticPathConst = false;
  @override
  get routeName => routeNameConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeSegmentsFolded => routePathConst;
  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);
  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final url = Uri.parse(settings.name!),
        parameters = tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["id"] ?? "");
    } catch (_) {
      id = int.tryParse(parameters["id"] ?? "");
    }
    return SetViewPageLoader.legacyBuilder(settings, id, url, parameters)!;
  }

  // #endregion Routing
  final SetModel set;
  const SetViewPage({super.key, required this.set});

  @override
  State<SetViewPage> createState() => _SetViewPageState();
}

// var forcePostUniqueness = true;
/// TODO: Currently forced to use ordered methodology, make optional, default to 'set:id'
class _SetViewPageState extends State<SetViewPage> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("SetViewPage").logger;
  SetModel get set => widget.set;
  List<E6PostResponse> posts = [];
  Future<List<E6PostResponse>>? loadingPosts;
  int currentPage = 1;
  JPureEvent rebuild = JPureEvent();
  @override
  void initState() {
    super.initState();
    if (widget.set.posts.isAssigned) {
      posts = widget.set.posts.$;
    } else {
      loadingPosts = widget.set.posts.getItemAsync()
        ..then((data) {
          logger.finest("Done loading");
          setState(() {
            if (posts.isNotEmpty) {
              posts.addAll(data);
              final before = posts.length,
                  after = (posts = posts.toSet().toList()).length;
              logger.finer(
                  "posts set conversion\n\tbefore: $before\n\tafter: $after");
            } else {
              posts = data;
            }
            loadingPosts = null;
          });
        }).ignore();
    }
    currentPage = 1;
    rebuild = JPureEvent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text.rich(TextSpan(
          text: "Set ${set.id}: ${set.name} (${set.shortname}) by ",
          children: [WidgetSpan(child: w.UserIdentifier(id: set.creatorId))],
        )),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.set.description.isNotEmpty)
              ExpansionTile(
                title: const Text("Description"),
                dense: true,
                initiallyExpanded: true,
                children: [
                  SelectableText.rich(
                      dt.parse(widget.set.description) as TextSpan)
                ],
              ),
            if (posts.isNotEmpty)
              Expanded(
                child: WPostSearchResults(
                  posts: E6PostsSync(posts: posts),
                  expectedCount: posts.length,
                  disallowSelections: true,
                  stripToGridView: true,
                  useProviderForPosts: false,
                  fireRebuild: rebuild,
                ),
              ),
            if (loadingPosts != null) spinnerExpanded,
            Center(
              child: Text(
                "Loaded ${posts.length}/${widget.set.postCount} posts",
              ),
            ),
            if (widget.set.postCount > posts.length && loadingPosts == null)
              TextButton(
                onPressed: () => setState(() {
                  loadingPosts = widget.set.getPosts(page: ++currentPage)
                    ..then((data) {
                      logger.info("Done loading");
                      setState(() {
                        if (posts.isNotEmpty) {
                          posts.addAll(data);
                          if (forcePostUniqueness) {
                            logger.finer(
                              "posts.length before set conversion: ${posts.length}",
                            );
                            posts = posts.toSet().toList();
                            logger.finer(
                              "posts.length after set conversion: ${posts.length}",
                            );
                          }
                        } else {
                          posts = data;
                        }
                        loadingPosts = null;
                        rebuild.invoke();
                      });
                    });
                }),
                child: const Text("Load More"),
              ),
          ],
        ),
      ),
    );
  }
}

typedef SetViewParameters = ({e621.PostSet? set, int? id});

class SetViewPageLoader extends StatelessWidget with IRoute<SetViewPageLoader> {
  // #region Routing
  static const routeNameConst = "/post_sets",
      routePathConst = "/post_sets/${IRoute.idPathParameter}",
      routeSegmentsConst = ["post_sets", IRoute.idPathParameter],
      hasStaticPathConst = false;
  @override
  get routeName => routeNameConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeSegmentsFolded => routePathConst;
  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);
  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final url = Uri.parse(settings.name!),
        parameters = tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["id"] ?? "");
    } catch (_) {
      id = int.tryParse(parameters["id"] ?? "");
    }
    return SetViewPageLoader.legacyBuilder(settings, id, url, parameters)!;
  }

  static Widget? legacyBuilder(RouteSettings settings, int? id, Uri url,
      Map<String, String> parameters) {
    try {
      try {
        final v = (settings.arguments as dynamic).set!;
        return SetViewPage(set: v is SetModel ? v : SetModel.fromInstance(v));
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
  }
  // #endregion Routing

  final int id;

  const SetViewPageLoader({
    required this.id,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: e621
          .sendRequest(e621.initSetGet(id))
          .then((v) => SetViewPage(set: SetModel.fromRawJson(v.body))),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          try {
            return snapshot.data!;
          } catch (e, s) {
            return Scaffold(
              appBar: AppBar(),
              body: Text(
                  "$e\n$s\n${snapshot.data}\n${snapshot.error}\n${snapshot.stackTrace}"),
            );
          }
        } else if (snapshot.hasError) {
          return ErrorPage(
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
            logger: _SetViewPageState.logger,
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: Text("Set $id")),
            body: const Column(children: [spinnerExpanded]),
          );
        }
      },
    );
  }
}
