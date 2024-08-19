import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/pages/saved_searches_page.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/widgets/w_fab_builder.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:provider/provider.dart';

import '../models/search_cache.dart';
import '../web/e621/e621_access_data.dart';
import '../widgets/w_home_end_drawer.dart';
import '../widgets/w_search_bar.dart';

class HomePage extends StatefulWidget implements IRoute<HomePage> {
  static const routeNameString = "/";
  static const allRoutesString = ["/", "/posts"];
  @override
  get routeName => routeNameString;

  final String? initialTags;
  final String? initialLimit;
  final String? initialPage;
  const HomePage({
    super.key,
    this.initialTags,
    this.initialLimit,
    this.initialPage,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // #region Logger
  late final lRecord = lm.generateLogger("HomePage");
  lm.Printer get print => lRecord.print;
  lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  @override
  void initState() {
    super.initState();
    if (!E621AccessData.devAccessData.isAssigned) {
      E621AccessData.devAccessData.getItem();
    }
    toFillSearchWith = sc.searchText;
  }

  String? toFillSearchWith;
  @override
  Widget build(BuildContext context) {
    final fsw = toFillSearchWith;
    toFillSearchWith = null;
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: WSearchBar(
            key: ObjectKey(fsw ?? sc/* Watch */.searchText),
            initialValue: fsw ?? sc/* Watch */.searchText,
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
              (value) {
                if (value != null) {
                  _sendSearchAndUpdateState(tags: value);
                  setState(() {
                    toFillSearchWith = /* sc.searchText =  */ value;
                  });
                }
              },
            );
          },
        ),
      ),
      body: SafeArea(child: buildSearchView(context)),
      endDrawer: WHomeEndDrawer(
        onSearchRequested: (searchText) {
          _sendSearchAndUpdateState(tags: searchText);
          setState(() {
            toFillSearchWith = /* sc.searchText =  */ searchText;
          });
        },
        getMountedContext: () => this.context,
      ),
      floatingActionButton: Selector2<SearchResultsNotifier, ManagedPostCollectionSync, (SearchResultsNotifier, PostCollectionSync)>(
        builder: (context, value, child) => WFabBuilder.multiplePosts(
          posts: /* sc.isMpcSync
              ? scWatch.mpcSync.collection */
              value.$2
                  .where((e) =>
                      value.$1 // Provider.of<SearchResultsNotifier>(context, listen: true)
                          .selectedPostIds
                          .contains(e.inst.$Safe?.id))
                  .map((e) => e.inst.$)
                  .toList()
              /* : Provider.of<SearchCacheLegacy>(context, listen: true)
                      .posts
                      ?.posts
                      .where((e) =>
                          value // Provider.of<SearchResultsNotifier>(context, listen: true)
                              .selectedPostIds
                              .contains(e.id))
                      .toList() ??
                  [] */,
        ),
        selector: (ctx, p1, p2) => (p1, p2.collection),
      ),
    );
  }

  // #region From WSearchView
  // JPureEvent onSelectionCleared = JPureEvent();

  ManagedPostCollectionSync get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  ManagedPostCollectionSync get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);

  @widgetFactory
  Widget buildSearchView(BuildContext context) {
    logger.info("buildSearchView");
    return Column(
      // key: ObjectKey(sc.parameters.tags),
      children: [
        // if (sc.posts == null && sc.pr != null)
        //   const Expanded(
        //     child: Center(
        //         child: AspectRatio(
        //       aspectRatio: 1,
        //       child: CircularProgressIndicator(),
        //     )),
        //   ),
        // if (sc.posts != null)
        Selector<ManagedPostCollectionSync, String>(
          builder: (context, value, child) => Expanded(
            key: ObjectKey(value), // key: ObjectKey(sc.parameters.tags),
            child: /* sc.isMpcSync
                ?  */WPostSearchResultsSwiper(
                    // key: ObjectKey(sc.parameters.tags),
                    // posts: sc,
                    useLazyBuilding: SearchView.i.lazyBuilding,
                  )/* 
                : WPostSearchResults(
                    key: ObjectKey(sc.posts!),
                    posts: sc.posts!,
                    expectedCount: SearchView.i.lazyLoad
                        ? SearchView.i.postsPerPage
                        : sc.posts!.count,
                    useLazyBuilding: SearchView.i.lazyBuilding,
                  ) */,
          ),
          selector: (ctx, p1) => p1.parameters.tags,
        ),
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
    Provider.of<ManagedPostCollectionSync>(context, listen: false).parameters =
        PostSearchQueryRecord(
      tags: tags,
      limit: limit ?? -1,
      page: encodePageParameterFromOptions(
              pageModifier: pageModifier, id: postId, pageNumber: pageNumber) ??
          "1",
    );
    // Provider.of<ManagedPostCollectionSync>(context, listen: false).launchSearch(
    //   context: context,
    //   searchViewNotifier:
    //       Provider.of<SearchResultsNotifier?>(context, listen: false),
    //   limit: limit,
    //   pageModifier: pageModifier,
    //   pageNumber: pageNumber,
    //   postId: postId,
    //   tags: tags,
    // );
  }
  // #endregion From WSearchView
}
