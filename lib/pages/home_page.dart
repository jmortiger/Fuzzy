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

  void searchRequestedCallback(String searchText) {
    _sendSearchAndUpdateState(tags: searchText);
    setState(() {
      toFillSearchWith = /* sc.searchText =  */ searchText;
    });
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
            key: ObjectKey(fsw ?? sc.searchText),
            initialValue: fsw ?? sc.searchText,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedSearchesPageProvider(),
                )).then((value) {
              if (value != null) searchRequestedCallback(value);
            });
          },
        ),
      ),
      body: SafeArea(child: buildSearchView(context)),
      endDrawer: WHomeEndDrawer(
        onSearchRequested: searchRequestedCallback,
        getMountedContext: () => this.context,
      ),
      floatingActionButton: Selector2<
          SearchResultsNotifier,
          ManagedPostCollectionSync,
          (SearchResultsNotifier, PostCollectionSync)>(
        builder: (context, value, child) => WFabBuilder.multiplePosts(
          posts: value.$2
              .where((e) => value.$1.selectedPostIds.contains(e.inst.$Safe?.id))
              .map((e) => e.inst.$)
              .toList(),
        ),
        selector: (ctx, p1, p2) => (p1, p2.collection),
        // shouldRebuild: (previous, next) => previous.$1.selectedPostIds != next.$1.selectedPostIds,
      ),
    );
  }

  ManagedPostCollectionSync get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  ManagedPostCollectionSync get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);

  @widgetFactory
  Widget buildSearchView(BuildContext context) {
    logger.info("buildSearchView");
    return Column(
      children: [
        Selector<ManagedPostCollectionSync, String>(
          builder: (context, value, child) => Expanded(
              key: ObjectKey(value),
              child: WPostSearchResultsSwiper(
                useLazyBuilding: SearchView.i.lazyBuilding,
              )),
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
}
