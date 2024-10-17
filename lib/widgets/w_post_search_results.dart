import 'dart:convert' as dc;

import 'package:collection/collection.dart';
import 'package:e621/e621_api.dart' show maxPostSearchLimit, maxPageNumber;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:fuzzy/i_route.dart';
// import 'package:fuzzy/main.dart';
import 'package:fuzzy/models/app_settings.dart';
// import 'package:fuzzy/models/selected_posts.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/util/util.dart' as util show fullPageSpinner;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/web/e621/util.dart';
import 'package:fuzzy/widgets/post_grid.dart';
import 'package:fuzzy/widget_lib.dart' as w;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';

import 'package:fuzzy/log_management.dart' as lm;

class WPostSearchResults extends StatefulWidget {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("WPostSearchResults").logger;

  final int pageIndex;
  final int indexOffset;
  final E6Posts? _posts;
  /* E6Posts posts(
    BuildContext context, {
    bool listen = false,
    bool? filterBlacklist,
  }) {
    final f = useProviderForPosts ? Provider.of<ManagedPostCollectionSync>(context,
                        listen: listen)
                    .getPostsOnPageAsObjSync(pageIndex, filterBlacklist)??:;
    return useProviderForPosts
        ? E6PostsSync(
            posts: Provider.of<ManagedPostCollectionSync>(context,
                        listen: listen)
                    .getPostsOnPageAsObjSync(pageIndex, filterBlacklist) ??
                (filterBlacklist == null
                        ? _posts?.posts
                        : _posts?.tryGetAll(filterBlacklist: filterBlacklist))
                    ?.toList() ??
                [])
        : _posts ??
            E6PostsSync(
                posts: Provider.of<ManagedPostCollectionSync>(context,
                            listen: listen)
                        .getPostsOnPageAsObjSync(pageIndex, filterBlacklist) ??
                    []);
  } */

  @Deprecated("")
  E6Posts posts(
    BuildContext context, {
    bool listen = false,
    bool? filterBlacklist,
  }) =>
      (useProviderForPosts
          ? Provider.of<ManagedPostCollectionSync>(context, listen: listen)
                  .getPostsOnPageAsObjSync(pageIndex, filterBlacklist) ??
              _posts
          : _posts ??
              Provider.of<ManagedPostCollectionSync>(context, listen: listen)
                  .getPostsOnPageAsObjSync(pageIndex, filterBlacklist)) ??
      E6PostsSync(posts: []);

  final int expectedCount;

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
    required this.useProviderForPosts,
    JPureEvent? fireRebuild,
  })  : _posts = posts,
        _fireRebuild = fireRebuild;
  const WPostSearchResults.useProvider({
    super.key,
    required this.expectedCount, // = 50,
    this.pageIndex = 0,
    this.indexOffset = 0,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
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
  @factory
  @widgetFactory
  static Widget directResults(List<int> postIds) => FutureBuilder(
        future: (E621
            .performPostSearch(
              tags: postIds.fold(
                "order:id_asc",
                (previousValue, element) => "$previousValue ~id:$element",
              ),
              limit: maxPostSearchLimit,
            )
            .then((v) => E6PostsSync.fromJson(dc.jsonDecode(v.responseBody)))),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            try {
              return WPostSearchResults(
                posts: snapshot.data!,
                disallowSelections: true,
                expectedCount: maxPostSearchLimit,
                useProviderForPosts: false,
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

  @factory
  @widgetFactory
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
                expectedCount: maxPostSearchLimit,
                stripToGridView: true,
                useProviderForPosts: false,
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
            return util.fullPageSpinner;
          }
        },
      );
}

/// TODO: Keep scroll pos when toggling blacklist
class _WPostSearchResultsState extends State<WPostSearchResults>
    with WBlacklistToggle {
  static lm.FileLogger get logger => WPostSearchResults.logger;

  // int? trueCount;

  // @Deprecated("Non functional")
  // E6PostsSync? get postSync => (widget.posts.runtimeType == E6PostsSync)
  //     ? (widget.posts as E6PostsSync)
  //     : null;
  // @Deprecated("Non functional")
  // E6PostsLazy? get postLazy => (widget.posts.runtimeType == E6PostsLazy)
  //     ? (widget.posts as E6PostsLazy)
  //     : null;

  void _rebuildCallback() => setState(() {});

  // #region Blacklist Mixin
  @override
  late final OverlayPortalController portalController;
  @override
  int? get blacklistedPostCount => (widget.useProviderForPosts
          ? Provider.of<ManagedPostCollectionSync>(context, listen: false)
              .getPostsOnPageSync(widget.pageIndex, false)
          : widget._posts?.posts)
      ?.where((e) =>
          (SearchView.i.blacklistFavs || !e.isFavorited) &&
          hasBlacklistedTags(e.tagSet))
      .length;
  // @override
  // int? get blacklistedPostCount => widget
  //     .posts(context, filterBlacklist: false)
  //     .posts
  //     .where((e) =>
  //         (SearchView.i.blacklistFavs || !e.isFavorited) &&
  //         hasBlacklistedTags(e.tagSet))
  //     .length;

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

  @override
  final ValueNotifier<bool>? filterBlacklistNotifier = null;
  // #endregion Blacklist Mixin
  late ScrollController scroll;
  @override
  void initState() {
    super.initState();
    // trueCount = (widget.useProviderForPosts
    //       ? Provider.of<ManagedPostCollectionSync>(context, listen: false)
    //           .getPostsOnPageSync(widget.pageIndex, false)
    //       : widget._posts)?.posts.length;
    // widget._onSelectionCleared?.subscribe(_clearSelectionsCallback);
    widget._fireRebuild?.subscribe(_rebuildCallback);
    // postLazy?.onFullyIterated.subscribe(
    //   (posts) => setState(() => trueCount = posts.posts.length),
    // );
    portalController = OverlayPortalController()..show();
    // filterBlacklistNotifier = !widget.useProviderForPosts
    //     ? (ValueNotifier(true)..addListener())
    //     : null;
    scroll = ScrollController(keepScrollOffset: true);
  }

  @override
  void dispose() {
    widget._fireRebuild?.unsubscribe(_rebuildCallback);
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /* final sc = widget.useProviderForPosts //!widget.stripToGridView
        ? Provider.of<ManagedPostCollectionSync>(context, listen: false)
        : null;
    final root = widget.useLazyBuilding
        ? GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: SearchView.i.postsPerRow,
              crossAxisSpacing: SearchView.i.horizontalGridSpace,
              mainAxisSpacing: SearchView.i.verticalGridSpace,
              childAspectRatio: SearchView.i.widthToHeightRatio,
            ),
            itemCount: widget.posts(context) is! E6PostsLazy
                ? widget.posts(context).count
                : trueCount ?? widget.expectedCount,
            itemBuilder: (_, i) {
              // TODO: Make not dependent on current page / first loaded page.
              i += sc!.currentPageFirstPostIndex;
              var data = sc.collection[i].$Safe;
              return (data == null) ? null : constructImageResult(data, i);
            },
            controller: scroll,
          )
        : widget.useProviderForPosts //!widget.stripToGridView
            ? Selector<ManagedPostCollectionSync, Iterable<E6PostResponse>?>(
                selector: (context, v) =>
                    v.getPostsOnPageSync(widget.pageIndex, filterBlacklist),
                builder: (_, v, __) => GridView.count(
                  crossAxisCount: SearchView.i.postsPerRow,
                  crossAxisSpacing: SearchView.i.horizontalGridSpace,
                  mainAxisSpacing: SearchView.i.verticalGridSpace,
                  childAspectRatio: SearchView.i.widthToHeightRatio,
                  controller: scroll,
                  children: sc!
                          .getPostsOnPageSync(widget.pageIndex, filterBlacklist)
                          ?.mapTo((e, i, _) => constructImageResult(
                                e,
                                i + sc.getPageFirstPostIndex(widget.pageIndex),
                              ))
                          .toList() ??
                      [],
                ),
              )
            : GridView.count(
                crossAxisCount: SearchView.i.postsPerRow,
                crossAxisSpacing: SearchView.i.horizontalGridSpace,
                mainAxisSpacing: SearchView.i.verticalGridSpace,
                childAspectRatio: SearchView.i.widthToHeightRatio,
                controller: scroll,
                children: (() {
                  final usedPosts = <E6PostResponse>{},
                      acc = <Widget>[],
                      posts = widget.posts(context, filterBlacklist: false);
                  for (var i = 0,
                          p = posts.tryGet(i, filterBlacklist: filterBlacklist);
                      i < estimatedCount && p != null;
                      ++i,
                      p = posts.tryGet(i, filterBlacklist: filterBlacklist)) {
                    if (usedPosts.add(p)) acc.add(constructImageResult(p, i));
                  }
                  return acc;
                })(),
                // children: (() {
                //   final usedPosts = <E6PostResponse>{};
                //   return Iterable<int>.generate(estimatedCount)
                //       .reduceUntilTrue<List<Widget>>((acc, _, i, __) {
                //     final p = widget
                //         .posts(context)
                //         .tryGet(i, filterBlacklist: filterBlacklist);
                //     if (p != null && usedPosts.add(p)) {
                //       acc.add(constructImageResult(p, i));
                //     }
                //     return (acc, p == null);
                //   }, []);
                // })(),
              );
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
              Expanded(child: root),
              super.buildBlacklistToggle(context,
                  blacklistedPosts: blacklistedPostCount),
            ],
          )
        : buildBlacklistToggle(
            context,
            child: root,
            blacklistedPosts: blacklistedPostCount,
          ); */
    return buildBlacklistToggle(
      context,
      child: widget.useProviderForPosts
          ? Selector<ManagedPostCollectionSync, E6PostsSync>(
              builder: (_, posts, __) => PostGrid(
                posts: posts,
                disallowSelections: widget.disallowSelections,
                filterBlacklist: filterBlacklist,
                useProviderForPosts: widget.useProviderForPosts,
                indexOffset: widget.indexOffset,
                pageIndex: widget.pageIndex,
                stripToGridView: widget.stripToGridView,
                useLazyBuilding: widget.useLazyBuilding,
              ),
              selector: (_, v) => v.getPostsOnPageAsObjSync(
                  widget.pageIndex, filterBlacklist) as E6PostsSync,
              shouldRebuild: (prior, next) => const DeepCollectionEquality()
                  .equals(prior.posts, next.posts),
            )
          : PostGrid(
              posts: widget._posts! as E6PostsSync,
              disallowSelections: widget.disallowSelections,
              filterBlacklist: filterBlacklist,
              useProviderForPosts: widget.useProviderForPosts,
              indexOffset: widget.indexOffset,
              pageIndex: widget.pageIndex,
              stripToGridView: widget.stripToGridView,
              useLazyBuilding: widget.useLazyBuilding,
            ),
      blacklistedPosts: blacklistedPostCount,
    );
  }

  // int get estimatedCount => widget.posts(context) is! E6PostsLazy
  //     ? widget.posts(context).count
  //     : trueCount ?? widget.expectedCount;

  /* @widgetFactory
  Widget constructImageResult(E6PostResponse data, int index) =>
      ErrorPage.errorWidgetWrapper(
        () => !widget.disallowSelections
            ? Selector<SelectedPosts, bool>(
                builder: (_, value, __) => w.ImageResult(
                  key: ObjectKey(data.id),
                  disallowSelections: widget.disallowSelections,
                  imageListing: data,
                  index: index,
                  filterBlacklist: filterBlacklist,
                  postsCache: widget.disallowSelections
                      ? widget
                          .posts(context, filterBlacklist: filterBlacklist)
                          .posts
                      : null,
                  isSelected: value,
                ),
                selector: (_, v) => v.getIsPostSelected(data.id),
              )
            : w.ImageResult(
                disallowSelections: widget.disallowSelections,
                imageListing: data,
                index: index,
                filterBlacklist: filterBlacklist,
                postsCache: widget.disallowSelections
                    ? widget.useProviderForPosts
                        ? Provider.of<ManagedPostCollectionSync>(context)
                                .getPostsOnPageAsObjSync(
                                    widget.pageIndex, filterBlacklist) ??
                            widget._posts
                        : widget._posts
                    : null,
                isSelected: false,
              ),
        logger: logger,
      ).value; */
}

class WPostSearchResultsSwiper extends StatefulWidget {
  // final int expectedCount;
  // final E6Posts posts;
  // final ManagedPostCollectionSync posts;

  final bool useLazyBuilding;

  final bool disallowSelections;

  final bool stripToGridView;
  final bool useProviderForPosts;

  final JPureEvent? _fireRebuild;
  const WPostSearchResultsSwiper({
    super.key,
    // required this.posts,
    // this.expectedCount = 50,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    this.stripToGridView = false,
    JPureEvent? fireRebuild,
  })  : _fireRebuild = fireRebuild,
        useProviderForPosts = true;
  @widgetFactory
  static Widget buildItFull(BuildContext context) => Column(
        children: [
          Selector<ManagedPostCollectionSync, String>(
            builder: (_, v, __) => Expanded(
                // key: ObjectKey(v),
                child: WPostSearchResultsSwiper(
              useLazyBuilding: SearchView.i.lazyBuilding,
            )),
            selector: (_, p) => p.parameters.tags,
          ),
        ],
      );
  @override
  State<WPostSearchResultsSwiper> createState() =>
      _WPostSearchResultsSwiperState();
}

class _WPostSearchResultsSwiperState extends State<WPostSearchResultsSwiper> {
  // ignore: unnecessary_late
  static late final logger =
      lm.generateLogger("WPostSearchResultsSwiperState").logger;
  late PageController _pageViewController;
  int largestValidIndex = 0;
  int _currentPageIndex = 0;
  // int _numPages = 50;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
  }

  @override
  void dispose() {
    _pageViewController.dispose();
    super.dispose();
  }

  ManagedPostCollectionSync get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  ManagedPostCollectionSync get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);

  @override
  Widget build(BuildContext context) {
    String logE6Posts(Iterable<E6PostResponse>? posts) =>
        "${posts?.take(3).followedBy(posts.skip(posts.length - 3)).map((e) => e.id)}";
    logger.info("build called");
    final root = PageView.builder(
      /// [PageView.scrollDirection] defaults to [Axis.horizontal].
      /// Use [Axis.vertical] to scroll vertically.
      controller: _pageViewController,
      onPageChanged: _handlePageViewChanged,
      itemBuilder: (context, index) {
        logger.info("itemBuilder called $index");
        bool lowerOrEqualsCurrentPage() =>
            index <= (_pageViewController.page?.round() ?? _currentPageIndex);
        void onInvalidIndex() {
          if (lowerOrEqualsCurrentPage() && index != largestValidIndex) {
            _updateCurrentPageIndex(largestValidIndex);
          }
        }

        void onValidIndex() {
          if (largestValidIndex < index) largestValidIndex = index;
        }

        var ps = ValueAsync(value: sc.getPostsOnPageAsObj(index)), t = ps.$Safe;
        Widget ret;
        if (ps.isComplete) {
          if (t?.isEmpty ?? true) {
            logger.finer(
                "index: $index, ${t == null ? "null" : "empty"} && complete");
            onInvalidIndex();
            return null;
          } else {
            logger.finer("index: $index, sync posts: ${logE6Posts(t)}");
            onValidIndex();
            ret = Selector<ManagedPostCollectionSync, E6Posts?>(
              builder: (_, posts, __) => WPostSearchResults(
                key: ObjectKey(
                    ((posts ?? t!).firstOrNull?.id, (posts ?? t!).count)),
                posts: posts ?? t!,
                expectedCount: (posts ?? t!).count,
                disallowSelections: widget.disallowSelections,
                fireRebuild: widget._fireRebuild,
                pageIndex: index,
                indexOffset: index * SearchView.i.postsPerPage,
                stripToGridView: widget.stripToGridView,
                useLazyBuilding: widget.useLazyBuilding,
                useProviderForPosts: widget.useProviderForPosts,
              ),
              selector: (_, v) {
                logger.info("Selector sync called");
                return v.getPostsOnPageAsObjSync(index);
              },
            );
          }
        } else {
          final snapshot = ValueNotifier<
              ({
                bool isNull,
                bool isComplete,
                bool hasData,
                ({Object? error, StackTrace? stackTrace})? errorData,
                E6Posts? data
              })>((
            isNull: false,
            isComplete: false,
            hasData: false,
            errorData: null,
            data: null
          ))
            ..addListener(() => logger.info("Returned"));
          ps.future.then<void>((v) {
            logger.info("ChangingSnapshot ${logE6Posts(v)}");
            snapshot.value = (
              isNull: v == null,
              isComplete: true,
              hasData: v == null,
              errorData: null,
              data: v,
            );
          }).onError((error, stackTrace) => snapshot.value = (
                isNull: true,
                isComplete: true,
                hasData: false,
                errorData: (error: error, stackTrace: stackTrace),
                data: null,
              ));
          ret = SelectorNotifier(
            key: ObjectKey(snapshot),
            value: snapshot,
            selector: (context, value) => value.value,
            // future: ps.future,
            builder: (_, snapshot, __) {
              logger.info("Index: $index, is /* snapshot complete */: "
                  "${snapshot.isComplete} "
                  "${logE6Posts(snapshot.data)}");
              if (snapshot.isComplete && snapshot.errorData == null) {
                if (snapshot.data != null) {
                  onValidIndex();
                  // return WPostSearchResults(
                  //   posts: snapshot.data!,
                  //   expectedCount: snapshot.data!.count,
                  //   disallowSelections: widget.disallowSelections,
                  //   fireRebuild: widget._fireRebuild,
                  //   pageIndex: index,
                  //   indexOffset: index * SearchView.i.postsPerPage,
                  //   stripToGridView: widget.stripToGridView,
                  //   useLazyBuilding: widget.useLazyBuilding,
                  // );
                  final t = snapshot.data!;
                  return Selector<ManagedPostCollectionSync, E6Posts?>(
                    builder: (_, posts, __) => WPostSearchResults(
                      key: ObjectKey(
                          ((posts ?? t).firstOrNull?.id, (posts ?? t).count)),
                      posts: posts ?? t,
                      expectedCount:
                          (posts ?? t).count, //SearchView.i.postsPerPage,
                      disallowSelections: widget.disallowSelections,
                      fireRebuild: widget._fireRebuild,
                      pageIndex: index,
                      indexOffset: index * SearchView.i.postsPerPage,
                      stripToGridView: widget.stripToGridView,
                      useLazyBuilding: widget.useLazyBuilding,
                      useProviderForPosts: widget.useProviderForPosts,
                    ),
                    selector: (_, v) {
                      logger.info("Selector sync called");
                      return v.getPostsOnPageAsObjSync(index);
                    },
                  );
                  /* return Selector<ManagedPostCollectionSync, E6Posts?>(
                      builder: (_, posts, __) => WPostSearchResults(
                        key: ObjectKey((
                          (posts ?? (/* snapshot.data */ ?? ps.$Safe)!).firstOrNull?.id,
                          (posts ?? (/* snapshot.data */ ?? ps.$Safe)!).count
                        )),
                        posts: posts ?? (/* snapshot.data */ ?? ps.$Safe)!,
                        expectedCount: (posts ?? (/* snapshot.data */ ?? ps.$Safe)!)
                            .count, //SearchView.i.postsPerPage,
                        disallowSelections: widget.disallowSelections,
                        fireRebuild: widget._fireRebuild,
                        pageIndex: index,
                        indexOffset: index * SearchView.i.postsPerPage,
                        stripToGridView: widget.stripToGridView,
                        useLazyBuilding: widget.useLazyBuilding,
                      ),
                      selector: (_, v) {
                        logger.info("Selector async called");
                        return v.getPostsOnPageAsObjSync(index);
                      },
                    ); */
                } else {
                  onInvalidIndex();
                  return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Text("No Results")]);
                }
              } else if (snapshot.errorData != null) {
                // onInvalidIndex();
                return ErrorPage.logError(
                    error: snapshot.errorData!.error,
                    stackTrace: snapshot.errorData!.stackTrace,
                    logger: logger);
                /* return Column(
                    children: [
                      Text("ERROR: ${snapshot.error}"),
                      Text("StackTrace: ${snapshot.stackTrace}"),
                    ],
                  ); */
              } else {
                return const AspectRatio(
                  aspectRatio: 1,
                  child: CircularProgressIndicator(),
                );
              }
            },
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
                      builder: (context, numPagesInSearch, child) =>
                          w.IndeterminatePageIndicator.builder(
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
                      ),
                      selector: (ctx, v) =>
                          /* v.numPagesInSearch ??  */ maxPageNumber,
                      // selector: (ctx, v) =>
                      //     v.numPostsInSearch ?? E621.maxPageNumber,
                    ),
                  ],
                )
              : root,
        ),
      ],
    );
  }

  void _handlePageViewChanged(int currentPageIndex) {
    _currentPageIndex = currentPageIndex;
    if (!Platform.isDesktop) return;
    Provider.of<ManagedPostCollectionSync>(context, listen: false)
        .goToPage(_currentPageIndex);
    setState(() => _currentPageIndex = currentPageIndex);
  }

  void _updateCurrentPageIndex(int index) {
    (_currentPageIndex - index).abs() > 1
        ? _pageViewController.jumpToPage(index)
        : _pageViewController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
  }

  /// TODO: Lock out while animating?
  void _updateCurrentPageIndexWrapper(int index, int old) =>
      index != old ? _updateCurrentPageIndex(index) : "";
}

/* class PostSearchResultsLoader extends StatelessWidget
    with IRoute<PostSearchResultsLoader> {
  final String? tags;
  final int? limit;
  final String? page;
  const PostSearchResultsLoader({super.key, this.tags, this.limit, this.page});

  @override
  Widget build(BuildContext context) {
    return WPostSearchResults.directResultFromSearchWithPage(tags ?? "",
        limit: limit, page: page, stripToWidget: false);
  }

  // #region Routing
  @override
  get routeName => routeNameConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get hasStaticPath => hasStaticPathConst;

  @override
  bool acceptsRoute(RouteSettings settings) => acceptsRoutePath(settings);
  static const routeNameConst = "/posts",
      // routeNameFullString = "/posts",
      routeSegmentsConst = ["posts"],
      hasStaticPathConst = true;
  static bool acceptsRoutePath(RouteSettings settings) {
    parsePathParam(int i, String e) =>
      IRoute.pathParametersMethod[routeSegmentsConst[i]]?.call(e);
    final Uri? uri;
    if ((uri = IRoute.retrieveValidUri(
            settings, routeSegmentsConst, hasStaticPathConst)) ==
        null) {
      return false;
    }
    final id = uri!.pathSegments.foldTo<int?>(null, (p, e, i, _) {
          if (e == routeSegmentsConst[i]) return p;
          if (p != null) {
            routeLogger.warning(
                "[PostViewPage.acceptsRoutePath] Shouldn't be able to have "
                "2 id param slots in path.\n\t"
                "settings.name: ${settings.name}");
          }
          return parsePathParam(i,e)! as int;
        },
            breakIfTrue: (_, e, i, __) => !(e != routeSegmentsConst[i] &&
                parsePathParam(i,e) == null)) ??
        RouteParameters.retrieveIdFromArguments(settings);
    return id != null;
  }
  // #endregion Routing
} */

mixin WBlacklistToggle<T extends StatefulWidget> on State<T> {
  OverlayPortalController get portalController;
  int? get blacklistedPostCount;

  /// Use to make only the switch rebuild rather than needing to trigger the State to rebuild.
  bool get useProvider;

  /// Use to make only the switch rebuild rather than needing to trigger the State to rebuild.
  ValueNotifier<bool>? get filterBlacklistNotifier;

  /// The fallback for fully customized behavior; used if [useProvider] is false and [filterBlacklistNotifier] is null.
  bool get filterBlacklist;

  /// The fallback for fully customized behavior; used if [useProvider] is false and [filterBlacklistNotifier] is null. Must Trigger reload through this if used.
  set filterBlacklist(bool v);
  @nonVirtual
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
