import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
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
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("HomePage");
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
      body: SafeArea(child: WPostSearchResultsSwiper.buildItFull(context)),
      endDrawer: WHomeEndDrawer(
        onSearchRequested: searchRequestedCallback,
        getMountedContext: () => this.context,
      ),
      floatingActionButton: WFabBuilder.buildItFull(context),
    );
  }

  ManagedPostCollectionSync get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  ManagedPostCollectionSync get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);

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
