// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/saved_searches_page.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/widgets/w_fab_builder.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
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
    super.initState();
    onSelectionCleared.subscribe(() {
      setState(() {
        sr.clearSelections();
      });
    });
    if (!E621AccessData.devAccessData.isAssigned) {
      E621AccessData.devAccessData.getItem();
    }
    toFillSearchWith = sc.searchText;
  }

  String? toFillSearchWith;
  @override
  Widget build(BuildContext context) {
    final tfsw = toFillSearchWith;
    toFillSearchWith = null;
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          // child: simpleTextField(),
          child: WSearchBar(
            key: ObjectKey(tfsw ?? scWatch.searchText),
            initialValue: tfsw ?? scWatch.searchText,
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
                      toFillSearchWith = sc.searchText = value;
                      // svm.fillTextBarWithSearchString = true;
                      _sendSearchAndUpdateState(tags: value);
                    }),
            );
          },
        ),
      ),
      body: SafeArea(child: buildSearchView(context)),
      endDrawer: WHomeEndDrawer(
        onSearchRequested: (searchText) {
          setState(() {
            toFillSearchWith = sc.searchText = searchText;
            // svm.fillTextBarWithSearchString = true;
            _sendSearchAndUpdateState(tags: searchText);
          });
        },
        getMountedContext: () => this.context,
      ), //_buildDrawer(context),
      floatingActionButton: WFabBuilder.multiplePosts(
        posts: sc.isMpcSync
            ? scWatch.mpcSync.collection
                .where((e) =>
                    Provider.of<SearchResultsNotifier>(context, listen: true)
                        .selectedPostIds
                        .contains(e.inst.$Safe?.id))
                .map((e) => e.inst.$)
                .toList()
            : Provider.of<SearchCacheLegacy>(context, listen: true)
                    .posts
                    ?.posts
                    .where((e) => Provider.of<SearchResultsNotifier>(context,
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
  JPureEvent onSelectionCleared = JPureEvent();

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
          Expanded(
            key: ObjectKey(sc.mpcSync.parameters.tags),
            child: sc.isMpcSync
                ? WPostSearchResultsSwiper(
                    key: ObjectKey(sc.mpcSync.parameters.tags),
                    posts: sc.mpcSync,
                    // expectedCount:
                    // SearchView.i.lazyLoad ? SearchView.i.postsPerPage : sc.posts!.count,
                    // onSelectionCleared: onSelectionCleared,
                    useLazyBuilding: SearchView.i.lazyBuilding,
                  )
                : WPostSearchResults(
                    key: ObjectKey(sc.posts!),
                    posts: sc.posts!,
                    expectedCount: SearchView.i.lazyLoad
                        ? SearchView.i.postsPerPage
                        : sc.posts!.count,
                    // onSelectionCleared: onSelectionCleared,
                    useLazyBuilding: SearchView.i.lazyBuilding,
                  ),
          ),
        // if (sc.posts?.posts.firstOrNull == null)
        //   const Align(
        //     alignment: AlignmentDirectional.topCenter,
        //     child: Text("No Results"),
        //   ),
        // if (sc.posts != null &&
        //     (sc.posts.runtimeType == E6PostsSync ||
        //         (sc.posts as E6PostsLazy).isFullyProcessed))
        //   (() {
        //     print("BUILDING PAGE NAVIGATION");
        //     return WSearchResultPageNavigation(
        //       onNextPage: sc.hasNextPageCached ?? false
        //           ? () {
        //               /* if (sc.isMpc) {
        //                 (sc.mpc).goToNextPage();
        //               } else  */
        //               if (sc.isMpcSync) {
        //                 (sc.mpcSync).goToNextPage();
        //               }
        //               _sendSearchAndUpdateState(
        //                 limit: SearchView.i.postsPerPage,
        //                 pageModifier: 'b',
        //                 postId: sc.lastPostOnPageIdCached,
        //                 tags: sc.priorSearchText,
        //               );
        //             }
        //           : null,
        //       onPriorPage: sc.hasPriorPage ?? false
        //           ? () {
        //               /* if (sc.isMpc) {
        //                 sc.mpc.goToPriorPage();
        //               } else  */
        //               if (sc.isMpcSync) {
        //                 sc.mpcSync.goToPriorPage();
        //               }
        //               _sendSearchAndUpdateState(
        //                 limit: SearchView.i.postsPerPage,
        //                 pageModifier: 'a',
        //                 postId: sc.firstPostOnPageId,
        //                 tags: sc.priorSearchText,
        //               );
        //             }
        //           : null,
        //     );
        //   })(),
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
    var sc = Provider.of<ManagedPostCollectionSync>(context, listen: false);
    sc.launchSearch(
      context: context,
      searchViewNotifier:
          Provider.of<SearchResultsNotifier?>(context, listen: false),
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
      tags: tags,
    );
  }
  // #endregion From WSearchView
}
