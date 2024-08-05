// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/saved_searches_page.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/widgets/w_fab_builder.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_result_page_navigation.dart';
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import '../models/search_cache.dart';
import '../web/e621/e621_access_data.dart';
import '../widgets/w_home_end_drawer.dart';
import '../widgets/w_search_bar.dart';

// #region Logger
late final lRecord = lm.genLogger("HomePage");
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;
// #endregion Logger

class HomePage extends StatefulWidget implements IRoute<HomePage> {
  static const routeNameString = "/";
  @override
  get routeName => routeNameString;
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    onSelectionCleared.subscribe(() {
      setState(() {
        sr.clearSelections();
      });
    });
    if (!E621AccessData.devAccessData.isAssigned) {
      E621AccessData.devAccessData.getItem();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          // child: simpleTextField(),
          child: WSearchBar(
            initialValue: scWatch.searchText,
            // onSelected: () => setState(() {}),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const SavedSearchesPageProvider /* Legacy */ (),
                )).then(
              (value) => value == null
                  ? null
                  : setState(() {
                      sc.searchText = value;
                      // svm.fillTextBarWithSearchString = true;
                      (sc.searchText.isNotEmpty)
                          ? _sendSearchAndUpdateState(tags: value)
                          : _sendSearchAndUpdateState();
                    }),
            );
          },
        ),
      ),
      body: SafeArea(child: buildSearchView(context)),
      endDrawer: WHomeEndDrawer(
        onSearchRequested: (searchText) {
          sc.searchText = searchText;
          // svm.fillTextBarWithSearchString = true;
          setState(() {
            _sendSearchAndUpdateState(tags: searchText);
          });
        },
        getMountedContext: () => this.context,
      ), //_buildDrawer(context),
      floatingActionButton: WFabBuilder.multiplePosts(
        posts: sc.isMpcSync
                ? scWatch
                    .mpcSync
                    .collection
                    .where((e) =>
                        Provider.of<SearchResultsNotifier>(context, listen: true)
                            .selectedPostIds
                            .contains(e.inst.$Safe?.id))
                    .map((e) => e.inst.$)
                    .toList()
                : Provider.of<SearchCacheLegacy>(context, listen: true)
                        .posts
                        ?.posts
                        .where((e) => Provider.of<SearchResultsNotifier>(
                                context,
                                listen: true)
                            .selectedPostIds
                            .contains(e.id))
                        .toList() ??
                    [],
        // onClearSelections: () => onSelectionCleared.invoke(),
      ),
    );
  }

  // #region From WSearchView
  SearchViewModel get svm =>
      Provider.of<SearchViewModel>(context, listen: false);

  JPureEvent onSelectionCleared = JPureEvent();

  String get priorSearchText => svm.priorSearchText;
  set priorSearchText(String value) => svm.priorSearchText = value;
  // SearchCacheLegacy get sc =>
      // Provider.of<SearchCacheLegacy>(context, listen: false);
  ManagedPostCollectionSync get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  ManagedPostCollectionSync get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);
  SearchResultsNotifier get sr =>
      Provider.of<SearchResultsNotifier>(context, listen: false);

  @widgetFactory
  Widget buildSearchView(BuildContext context) {
    return Column(
      key: ObjectKey(sc.mpcSync.parameters.tags),
      children: [
        if (sc.posts == null && sc.pr != null)
          const Expanded(
            child: Center(
                child: AspectRatio(
              aspectRatio: 1,
              child: CircularProgressIndicator(),
            )),
          ),
        if (sc.posts != null)
          (() {
            if (sc.pr != null) {
              logger.finer("Results Came back: ${svm.priorSearchText}");
            }
            // if (sc.posts!.posts.firstOrNull == null) {
            //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Results. Did you mean to login?")));
            // }
            return Expanded(
              key: ObjectKey(sc.mpcSync.parameters.tags),
              child: sc.isMpcSync
                  ? WPostSearchResultsSwiper(
                      // key: ObjectKey(sc.posts!),
                      // key: ObjectKey(svm.searchText),
                      key: ObjectKey(sc.mpcSync.parameters.tags),
                      // posts: sc /* .posts! */.mpcSync,
                      // posts: Provider.of<SearchCacheLegacy>(context).mpcSync,
                      posts: sc.mpcSync,
                      // expectedCount:
                      // svm.lazyLoad ? SearchView.i.postsPerPage : sc.posts!.count,
                      onSelectionCleared: onSelectionCleared,
                      useLazyBuilding: svm.lazyBuilding,
                    )
                  : WPostSearchResults(
                      key: ObjectKey(sc.posts!),
                      posts: sc.posts!,
                      expectedCount: svm.lazyLoad
                          ? SearchView.i.postsPerPage
                          : sc.posts!.count,
                      onSelectionCleared: onSelectionCleared,
                      useLazyBuilding: svm.lazyBuilding,
                    ),
            );
          })(),
        if (sc.posts?.posts.firstOrNull == null)
          const Align(
            alignment: AlignmentDirectional.topCenter,
            child: Text("No Results"),
          ),
        if (sc.posts != null &&
            (sc.posts.runtimeType == E6PostsSync ||
                (sc.posts as E6PostsLazy).isFullyProcessed))
          (() {
            print("BUILDING PAGE NAVIGATION");
            return WSearchResultPageNavigation(
              onNextPage: sc.hasNextPageCached ?? false
                  ? () {
                      /* if (sc.isMpc) {
                        (sc.mpc).goToNextPage();
                      } else  */if (sc.isMpcSync) {
                        (sc.mpcSync).goToNextPage();
                      }
                      _sendSearchAndUpdateState(
                        limit: SearchView.i.postsPerPage,
                        pageModifier: 'b',
                        postId: sc.lastPostOnPageIdCached,
                        tags: svm.priorSearchText,
                      );
                    }
                  : null,
              onPriorPage: sc.hasPriorPage ?? false
                  ? () {
                      /* if (sc.isMpc) {
                        sc.mpc.goToPriorPage();
                      } else  */if (sc.isMpcSync) {
                        sc.mpcSync.goToPriorPage();
                      }
                      _sendSearchAndUpdateState(
                        limit: SearchView.i.postsPerPage,
                        pageModifier: 'a',
                        postId: sc.firstPostOnPageId,
                        tags: svm.priorSearchText,
                      );
                    }
                  : null,
            );
          })(),
      ],
    );
  }

  /// Call inside of setState
  void _sendSearchAndUpdateState({
    String tags = "",
    int? limit,
    String? pageModifier,
    int? postId,
    int? pageNumber,
  }) {
    var svmWatch = Provider.of<SearchViewModel>(context),
        svm = Provider.of<SearchViewModel>(context, listen: false),
        scWatch = Provider.of<ManagedPostCollectionSync>(context),
        sc = Provider.of<ManagedPostCollectionSync>(context, listen: false);
        // scWatch = Provider.of<SearchCacheLegacy>(context),
        // sc = Provider.of<SearchCacheLegacy>(context, listen: false);
    limit ??= SearchView.i.postsPerPage;
    bool isNewRequest = false;
    var out = "pageModifier = $pageModifier, "
        "postId = $postId, "
        "pageNumber = $pageNumber,"
        "projectedTrueTags = ${E621.fillTagTemplate(tags)})";
    if (isNewRequest = (svm.priorSearchText != tags)) {
      out = "Request For New Terms: ${svm.priorSearchText} -> $tags ($out";
      sc.lastPostIdCached = null;
      sc.firstPostIdCached = null;
      svmWatch.priorSearchText = tags;
    } else {
      out = "Request For Same Terms: ${svm.priorSearchText} ($out";
    }
    print(out);
    //sr.selectedIndices.clear();
    // context.watch<SearchResultsNotifier?>()?.clearSelections();
    Provider.of(context)<SearchResultsNotifier?>()?.clearSelections();
    sc.hasNextPageCached = null;
    sc.lastPostOnPageIdCached = null;
    var username = E621AccessData.fallback?.username,
        apiKey = E621AccessData.fallback?.apiKey;
    scWatch.pr = E621.performUserPostSearch(
      tags: svm.forceSafe ? "$tags rating:safe" : tags,
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
      apiKey: apiKey,
      username: username,
    );
    sc.pr!.then((v) {
      setState(() {
        print("pr reset");
        sc.pr = null;
        var json = jsonDecode(v.responseBody);
        if (json["success"] == false) {
          print("_sendSearchAndUpdateState: Response failed: $json");
          if (json["reason"].contains("Access Denied")) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Access Denied. Did you mean to login?"),
            ));
          }
          sc.posts = E6PostsSync(posts: []);
        } else {
          sc.posts = svm.lazyLoad
              ? E6PostsLazy.fromJson(json as Map<String, dynamic>)
              : E6PostsSync.fromJson(json as Map<String, dynamic>);
        }
        if (sc.posts?.posts.firstOrNull != null) {
          if (sc.posts.runtimeType == E6PostsLazy) {
            (sc.posts as E6PostsLazy)
                .onFullyIterated
                .subscribe((a) => sc.getHasNextPage(
                      tags: svm.priorSearchText,
                      lastPostId: a.posts.last.id,
                    ));
          } else {
            sc.getHasNextPage(
                tags: svm.priorSearchText,
                lastPostId: (sc.posts as E6PostsSync).posts.last.id);
          }
        }
        if (isNewRequest) sc.firstPostIdCached = sc.firstPostOnPageId;
      });
    }).catchError((err, st) {
      print(err);
      print(st);
    });
  }
  // #endregion From WSearchView
}
