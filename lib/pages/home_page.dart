import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/main.dart';
// import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/pages/saved_searches_page.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/widgets/w_fab_builder.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:provider/provider.dart';

import '../widgets/w_home_end_drawer.dart';
import '../widgets/w_search_bar.dart';

class HomePage extends StatefulWidget with IRoute<HomePage> {
  // #region Routing
  static const allRoutesString = ["/", "/posts"];
  static const routeNameConst = "/";
  static const routeSegmentsConst = [""];
  // static const routeSegmentsConst = ["posts"];
  static const routePathConst = "/";
  // static const routePathConst = "/posts";
  static const hasStaticPathConst = true;
  @override
  get routeName => routeNameConst;
  @override
  get routeSegmentsFolded => routePathConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;

  @override
  Widget generateWidgetForRoute(RouteSettings settings) {
    final url = Uri.parse(settings.name ?? "/");
    return buildHomePageWithProviders(
      searchText: url.queryParameters["tags"],
      limit: int.tryParse(url.queryParameters["limit"] ?? ""),
      page: url.queryParameters["page"],
    );
  }

  static Widget? legacyBuilder(RouteSettings settings, int? id, Uri url) {
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
  }
  // #endregion Routing

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
  /* // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("HomePage");
  // #endregion Logger */
  @override
  void initState() {
    super.initState();
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
    //       Provider.of<SelectedPosts?>(context, listen: false),
    //   limit: limit,
    //   pageModifier: pageModifier,
    //   pageNumber: pageNumber,
    //   postId: postId,
    //   tags: tags,
    // );
  }
}
