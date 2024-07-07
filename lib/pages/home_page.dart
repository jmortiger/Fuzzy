// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/saved_searches_page.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_fab_builder.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_result_page_navigation.dart';
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import '../models/search_cache.dart';
import '../widgets/w_home_end_drawer.dart';

import 'package:fuzzy/log_management.dart' as lm;

import '../widgets/w_search_bar.dart';

late final lRecord = lm.genLogger("HomePage");
late final print = lRecord.print;
late final logger = lRecord.logger;

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

  // void workThroughSnackbarQueue() {
  //   if (util.snackbarMessageQueue.isNotEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       util.snackbarMessageQueue.removeLast(),
  //     );
  //   }
  //   if (util.snackbarBuilderMessageQueue.isNotEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       util.snackbarBuilderMessageQueue.removeLast()(context),
  //     );
  //   }
  // }
  @override
  Widget build(BuildContext context) {
    // workThroughSnackbarQueue();
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          // child: simpleTextField(),
          child: WSearchBar(
            initialValue: Provider.of<SearchViewModel>(context).searchText,
            // onSelected: () => setState(() {}),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedSearchesPageProvider(),
                )).then(
              (value) => value == null
                  ? null
                  : setState(() {
                      svm.searchText = value;
                      // svm.fillTextBarWithSearchString = true;
                      (svm.searchText.isNotEmpty)
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
          svm.searchText = searchText;
          // svm.fillTextBarWithSearchString = true;
          setState(() {
            _sendSearchAndUpdateState(tags: searchText);
          });
        },
      ), //_buildDrawer(context),
      floatingActionButton: WFabBuilder.multiplePosts(
        posts: Provider.of<SearchCache>(context, listen: true)
                .posts
                ?.posts
                .where((e) =>
                    Provider.of<SearchResultsNotifier>(context, listen: false)
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
  // #region SearchCache
  SearchCache get sc => Provider.of<SearchCache>(context, listen: false);
  E6Posts? get posts => sc.posts;
  int? get firstPostOnPageId => sc.firstPostOnPageId;
  set posts(E6Posts? value) => sc.posts = value;
  int? get firstPostIdCached => sc.firstPostIdCached;
  set firstPostIdCached(int? value) => sc.firstPostIdCached = value;
  int? get lastPostIdCached => sc.lastPostIdCached;
  set lastPostIdCached(int? value) => sc.lastPostIdCached = value;
  int? get lastPostOnPageIdCached => sc.lastPostOnPageIdCached;
  set lastPostOnPageIdCached(int? value) => sc.lastPostOnPageIdCached = value;
  bool? get hasNextPageCached => sc.hasNextPageCached;
  set hasNextPageCached(bool? value) => sc.hasNextPageCached = value;
  bool? get hasPriorPage => sc.hasPriorPage;
  // #endregion SearchCache
  SearchResultsNotifier get sr =>
      Provider.of<SearchResultsNotifier>(context, listen: false);

  @widgetFactory
  Widget buildSearchView(BuildContext context) {
    return Column(
      children: [
        if (sc.posts == null && svm.pr != null)
          const Expanded(
            child: Center(
                child: AspectRatio(
              aspectRatio: 1,
              child: CircularProgressIndicator(),
            )),
          ),
        if (sc.posts != null)
          (() {
            if (svm.pr != null) {
              logger.finer("Results Came back: ${svm.priorSearchText}");
            }
            // if (sc.posts!.posts.firstOrNull == null) {
            //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Results. Did you mean to login?")));
            // }
            return Expanded(
              child: WPostSearchResults(
                key: ObjectKey(sc.posts!),
                posts: sc.posts!,
                expectedCount:
                    svm.lazyLoad ? SearchView.i.postsPerPage : sc.posts!.count,
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
                  ? () => _sendSearchAndUpdateState(
                        limit: SearchView.i.postsPerPage,
                        pageModifier: 'b',
                        postId: sc.lastPostOnPageIdCached,
                        tags: svm.priorSearchText,
                      )
                  : null,
              onPriorPage: sc.hasPriorPage ?? false
                  ? () => _sendSearchAndUpdateState(
                        limit: SearchView.i.postsPerPage,
                        pageModifier: 'a',
                        postId: sc.firstPostOnPageId,
                        tags: svm.priorSearchText,
                      )
                  : null,
            );
          })(),
      ],
    );
  }

  /// Call inside of setState
  void _sendSearchAndUpdateState({
    String tags = "",
    int limit = 50,
    String? pageModifier,
    int? postId,
    int? pageNumber,
  }) {
    bool isNewRequest = false;
    var out = "pageModifier = $pageModifier, "
        "postId = $postId, "
        "pageNumber = $pageNumber,"
        "projectedTrueTags = ${E621.fillTagTemplate(tags)})";
    if (isNewRequest = (svm.priorSearchText != tags)) {
      out = "Request For New Terms: ${svm.priorSearchText} -> $tags ($out";
      sc.lastPostIdCached = null;
      sc.firstPostIdCached = null;
      svm.priorSearchText = tags;
    } else {
      out = "Request For Same Terms: ${svm.priorSearchText} ($out";
    }
    sr.selectedIndices.clear();
    print(out);
    sc.hasNextPageCached = null;
    sc.lastPostOnPageIdCached = null;
    var (:username, :apiKey) = svm.sendAuthHeaders &&
            (E621AccessData.userData.isAssigned ||
                E621AccessData.devAccessData.isAssigned)
        ? (
            username: E621AccessData.userData.itemSafe?.username ??
                E621AccessData.devAccessData.item.username,
            apiKey: E621AccessData.userData.itemSafe?.apiKey ??
                E621AccessData.devAccessData.item.apiKey,
          )
        : (username: null, apiKey: null);
    svm.pr = E621.performUserPostSearch(
      tags: svm.forceSafe ? "$tags rating:safe" : tags,
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
      apiKey: apiKey,
      username: username,
    );
    svm.pr!.then((v) {
      setState(() {
        print("pr reset");
        svm.pr = null;
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
