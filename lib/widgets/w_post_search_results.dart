import 'dart:convert' as dc;

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/util/util.dart' as util
    show defaultOnLinkifyOpen, fullPageSpinner;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/web/e621/util.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:fuzzy/widgets/w_page_indicator.dart';
import 'package:j_util/j_util_full.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';

import 'package:fuzzy/log_management.dart' as lm;

class WPostSearchResults extends StatefulWidget {
  // ignore: unnecessary_late
  static late final _logger = lm.generateLogger("WPostSearchResults").logger;

  final int pageIndex;
  final int indexOffset;
  final E6Posts? _posts;
  E6Posts posts(BuildContext context,
          {bool listen = false, bool? filterBlacklist}) =>
      _posts ??
      E6PostsSync(
          posts: Provider.of<ManagedPostCollectionSync>(context, listen: listen)
                  .getPostsOnPageAsObjSync(pageIndex, filterBlacklist) ??
              []);
  final int expectedCount;

  bool get usesLazyPosts => posts is E6PostsLazy;

  final bool useLazyBuilding;

  final bool disallowSelections;

  final bool stripToGridView;

  final bool useProviderForPosts;

  final JPureEvent? _fireRebuild;
  const WPostSearchResults({
    super.key,
    required E6Posts posts,
    required this.expectedCount, // = 50,
    this.pageIndex = 0,
    this.indexOffset = 0,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
    bool? useProviderForPosts,
    JPureEvent? fireRebuild,
  })  : _posts = posts,
        _fireRebuild = fireRebuild,
        useProviderForPosts = useProviderForPosts ?? !stripToGridView;
  const WPostSearchResults.useProvider({
    super.key,
    // this.posts,
    required this.expectedCount, // = 50,
    this.pageIndex = 0,
    this.indexOffset = 0,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
    bool? useProviderForPosts,
    JPureEvent? fireRebuild,
  })  : _posts = null,
        _fireRebuild = fireRebuild,
        useProviderForPosts = true;
  // const WPostSearchResults.sync({
  //   super.key,
  //   required E6PostsSync this.posts,
  //   required this.expectedCount, // = 50,
  //   this.pageIndex = 0,
  //   this.indexOffset = 0,
  //   this.useLazyBuilding = false,
  //   this.disallowSelections = false,
  //   this.stripToGridView = false,
  //   bool? useProviderForPosts,
  //   JPureEvent? fireRebuild,
  // })  : _fireRebuild = fireRebuild,
  //       useProviderForPosts = useProviderForPosts ?? !stripToGridView;
  // const WPostSearchResults.lazy({
  //   super.key,
  //   required E6PostsLazy this.posts,
  //   required this.expectedCount,
  //   this.pageIndex = 0,
  //   this.indexOffset = 0,
  //   this.useLazyBuilding = false,
  //   this.disallowSelections = false,
  //   this.stripToGridView = false,
  //   bool? useProviderForPosts,
  //   JPureEvent? fireRebuild,
  // })  : _fireRebuild = fireRebuild,
  //       useProviderForPosts = useProviderForPosts ?? !stripToGridView;

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
              logger: _logger,
            );
          } else {
            return util.fullPageSpinner;
          }
        },
      );
}

class _WPostSearchResultsState extends State<WPostSearchResults>
    with WBlacklistToggle {
  static lm.FileLogger get _logger => WPostSearchResults._logger;

  int? trueCount;

  E6PostsSync? get postSync => (widget.posts.runtimeType == E6PostsSync)
      ? (widget.posts as E6PostsSync)
      : null;
  E6PostsLazy? get postLazy => (widget.posts.runtimeType == E6PostsLazy)
      ? (widget.posts as E6PostsLazy)
      : null;

  void _rebuildCallback() => setState(() {});

  // #region Blacklist Mixin
  @override
  late final OverlayPortalController portalController;
  @override
  int? get blacklistedPostCount => widget
      .posts(context, filterBlacklist: false)
      .posts
      .where((e) =>
          (SearchView.i.blacklistFavs || !e.isFavorited) &&
          hasBlacklistedTag(e.tagList))
      .length;

  @override
  E6Posts get posts => widget.posts(context);
  @override
  bool get useProvider => widget.useProviderForPosts;
  bool _filterBlacklist = true;
  @override
  bool get filterBlacklist => !widget.useProviderForPosts
      ? _filterBlacklist
      : Provider.of<ManagedPostCollectionSync>(context, listen: false)
          .filterBlacklist;
  @override
  set filterBlacklist(bool v) {
    !widget.useProviderForPosts
        ? setState(() {
            _filterBlacklist = v;
          })
        : "";
  }

  // @override
  // late final ValueNotifier<bool>? filterBlacklistNotifier;
  @override
  final ValueNotifier<bool>? filterBlacklistNotifier = null;
  // #endregion Blacklist Mixin

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
    portalController = OverlayPortalController()..show();
    // filterBlacklistNotifier = !widget.useProviderForPosts
    //     ? (ValueNotifier(true)..addListener())
    //     : null;
  }

  @override
  void dispose() {
    widget._fireRebuild?.unsubscribe(_rebuildCallback);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !widget.stripToGridView
        ? Column(
            children: [
              // TODO: Make this work lazy
              if (widget.posts(context).restrictedIndices.isNotEmpty)
                Linkify(
                  onOpen: util.defaultOnLinkifyOpen,
                  text: "${widget.posts(context).restrictedIndices.length} "
                      "hidden by global blacklist. "
                      "https://e621.net/help/global_blacklist",
                  linkStyle: const TextStyle(color: Colors.yellow),
                ),
              Expanded(child: _makeGridView(widget.posts(context))),
              super.buildBlacklistToggle(context,
                  blacklistedPosts: blacklistedPostCount),
            ],
          )
        : buildBlacklistToggle(
            context,
            child: _makeGridView(widget.posts(context)),
            blacklistedPosts: blacklistedPostCount,
          );
  }

  int get estimatedCount => widget.usesLazyPosts
      ? widget.posts(context).count
      : trueCount ?? widget.expectedCount;
  @widgetFactory
  Widget _makeGridView(E6Posts posts) {
    final sc = widget.useProviderForPosts //!widget.stripToGridView
        ? Provider.of<ManagedPostCollectionSync>(context, listen: false)
        : null;
    // TODO: Lazy builder is decades behind
    return widget.useLazyBuilding
        ? GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: SearchView.i.postsPerRow,
              crossAxisSpacing: SearchView.i.horizontalGridSpace,
              mainAxisSpacing: SearchView.i.verticalGridSpace,
              childAspectRatio: SearchView.i.widthToHeightRatio,
            ),
            itemCount: estimatedCount,
            itemBuilder: (context, index) {
              // var data = sc.mpcSync
              //     .collection
              //     .posts
              //     .elementAtOrNull(index)?.inst.$Safe;
              // TODO: Make not dependent on current page / first loaded page.
              index += sc!.currentPageFirstPostIndex;
              var data = sc.collection[index].$Safe;
              return (data == null) ? null : constructImageResult(data, index);
            }
            // (context, index) {
            //     if (trueCount == null &&
            //         widget.expectedCount - 1 == index) {
            //       posts.tryGet(index + 3);
            //     }
            //     var data = posts.tryGet(index);
            //     return (data == null)
            //         ? null
            //         : constructImageResult(data, index);
            //   },
            )
        : widget.useProviderForPosts //!widget.stripToGridView
            ? Selector<ManagedPostCollectionSync, Iterable<E6PostResponse>?>(
                selector: (context, value) =>
                    value.getPostsOnPageSync(widget.pageIndex, filterBlacklist),
                builder: (context, posts, _) {
                  return GridView.count(
                    crossAxisCount: SearchView.i.postsPerRow,
                    crossAxisSpacing: SearchView.i.horizontalGridSpace,
                    mainAxisSpacing: SearchView.i.verticalGridSpace,
                    childAspectRatio: SearchView.i.widthToHeightRatio,
                    children: sc!
                            .getPostsOnPageSync(
                                widget.pageIndex, filterBlacklist)
                            ?.mapAsList((e, i, l) => constructImageResult(
                                  e,
                                  i +
                                      sc.getPageFirstPostIndex(
                                          widget.pageIndex),
                                ))
                            .toList() ??
                        [],
                  );
                })
            : GridView.count(
                crossAxisCount: SearchView.i.postsPerRow,
                crossAxisSpacing: SearchView.i.horizontalGridSpace,
                mainAxisSpacing: SearchView.i.verticalGridSpace,
                childAspectRatio: SearchView.i.widthToHeightRatio,
                children: (() {
                  final usedPosts = <E6PostResponse>{};
                  return (Iterable<int>.generate(estimatedCount))
                      .reduceUntilTrue<List<Widget>>(
                          (accumulator, _, index, __) {
                    final p = posts.tryGet(
                      index,
                      filterBlacklist: filterBlacklist,
                    );
                    if (p != null && usedPosts.add(p)) {
                      accumulator.add(constructImageResult(p, index));
                    }
                    return (accumulator, p == null);
                  }, []);
                })(),
              );
  }

  @widgetFactory
  Widget constructImageResult(E6PostResponse data, int index) =>
      ErrorPage.errorWidgetWrapper(
        () => !widget.disallowSelections
            ? Selector<SearchResultsNotifier, bool>(
                builder: (_, value, __) => ErrorPage.errorWidgetWrapper(
                  () => WImageResult(
                    disallowSelections: widget.disallowSelections,
                    imageListing: data,
                    index: index,
                    postsCache: widget.disallowSelections
                        ? widget.posts(context).posts
                        : null,
                    isSelected: value,
                  ),
                  logger: _logger,
                ).value,
                selector: (ctx, v) => v.getIsPostSelected(data.id),
              )
            : WImageResult(
                disallowSelections: widget.disallowSelections,
                imageListing: data,
                index: index,
                postsCache: widget.disallowSelections
                    ? widget.posts(context).posts
                    : null,
                isSelected: false,
              ),
        logger: _logger,
      ).value;
}

class WPostSearchResultsSwiper extends StatefulWidget {
  // final int expectedCount;
  // final E6Posts posts;
  // final ManagedPostCollectionSync posts;

  final bool useLazyBuilding;

  final bool disallowSelections;

  final bool stripToGridView;

  final JPureEvent? _fireRebuild;
  const WPostSearchResultsSwiper({
    super.key,
    // required this.posts,
    // this.expectedCount = 50,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
    JPureEvent? fireRebuild,
  }) : _fireRebuild = fireRebuild;
  @widgetFactory
  static Widget buildItFull(BuildContext context) => Column(
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
  @override
  State<WPostSearchResultsSwiper> createState() =>
      _WPostSearchResultsSwiperState();
}

class _WPostSearchResultsSwiperState extends State<
    WPostSearchResultsSwiper> /* 
    with TickerProviderStateMixin */
{
  // #region Logger
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord =
      lm.generateLogger("WPostSearchResultsSwiperState");
  // #endregion Logger
  late PageController _pageViewController;
  // late TabController _tabController;
  int _currentPageIndex = 0;
  // int _numPages = 50;

  // late OverlayPortalController _portal;
  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
    // _tabController = TabController(length: _numPages, vsync: this);
    // _portal = OverlayPortalController()..show();
  }

  @override
  void dispose() {
    _pageViewController.dispose();
    // _tabController.dispose();
    super.dispose();
  }

  ManagedPostCollectionSync get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  ManagedPostCollectionSync get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);

  @override
  Widget build(BuildContext context) {
    String logE6Posts(Iterable<E6PostResponse>? posts) =>
        "${posts?.map((e) => e.id)}";
    // logger.info(
    //     "Building widget.posts.parameters.tags: ${widget.posts.parameters.tags} Provider.of<SearchCacheLegacy>(context).mpcSync.parameters.tags: ${scWatch.mpcSync.parameters.tags}");
    logger.info("build called");
    final root = PageView.builder(
      /// [PageView.scrollDirection] defaults to [Axis.horizontal].
      /// Use [Axis.vertical] to scroll vertically.
      controller: _pageViewController,
      onPageChanged:
          _handlePageViewChanged, //Platform.isDesktop ? _handlePageViewChanged : null,
      itemBuilder: (context, index) {
        logger.info("itemBuilder called $index");
        // var ps = widget.posts[index], t = ps.$Safe;
        // logger.finest("${widget.posts.parameters.tags} $index");
        // logger.finest("$tags $index");
        var ps = ValueAsync(value: sc.getPostsOnPageAsObj(index)),
            // value: widget.posts.getPostsOnPageAsObj(index)),
            t = ps.$Safe;
        Widget ret;
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
                    posts: snapshot.data!,
                    expectedCount: SearchView.i.postsPerPage,
                    disallowSelections: widget.disallowSelections,
                    fireRebuild: widget._fireRebuild,
                    pageIndex: index,
                    indexOffset: index * SearchView.i.postsPerPage,
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
            posts: t!,
            expectedCount: SearchView.i.postsPerPage,
            disallowSelections: widget.disallowSelections,
            fireRebuild: widget._fireRebuild,
            pageIndex: index,
            indexOffset: index * SearchView.i.postsPerPage,
            stripToGridView: widget.stripToGridView,
            useLazyBuilding: widget.useLazyBuilding,
          );
        }
        return Column(
          children: [
            Text(
              "index: $index, indexOffset: ${index * SearchView.i.postsPerPage}",
            ),
            Expanded(child: ret),
          ],
        );
      },
    );
    return Column(
      children: [
        Selector<ManagedPostCollectionSync, (int?, int?, int?)>(
          builder: (context, value, child) => Text(
              "_currentPageIndex: $_currentPageIndex, # Posts: ${value.$1 ?? "?"}, # Pages: ${value.$2 ?? "?"} (${value.$3 ?? "?"} accessible)"),
          selector: (ctx, v) => (
            v.numPostsInSearch,
            v.numPagesInSearch,
            v.numAccessiblePagesInSearch,
          ),
        ),
        Expanded(
          child: Platform.isDesktop
              ? Stack(
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    root,
                    Selector<ManagedPostCollectionSync, int>(
                      builder: (context, numPagesInSearch, child) {
                        return IndeterminatePageIndicator.builder(
                          determineNextPage: (currentPageIndex) =>
                              (currentPageIndex == numPagesInSearch - 1)
                                  ? null
                                  : currentPageIndex + 1,
                          currentPageIndex: _currentPageIndex,
                          onUpdateCurrentPageIndex:
                              _updateCurrentPageIndexWrapper,
                          pageIndicatorBuilder: (cxt, currentPageIndex) =>
                              IgnorePointer(
                                  child: Text(
                            "tabController.index: $currentPageIndex, tabController.length: $numPagesInSearch",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 1),
                                Shadow(color: Colors.black, blurRadius: 5),
                              ],
                            ),
                          )),
                        );

                        // return TabIndicatorWrapper(
                        //     key: ObjectKey("$tags$numPagesInSearch"),
                        //     numPagesInSearch: numPagesInSearch,
                        //     updateCurrentPageIndex: _updateCurrentPageIndex,
                        //     currentPageIndex: _currentPageIndex);

                        // final tabController =
                        //     TabController(length: numPagesInSearch, vsync: this);
                        // final ColorScheme colorScheme =
                        //     Theme.of(context).colorScheme;
                        // return IndeterminatePageIndicator(
                        //   determineNextPage: (currentPageIndex) =>
                        //       (currentPageIndex == /* _tabController.length */
                        //               /* _numPages */numPagesInSearch - 1)
                        //           ? null
                        //           : currentPageIndex + 1,
                        //   // tabController: _tabController,
                        //   currentPageIndex: _currentPageIndex,
                        //   // onUpdateCurrentPageIndex: _updateCurrentPageIndex,
                        //   onUpdateCurrentPageIndex: (newPageIndex, oldPageIndex) {
                        //     tabController.index = newPageIndex;
                        //     _updateCurrentPageIndex(newPageIndex);
                        //   },
                        //   pageIndicator: IgnorePointer(
                        //     child: TabPageSelector(
                        //       controller: tabController,
                        //       color: colorScheme.surface,
                        //       selectedColor: colorScheme.primary,
                        //     ),
                        //   ),
                        // );
                      },
                      selector: (ctx, v) =>
                          v.numPostsInSearch ?? E621.maxPageNumber,
                    ),
                    // PageIndicator(
                    //   tabController: _tabController,
                    //   currentPageIndex: _currentPageIndex,
                    //   onUpdateCurrentPageIndex: _updateCurrentPageIndex,
                    // ),
                  ],
                )
              : root,
        ),
        // OverlayPortal(
        //   controller: _portal,
        //   overlayChildBuilder: (_) => Positioned(
        //     bottom: 0,
        //     left: 0,
        //     child: Row(
        //       mainAxisAlignment: MainAxisAlignment.start,
        //       mainAxisSize: MainAxisSize.min,
        //       children: [
        //         const Text("Blacklist"),
        //         Selector<ManagedPostCollectionSync, bool>(
        //           selector: (_, p1) => p1.filterBlacklist,
        //           builder: (cxt, v, _) => Switch(
        //             value: v,
        //             onChanged: (v) => Provider.of<ManagedPostCollectionSync>(
        //                     cxt,
        //                     listen: false)
        //                 .filterBlacklist = v,
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
      ],
    );
  }

  void _handlePageViewChanged(int currentPageIndex) {
    _currentPageIndex = currentPageIndex;
    if (!Platform.isDesktop) {
      return;
    }
    Provider.of<ManagedPostCollectionSync>(context, listen: false)
        .goToPage(_currentPageIndex);
    setState(() {
      _currentPageIndex = currentPageIndex;
    });
  }

  void _updateCurrentPageIndex(int index) {
    // if (Platform.isDesktop) _tabController.index = index;
    (_currentPageIndex - index).abs() > 1
        ? _pageViewController.jumpToPage(index)
        : _pageViewController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
  }

  void _updateCurrentPageIndexWrapper(int index, int old) =>
      _updateCurrentPageIndex(index);
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

mixin WBlacklistToggle<T extends StatefulWidget> on State<T> {
  OverlayPortalController get portalController;
  int? get blacklistedPostCount;
  bool get useProvider;
  E6Posts get posts;
  ValueNotifier<bool>? get filterBlacklistNotifier;
  bool get filterBlacklist;

  /// Trigger reload through this
  set filterBlacklist(bool v);
  // @override
  Widget buildBlacklistToggle(
    BuildContext context, {
    int? blacklistedPosts,
    Widget? child,
  }) =>
      OverlayPortal(
        controller: portalController,
        overlayChildBuilder: (_) => Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            color: const Color.fromARGB(168, 32, 32, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    "Blacklisted: ${blacklistedPosts ?? blacklistedPostCount ?? "?"}"),
                if (useProvider)
                  Selector<ManagedPostCollectionSync, bool>(
                    selector: (_, p1) => p1.filterBlacklist,
                    builder: (cxt, v, _) => Switch(
                      value: v,
                      onChanged: (v) => Provider.of<ManagedPostCollectionSync>(
                              cxt,
                              listen: false)
                          .filterBlacklist = filterBlacklist = v,
                    ),
                  )
                else if (filterBlacklistNotifier != null)
                  SelectorNotifier(
                    value: filterBlacklistNotifier!,
                    selector: (_, p1) => p1.value,
                    builder: (cxt, v, _) => Switch(
                      value: v,
                      onChanged: (v) => filterBlacklistNotifier!.value = v,
                    ),
                  )
                else
                  Switch(
                    value: filterBlacklist,
                    onChanged: (v) => filterBlacklist = v,
                  )
              ],
            ),
          ),
        ),
        child: child,
      );
}

mixin WBlacklistToggleProvider<T extends StatefulWidget> on State<T> {
  OverlayPortalController get portalController;
  int? get blacklistedPostCount;
  // @override
  Widget buildBlacklistToggle(
    BuildContext context, {
    int? blacklistedPosts,
    Widget? child,
  }) =>
      OverlayPortal(
        controller: portalController,
        overlayChildBuilder: (_) => Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            color: const Color.fromARGB(168, 32, 32, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    "Blacklisted: ${blacklistedPosts ?? blacklistedPostCount ?? "?"}"),
                Selector<ManagedPostCollectionSync, bool>(
                  selector: (_, p1) => p1.filterBlacklist,
                  builder: (cxt, v, _) => Switch(
                    value: v,
                    onChanged: (v) => Provider.of<ManagedPostCollectionSync>(
                            cxt,
                            listen: false)
                        .filterBlacklist = v,
                  ),
                ),
              ],
            ),
          ),
        ),
        child: child,
      );
}
