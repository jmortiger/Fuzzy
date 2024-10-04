import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/log_management.dart' show SymbolName;
// import 'package:fuzzy/models/search_results.dart' as srn_lib;

import '../widgets/w_page_indicator.dart';

// #region Unmanaged
class PostSwipePage extends StatefulWidget implements IRoute<PostSwipePage> {
  static const routeNameString = "/";

  final bool startFullscreen;
  @override
  get routeName => routeNameString;
  final int initialIndex;
  final E6Posts? postsObj;
  final Iterable<E6PostResponse>? postsIterable;
  Iterable<E6PostResponse> get posts => postsObj?.posts ?? postsIterable!;
  final void Function(String addition)? onAddToSearch;
  // final srn_lib.SearchResultsNotifier? selectedPosts;
  final List<E6PostResponse>? selectedPosts;

  const PostSwipePage.postsCollection({
    super.key,
    required this.initialIndex,
    required Iterable<E6PostResponse> posts,
    this.onAddToSearch,
    this.startFullscreen = false,
    this.selectedPosts,
  })  : postsObj = null,
        postsIterable = posts;
  const PostSwipePage({
    super.key,
    required this.initialIndex,
    required E6Posts posts,
    this.onAddToSearch,
    this.startFullscreen = false,
    this.selectedPosts,
  })  : postsObj = posts,
        postsIterable = null;

  @override
  State<PostSwipePage> createState() => _PostSwipePageState();
}

class _PostSwipePageState extends State<PostSwipePage>
    with TickerProviderStateMixin {
  late PageController _pageViewController;
  late TabController _tabController;
  late int _currentPageIndex;
  String toReturn = "";
  bool isFullscreen = false;
  @override
  void initState() {
    super.initState();
    isFullscreen = widget.startFullscreen;
    _pageViewController = PageController(
      initialPage: widget.initialIndex,
      keepPage: false,
    );
    if (Platform.isDesktop) {
      _currentPageIndex = widget.initialIndex;
      _tabController = TabController(
        initialIndex: widget.initialIndex,
        length: widget.posts.length,
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    if (Platform.isDesktop) {
      _tabController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final root = PageView(
      // scrollBehavior: MyScrollBehavior(),

      /// [PageView.scrollDirection] defaults to [Axis.horizontal].
      /// Use [Axis.vertical] to scroll vertically.
      controller: _pageViewController,
      allowImplicitScrolling: true,
      // onPageChanged: _handlePageViewChanged,
      children: widget.posts.mapAsList(
        (elem, index, list) => PostViewPage.overrideFullscreen(
          postListing: elem,
          onAddToSearch: onAddToSearch,
          getFullscreen: () => isFullscreen,
          setFullscreen: (v) => setState(() {
            isFullscreen = v;
          }),
          onPop: onPop,
          selectedPosts: widget.selectedPosts,
        ),
      ),
    );
    if (!Platform.isDesktop) {
      return root;
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        root,
        PageIndicator(
          tabController: _tabController,
          currentPageIndex: _currentPageIndex,
          onUpdateCurrentPageIndex: _updateCurrentPageIndex,
        ),
      ],
    );
  }

  void onAddToSearch(String s) {
    // widget.onAddToSearch?.call(s);
    toReturn = "$toReturn $s";
    tagsToAddToSearch.add(s);
  }

  final tagsToAddToSearch = <String>[];
  void onPop() => Navigator.pop(context, (
        tagsToAddToSearch: tagsToAddToSearch,
        selectedPosts: widget.selectedPosts,
      ));

  void _handlePageViewChanged(int currentPageIndex) {
    if (!Platform.isDesktop) {
      return;
    }
    _tabController.index = currentPageIndex;
    setState(() {
      _currentPageIndex = currentPageIndex;
    });
  }

  void _updateCurrentPageIndex(int index) {
    _tabController.index = index;
    _pageViewController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

// #endregion Unmanaged
class PostSwipePageManaged extends StatefulWidget
    implements IRoute<PostSwipePageManaged> {
  static const routeNameString = "/";

  final bool startFullscreen;
  @override
  get routeName => routeNameString;
  final int initialIndex;
  final int initialPageIndex;
  final bool? filterBlacklist;
  final ManagedPostCollectionSync postsObj;
  Iterable<E6PostResponse> get posts => postsObj.posts!.posts;
  Iterable<E6PostEntrySync> get postCache => postsObj.collection.posts;
  final void Function(String addition)? onAddToSearch;
  final List<E6PostResponse>? selectedPosts;

  const PostSwipePageManaged({
    super.key,
    required this.initialIndex,
    required this.initialPageIndex,
    required ManagedPostCollectionSync posts,
    this.onAddToSearch,
    this.startFullscreen = false,
    required this.selectedPosts,
    required this.filterBlacklist,
  }) : postsObj = posts;

  @override
  State<PostSwipePageManaged> createState() => _PostSwipePageManagedState();
}

class _PostSwipePageManagedState extends State<PostSwipePageManaged>
    with TickerProviderStateMixin {
  // ignore: unnecessary_late
  static late final logger =
      lm.generateLogger("PostSwipePageManagedState").logger;
  late PageController _pageViewController;
  late int _currentPostPageIndex;

  /// Used for the page indicator on desktop
  late ValueNotifier<int>? currentPostPageIndexNotifier;
  String toReturn = "";
  bool isFullscreen = false;
  late final List<Widget> _extras;
  List<Widget> get extras => (loopy ?? onFinished) != null ? [cancel] : _extras;
  late final Widget cancel;
  final tagsToAddToSearch = <String>[];
  @override
  void initState() {
    super.initState();
    isFullscreen = widget.startFullscreen;
    _pageViewController = PageController(
      initialPage: widget.initialIndex,
      keepPage: false,
    );
    currentPostPageIndexNotifier =
        Platform.isDesktop ? ValueNotifier<int>(widget.initialIndex) : null;
    _currentPostPageIndex = widget.initialIndex;
    widget.postsObj.currentPostIndex = widget.initialIndex;
    _extras = [makeSlideshow(context)];
    cancel = ActionButton(
      tooltip: "Stop Slideshow",
      icon: const Icon(Icons.close),
      onPressed: stopSlideshow,
    );
  }

  @override
  void dispose() {
    stopSlideshow();
    currentPostPageIndexNotifier?.dispose();
    _pageViewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final root = PageView.builder(
      controller: _pageViewController,
      allowImplicitScrolling: true,
      onPageChanged: _handlePageViewChanged,
      itemBuilder: (context, index) => ErrorPage.errorCatcher<Widget?>(
        () => _pageBuilder(context, index),
        context: context,
        logger: logger,
      ),
    );
    return !Platform.isDesktop
        ? root
        : Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              root,
              SelectorNotifier(
                value: currentPostPageIndexNotifier!,
                builder: (context, currentPostPageIndex, child) {
                  return IndeterminatePageIndicator.builder(
                    determineNextPage: (currPageIndex) =>
                        (currPageIndex >= widget.postsObj.numStoredPosts - 1)
                            ? null
                            : currPageIndex + 1,
                    currentPageIndex: currentPostPageIndex,
                    onUpdateCurrentPageIndex: _updateCurrentPageIndexWrapper,
                    pageIndicatorBuilder: (_, currPage) => IgnorePointer(
                        child: Text("currentPageIndex: $currPage")),
                  );
                },
                selector: (context, value) => value.value,
              ),
            ],
          );
  }

  /// Presumes [index] is the overall index, not the index on current page
  Widget? _pageBuilder(BuildContext context, int index) {
    final page = widget.postsObj.getPageIndexOfGivenPost(index);
    logger.info("[${(#_pageBuilder).name}]\n\tIndex: $index\n\tPageInd: $page");
    var ps = ValueAsync(
            value: widget.postsObj
                .getPostsOnPageAsObj(page, widget.filterBlacklist)),
        t = ps.$Safe;
    if (ps.isComplete && t == null) {
      return null;
    } else if (!ps.isComplete) {
      return FutureBuilder(
        future: ps.future,
        builder: (context, snapshot) {
          logger.info("Index: $index "
              "PageIndex: $page "
              "snapshot complete ${snapshot.hasData || snapshot.hasError} "
              "${snapshot.data}");
          return snapshot.hasData
              ? snapshot.data != null
                  ? ErrorPage.errorWidgetWrapper(
                      () {
                        return PostViewPage.overrideFullscreen(
                          postListing: snapshot.data![
                              widget.postsObj.getPostIndexOnPage(index, page)],
                          onAddToSearch: onAddToSearch,
                          onPop: onPop,
                          getFullscreen: () => isFullscreen,
                          setFullscreen: (v) => setState(() {
                            isFullscreen = v;
                          }),
                          extraActions: extras,
                          selectedPosts: widget.selectedPosts,
                        );
                      },
                      logger: logger,
                    ).value
                  : const Column(
                      children: [Expanded(child: Text("No Results"))],
                    )
              : snapshot.hasError
                  ? ErrorPage(
                      error: snapshot.error,
                      stackTrace: snapshot.stackTrace,
                      logger: logger,
                    )
                  : util.fullPageSpinner;
        },
      );
    } else {
      // final p =
      //     t!.elementAtOrNull(widget.postsObj.getPostIndexOnPage(index, page));
      final p = t!.tryGet(widget.postsObj.getPostIndexOnPage(index, page));
      return p != null
          ? PostViewPage.overrideFullscreen(
              postListing: p,
              onAddToSearch: onAddToSearch,
              onPop: onPop,
              getFullscreen: () => isFullscreen,
              setFullscreen: (v) => setState(() => isFullscreen = v),
              extraActions: extras,
              selectedPosts: widget.selectedPosts,
            )
          : null;
    }
  }

  void onAddToSearch(String s) {
    toReturn = "$toReturn $s";
    tagsToAddToSearch.add(s);
  }

  void onPop() {
    Navigator.pop(context, (
      tagsToAddToSearch: tagsToAddToSearch,
      selectedPosts: widget.selectedPosts,
    ));
  }

  // #region Slideshow
  Widget makeSlideshow(BuildContext context) {
    return ActionButton(
      icon: const Icon(Icons.timelapse),
      tooltip: "Slideshow",
      onPressed: () {
        showDialog<
            ({bool reverse, double time, bool fullscreen, bool repeatPage})>(
          context: context,
          builder: (_) {
            double time = 5;
            var reverse = false, fullscreen = false, repeatPage = false;
            return StatefulBuilder(
              builder: (ctx, setState) => AlertDialog(
                title: const Text("Slideshow"),
                content: SizedBox.expand(
                  child: Column(
                    children: [
                      Row(children: [
                        Slider(
                          label: "$time sec.",
                          onChanged: (value) => setState(() => time = value),
                          value: time,
                          divisions: 29,
                          min: 1,
                          max: 30,
                        ),
                        Text("$time sec."),
                      ]),
                      Row(children: [
                        const Text("Reverse?"),
                        Checkbox(
                          value: reverse,
                          onChanged: (value) =>
                              setState(() => reverse = value!),
                        ),
                      ]),
                      Row(children: [
                        const Text("Fullscreen?"),
                        Checkbox(
                          value: fullscreen,
                          onChanged: (value) =>
                              setState(() => fullscreen = value!),
                        ),
                      ]),
                      Row(children: [
                        const Text("Repeat page"),
                        Checkbox(
                          value: repeatPage,
                          onChanged: (value) =>
                              setState(() => repeatPage = value!),
                        ),
                      ]),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, (
                            reverse: reverse,
                            fullscreen: fullscreen,
                            repeatPage: repeatPage,
                            time: time,
                          )),
                      child: const Text("Accept")),
                ],
              ),
            );
          },
        ).then(
          (final value) {
            if (value == null) return;
            isFullscreen = value.fullscreen;
            final delta = value.reverse ? -1 : 1;
            onFinished = () {
              var newIndex = _currentPostPageIndex + delta;

              /// TODO: Still has problems
              if (value.repeatPage) {
                final last = widget.postsObj.getPageLastVisiblePostIndex(
                        widget.postsObj.currentPageIndex),
                    first = widget.postsObj.getPageFirstVisiblePostIndex(
                        widget.postsObj.currentPageIndex);
                newIndex = switch (newIndex) {
                  int n when n > last => first,
                  int n when n < first => last,
                  _ => newIndex,
                };
                assert(
                  newIndex <= last && newIndex >= first,
                  "newIndex out of bounds"
                  "\n\tnewIndex: $newIndex"
                  "\n\tfirst: $first"
                  "\n\tlast: $last",
                );
              }
              _updateCurrentPageIndex(newIndex);
            };
            loopy = looper(Duration(seconds: value.time.toInt()));
          },
        );
      },
    );
  }

  /// Called when the slideshow timer runs out (i.e. when [loopy] completes).
  /// Setting to `null` will end the loop when the timer runs out next.
  VoidCallback? onFinished;
  Future<void>? loopy;
  Future<void> looper(Duration duration) => Future.delayed(duration,
      () => loopy = (onFinished?..call()) == null ? null : looper(duration));

  void stopSlideshow() {
    loopy?.ignore();
    onFinished = loopy = null;
  }
  // #endregion Slideshow

  void _handlePageViewChanged(int currentPageIndex) {
    logger.info(
        "PageView changed from $_currentPostPageIndex to $currentPageIndex");
    widget.postsObj.currentPostIndex = currentPageIndex +
        widget.postsObj.currentPageIndex * widget.postsObj.postsPerPage;
    _currentPostPageIndex = currentPageIndex;
    currentPostPageIndexNotifier?.value = currentPageIndex;
  }

  void _updateCurrentPageIndex(int newPageViewIndex) {
    (_currentPostPageIndex - newPageViewIndex).abs() > 1
        ? _pageViewController.jumpToPage(newPageViewIndex)
        : _pageViewController
            .animateToPage(
              newPageViewIndex,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            )
            .ignore();
  }

  void _updateCurrentPageIndexWrapper(int newIndex, int old) =>
      _updateCurrentPageIndex(newIndex);
}
