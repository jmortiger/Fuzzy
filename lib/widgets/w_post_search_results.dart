import 'dart:convert' as dc;

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:fuzzy/widgets/w_page_indicator.dart';
import 'package:j_util/j_util_full.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fuzzy/log_management.dart' as lm;

import '../models/search_cache.dart';

class WPostSearchResults extends StatefulWidget {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WPostSearchResults");
  // #endregion Logger

  final int pageIndex;
  final int indexOffset;
  final E6Posts posts;
  final int expectedCount;
  final void Function(Set<int> indices, int newest)? onPostsSelected;

  final bool? usesLazyPosts;

  final bool useLazyBuilding;

  final bool disallowSelections;

  final bool stripToGridView;

  final JPureEvent? _fireRebuild;
  const WPostSearchResults({
    super.key,
    required this.posts,
    required this.expectedCount, // = 50,
    this.pageIndex = 0,
    this.indexOffset = 0,
    this.onPostsSelected,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
    JPureEvent? fireRebuild,
  })  : _fireRebuild = fireRebuild,
        usesLazyPosts = null;
  const WPostSearchResults.sync({
    super.key,
    required E6PostsSync this.posts,
    required this.expectedCount, // = 50,
    this.pageIndex = 0,
    this.indexOffset = 0,
    this.onPostsSelected,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
    JPureEvent? fireRebuild,
  })  : _fireRebuild = fireRebuild,
        usesLazyPosts = false;
  const WPostSearchResults.lazy({
    super.key,
    required E6PostsLazy this.posts,
    required this.expectedCount,
    this.pageIndex = 0,
    this.indexOffset = 0,
    this.onPostsSelected,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
    JPureEvent? fireRebuild,
  })  : _fireRebuild = fireRebuild,
        usesLazyPosts = true;

  @override
  State<WPostSearchResults> createState() => _WPostSearchResultsState();

  static Widget directResults(List<int> postIds) => FutureBuilder(
        future: (E621
            .performPostSearch(
              tags: postIds.fold(
                "order:id_asc",
                (previousValue, element) => "$previousValue ~id:$element",
              ),
              limit: E621.maxPostsPerSearch,
            )
            .then((v) => E6PostsSync.fromJson(dc.jsonDecode(v.responseBody)))),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            try {
              return WPostSearchResults(
                posts: snapshot.data!,
                disallowSelections: true,
                expectedCount: E621.maxPostsPerSearch,
              );
            } catch (e, s) {
              return Scaffold(
                body: Text("$e\n$s\n${snapshot.data}\n${snapshot.stackTrace}"),
              );
            }
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Text("${snapshot.error}\n${snapshot.stackTrace}"),
            );
          } else {
            return const Scaffold(
              body: CircularProgressIndicator(),
            );
          }
        },
      );
  static Widget directResultFromSearchWithPage(
    String tags, {
    String? page,
    int? limit,
    bool stripToWidget = true,
  }) {
    var (:String? pageModifier, :int? pageNumber, id: int? postId) =
        parsePageParameter(page);
    return directResultFromSearch(
      tags,
      pageModifier: pageModifier,
      postId: postId,
      pageNumber: pageNumber,
      limit: limit,
      stripToWidget: stripToWidget,
    );
  }

  static Widget directResultFromSearch(
    String tags, {
    String? pageModifier,
    int? postId,
    int? pageNumber,
    int? limit,
    bool stripToWidget = true,
  }) =>
      FutureBuilder(
        future: (E621
            .performPostSearch(
              tags: tags,
              pageModifier: pageModifier,
              postId: postId,
              pageNumber: pageNumber,
              limit: limit,
            )
            .then((v) => E6PostsSync.fromJson(dc.jsonDecode(v.responseBody)))),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            try {
              final r = WPostSearchResults(
                posts: snapshot.data!,
                disallowSelections: true,
                expectedCount: E621.maxPostsPerSearch,
                stripToGridView: true,
              );
              return stripToWidget
                  ? r
                  : SafeArea(
                      child: Scaffold(
                      appBar: AppBar(
                        title: Text("[${encodePageParameterFromOptions(
                              pageModifier: pageModifier,
                              id: postId,
                              pageNumber: pageNumber,
                            ) ?? 1}]$tags"),
                      ),
                      body: Column(
                        children: [Expanded(child: r)],
                      ),
                    ));
            } catch (e, s) {
              return Scaffold(
                body: Text("$e\n$s\n${snapshot.data}\n${snapshot.stackTrace}"),
              );
            }
          } else if (snapshot.hasError) {
            return ErrorPage(
              error: snapshot.error,
              stackTrace: snapshot.stackTrace,
              logger: logger,
            );
          } else {
            return fullPageSpinner;
          }
        },
      );
}

class _WPostSearchResultsState extends State<WPostSearchResults> {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WPostSearchResultsState");
  // #endregion Logger
  // #region Notifiers
  Set<int> _selectedIndices = {};
  Set<int> _selectedPostIds = {};

  SearchCacheLegacy get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  SearchCacheLegacy get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);
  SearchResultsNotifier get sr =>
      Provider.of<SearchResultsNotifier>(context, listen: false);
  SearchResultsNotifier get srl =>
      Provider.of<SearchResultsNotifier>(context, listen: true);
  Set<int> get selectedIndices =>
      widget.disallowSelections ? _selectedIndices : sr.selectedIndices;
  Set<int> get selectedPostIds =>
      widget.disallowSelections ? _selectedPostIds : sr.selectedPostIds;

  set selectedIndices(Set<int> value) => widget.disallowSelections
      ? setState(() {
          _selectedIndices = value;
        })
      : srl.selectedIndices = SetNotifier.from(value);
  set selectedPostIds(Set<int> value) => widget.disallowSelections
      ? setState(() {
          _selectedPostIds = value;
        })
      : srl.selectedPostIds = SetNotifier.from(value);
  bool getIsIndexSelected(int index) => widget.disallowSelections
      ? _selectedIndices.contains(index)
      : sr.getIsSelected(index);
  bool getIsPostIdSelected(int index) => widget.disallowSelections
      ? _selectedPostIds.contains(index)
      : sr.getIsPostSelected(index);
  // #endregion Notifiers

  int? trueCount;

  E6PostsSync? get postSync => (widget.posts.runtimeType == E6PostsSync)
      ? (widget.posts as E6PostsSync)
      : null;
  E6PostsLazy? get postLazy => (widget.posts.runtimeType == E6PostsLazy)
      ? (widget.posts as E6PostsLazy)
      : null;
  void _clearSelectionsCallback() {
    if (mounted) {
      setState(() {
        selectedIndices.clear();
        selectedPostIds.clear();
      });
    } else {
      print("Dismounted?");
    }
  }

  void _rebuildCallback() => setState(() {});

  @override
  void initState() {
    super.initState();
    trueCount = postSync?.posts.length;
    // widget._onSelectionCleared?.subscribe(_clearSelectionsCallback);
    widget._fireRebuild?.subscribe(_rebuildCallback);
    postLazy?.onFullyIterated.subscribe(
      (FullyIteratedArgs posts) => setState(() {
        trueCount = posts.posts.length;
      }),
    );
  }

  @override
  void dispose() {
    // widget._onSelectionCleared?.unsubscribe(_clearSelectionsCallback);
    widget._fireRebuild?.unsubscribe(_rebuildCallback);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !widget.stripToGridView
        ? Column(
            children: [
              // TODO: Make this work lazy
              if (widget.posts.restrictedIndices.isNotEmpty)
                Linkify(
                  onOpen: (link) async {
                    if (!await launchUrl(Uri.parse(link.url))) {
                      throw Exception('Could not launch ${link.url}');
                    }
                  },
                  text:
                      "${widget.posts.restrictedIndices.length} hidden by global"
                      " blacklist. https://e621.net/help/global_blacklist",
                  // style: TextStyle(color: Colors.yellow),
                  linkStyle: const TextStyle(color: Colors.yellow),
                ),
              Expanded(child: _makeGridView(widget.posts)),
            ],
          )
        : _makeGridView(widget.posts);
  }

  int get estimatedCount => widget.usesLazyPosts != null
      ? widget.usesLazyPosts!
          ? widget.posts.count
          : trueCount ?? widget.expectedCount
      : widget.posts.runtimeType == E6PostsSync
          ? widget.posts.count
          : trueCount ?? widget.expectedCount;
  @widgetFactory
  GridView _makeGridView(E6Posts posts) {
    return widget.useLazyBuilding
        ? GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppSettings.i!.searchView.postsPerRow,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: SearchView.i.widthToHeightRatio,
            ),
            itemCount: estimatedCount,
            itemBuilder: sc.isMpcSync
                ? (context, index) {
                    // var data = sc.mpcSync
                    //     .collection
                    //     .posts
                    //     .elementAtOrNull(index)?.inst.$Safe;
                    // TODO: Make not dependent on current page / first loaded page.
                    index += sc.mpcSync.currentPageFirstPostIndex;
                    var data = sc.mpcSync.collection[index].$Safe;
                    return (data == null)
                        ? null
                        : constructImageResult(data, index);
                  }
                : (context, index) {
                    if (trueCount == null &&
                        widget.expectedCount - 1 == index) {
                      posts.tryGet(index + 3);
                    }
                    var data = posts.tryGet(index);
                    return (data == null)
                        ? null
                        : constructImageResult(data, index);
                  },
          )
        : GridView.count(
            crossAxisCount: AppSettings.i!.searchView.postsPerRow,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: SearchView.i.widthToHeightRatio,
            children: !widget.stripToGridView // sc.isMpcSync
                ? sc.mpcSync
                        .getPostsOnPageSync(widget.pageIndex)
                        ?.mapAsList((e, i, l) => constructImageResult(
                              e,
                              i +
                                  sc.mpcSync
                                      .getPageFirstPostIndex(widget.pageIndex),
                            ))
                        .toList() ??
                    []
                : (Iterable<int>.generate(estimatedCount)).reduceUntilTrue(
                    (accumulator, _, index, __) => posts.tryGet(index) != null
                        ? (
                            accumulator
                              ..add(
                                constructImageResult(
                                    posts.tryGet(index)!, index),
                              ),
                            false
                          )
                        : (accumulator, true),
                    []),
          );
  }

  @widgetFactory
  Widget constructImageResult(E6PostResponse data, int index) =>
      Selector<SearchResultsNotifier, bool>(
        builder: (context, value, child) => WImageResult(
          disallowSelections: widget.disallowSelections,
          imageListing: data,
          index: index,
          postsCache: widget.disallowSelections ? widget.posts.posts : null,
          // isSelected: getIsIndexSelected(index),
          // isSelected: getIsPostIdSelected(data.id),
          isSelected: value,
        ),
        selector: (ctx, v) => v.getIsPostSelected(data.id),
      );
}

class WPostSearchResultsSwiper extends StatefulWidget {
  // final int expectedCount;
  // final E6Posts posts;
  final ManagedPostCollectionSync posts;
  final void Function(Set<int> indices, int newest)? onPostsSelected;

  final bool useLazyBuilding;

  final bool disallowSelections;

  final bool stripToGridView;

  final JPureEvent? _fireRebuild;
  const WPostSearchResultsSwiper({
    super.key,
    required this.posts,
    // this.expectedCount = 50,
    this.onPostsSelected,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
    JPureEvent? fireRebuild,
  }) : _fireRebuild = fireRebuild;

  @override
  State<WPostSearchResultsSwiper> createState() =>
      _WPostSearchResultsSwiperState();
}

class _WPostSearchResultsSwiperState extends State<WPostSearchResultsSwiper>
    with TickerProviderStateMixin {
  // #region Logger
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord =
      lm.generateLogger("WPostSearchResultsSwiperState");
  // #endregion Logger
  late PageController _pageViewController;
  late TabController _tabController;
  int _currentPageIndex = 0;
  int _numPages = 50;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
    _tabController = TabController(length: _numPages, vsync: this);
  }

  @override
  void dispose() {
    _pageViewController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  SearchCacheLegacy get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  SearchCacheLegacy get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);

  @override
  Widget build(BuildContext context) {
    String logE6Posts(Iterable<E6PostResponse>? posts) =>
        "${posts?.map((e) => e.id)}";
    logger.finest(
        "Building widget.posts.parameters.tags: ${widget.posts.parameters.tags} Provider.of<SearchCacheLegacy>(context).mpcSync.parameters.tags: ${scWatch.mpcSync.parameters.tags}");
    return Selector<ManagedPostCollectionSync, String>(
      builder: (context, tags, child) => Column(
        key: ObjectKey(
          tags,
          // scWatch.mpcSync.parameters.tags,
        ),
        children: [
          Selector<ManagedPostCollectionSync, int?>(
            builder: (context, value, child) => Text(
                "_currentPageIndex: $_currentPageIndex, totalPages: ${((value ?? 750 * SearchView.i.postsPerPage) / SearchView.i.postsPerPage).ceil()}"),
            selector: (ctx, v) =>
                v.totalPostsInSearch.$Safe ?? v.numPostsInSearch,
          ),
          Expanded(
            key: ObjectKey(
              tags,
              // scWatch.mpcSync.parameters.tags,
            ),
            child: Stack(
              key: ObjectKey(
                tags,
                // scWatch.mpcSync.parameters.tags,
              ),
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                PageView.builder(
                  key: ObjectKey(
                    tags,
                    // scWatch.mpcSync.parameters.tags,
                  ),

                  /// [PageView.scrollDirection] defaults to [Axis.horizontal].
                  /// Use [Axis.vertical] to scroll vertically.
                  controller: _pageViewController,
                  onPageChanged:
                      _handlePageViewChanged, //Platform.isDesktop ? _handlePageViewChanged : null,
                  itemBuilder: (context, index) {
                    // var ps = widget.posts[index], t = ps.$Safe;
                    // logger.finest("${widget.posts.parameters.tags} $index");
                    logger.finest("$tags $index");
                    var ps = ValueAsync(
                            value: widget.posts.getPostsOnPageAsObj(index)),
                        t = ps.$Safe;
                    Widget ret;
                    Key? key;
                    // key = widget.key;
                    // key = ObjectKey(widget.posts.parameters.tags);
                    // key = ObjectKey("${widget.posts.parameters.tags}$index");
                    key = ObjectKey("$tags $index");
                    // logger.finer("index: $index, sync posts: ${t?.map(
                    //   (element) => element.id,
                    // )}");

                    if (ps.isComplete && t == null) {
                      logger.finer("index: $index, empty && complete}");
                      return null;
                    } else if (!ps.isComplete) {
                      ret = FutureBuilder(
                        future: ps.future,
                        builder: (context, snapshot) {
                          logger.info("Index: $index snapshot complete "
                              "${snapshot.hasData || snapshot.hasError} "
                              "${logE6Posts(snapshot.data)}");
                          if (snapshot.hasData || ps.isComplete) {
                            if (snapshot.data != null) {
                              return WPostSearchResults(
                                key: key,
                                posts: snapshot.data!,
                                expectedCount: SearchView.i.postsPerPage,
                                disallowSelections: widget.disallowSelections,
                                fireRebuild: widget._fireRebuild,
                                pageIndex: index,
                                indexOffset: index * SearchView.i.postsPerPage,
                                onPostsSelected: widget.onPostsSelected,
                                stripToGridView: widget.stripToGridView,
                                useLazyBuilding: widget.useLazyBuilding,
                              );
                            } else {
                              return const Column(
                                children: [Expanded(child: Text("No Results"))],
                              );
                            }
                          } else if (snapshot.hasError) {
                            return Column(
                              children: [
                                Text("ERROR: ${snapshot.error}"),
                                Text("StackTrace: ${snapshot.stackTrace}"),
                              ],
                            );
                          } else {
                            return const AspectRatio(
                              aspectRatio: 1,
                              child: CircularProgressIndicator(),
                            );
                          }
                        },
                      );
                    } else {
                      logger.finer("index: $index, sync posts: ${t?.map(
                        (element) => element.id,
                      )}");
                      ret = WPostSearchResults(
                        key: key,
                        posts: t!,
                        expectedCount: SearchView.i.postsPerPage,
                        disallowSelections: widget.disallowSelections,
                        fireRebuild: widget._fireRebuild,
                        pageIndex: index,
                        indexOffset: index * SearchView.i.postsPerPage,
                        onPostsSelected: widget.onPostsSelected,
                        stripToGridView: widget.stripToGridView,
                        useLazyBuilding: widget.useLazyBuilding,
                      );
                    }
                    return Column(
                      key: key,
                      children: [
                        Text(
                          "index: $index, indexOffset: ${index * SearchView.i.postsPerPage}",
                        ),
                        Expanded(child: ret),
                      ],
                    );
                  },
                ),
                if (Platform.isDesktop)
                  PageIndicator(
                    tabController: _tabController,
                    currentPageIndex: _currentPageIndex,
                    onUpdateCurrentPageIndex: _updateCurrentPageIndex,
                  ),
              ],
            ),
          ),
        ],
      ),
      selector: (context, mpc) => mpc.parameters.tags,
      // shouldRebuild: (prior, latter) => prior != latter,
    );
  }

  void _handlePageViewChanged(int currentPageIndex) {
    _currentPageIndex = currentPageIndex;
    if (!Platform.isDesktop) {
      return;
    }
    _tabController.index = currentPageIndex;
    setState(() {
      _currentPageIndex = currentPageIndex;
    });
  }

  void _updateCurrentPageIndex(int index) {
    if (Platform.isDesktop) _tabController.index = index;
    _pageViewController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

class PostSearchResultsBuilder extends StatelessWidget
    implements IRoute<PostSearchResultsBuilder> {
  final String? tags;
  final int? limit;
  final String? page;
  const PostSearchResultsBuilder({super.key, this.tags, this.limit, this.page});

  @override
  Widget build(BuildContext context) {
    return WPostSearchResults.directResultFromSearchWithPage(tags ?? "",
        limit: limit, page: page, stripToWidget: false);
  }

  @override
  String get routeName => routeNameString;
  static const routeNameString = "/posts";
}
