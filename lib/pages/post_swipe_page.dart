import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/log_management.dart' as lm;
// import 'package:fuzzy/models/search_results.dart' as srn_lib;

import '../widgets/w_page_indicator.dart';

class PostSwipePage extends StatefulWidget
    implements /* 
  void sortBySecondaryComparator() {
    if (secondaryComparator != null) {
      for (final e in queue) {
        e.sort(secondaryComparator);
      }
    }
  } */
        IRoute<PostSwipePage> {
  static const routeNameString = "/";

  final bool startFullscreen;
  @override
  get routeName => routeNameString;
  final int initialIndex;
  final E6Posts? postsObj;
  final Iterable<E6PostResponse>? postsIterable;
  Iterable<E6PostResponse> get posts => postsObj?.posts ?? postsIterable!;
  final void Function(String addition)? onAddToSearch;
  // @override
  // final List<String>? tagsToAdd;
  // final srn_lib.SearchResultsNotifier? selectedPosts;
  final List<E6PostResponse>? selectedPosts;

  const PostSwipePage.postsCollection({
    super.key,
    required this.initialIndex,
    required Iterable<E6PostResponse> posts,
    this.onAddToSearch,
    // this.tagsToAdd,
    this.startFullscreen = false,
    this.selectedPosts,
  })  : postsObj = null,
        postsIterable = posts;
  const PostSwipePage({
    super.key,
    required this.initialIndex,
    required E6Posts posts,
    this.onAddToSearch,
    // this.tagsToAdd,
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
    // widget.tagsToAdd?.add(s);
    tagsToAddToSearch.add(s);
  }

  final tagsToAddToSearch = <String>[];
  void onPop() => Navigator.pop(context, (
        tagsToAddToSearch: tagsToAddToSearch,
        postsSelected: widget.selectedPosts,
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

class PostSwipePageManaged extends StatefulWidget
    implements /* IReturnsTags,  */ IRoute<PostSwipePageManaged> {
  static const routeNameString = "/";

  final bool startFullscreen;
  @override
  get routeName => routeNameString;
  final int initialIndex;
  final int initialPageIndex;
  final ManagedPostCollectionSync postsObj;
  Iterable<E6PostResponse> get posts => postsObj.posts!.posts;
  Iterable<E6PostEntrySync> get postCache => postsObj.collection.posts;
  final void Function(String addition)? onAddToSearch;
  // @override
  // final List<String>? tagsToAdd;
  final List<E6PostResponse>? selectedPosts;

  const PostSwipePageManaged({
    super.key,
    required this.initialIndex,
    required this.initialPageIndex,
    required ManagedPostCollectionSync posts,
    this.onAddToSearch,
    // this.tagsToAdd,
    this.startFullscreen = false,
    required this.selectedPosts,
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
  // late TabController _tabController;
  // TabController? get tabController =>
  //     Platform.isDesktop ? _tabController : null;
  late int _currentPostPageIndex;
  late ValueNotifier<int> currentPostPageIndexNotifier;
  // late int _currentResultsPageIndex;
  String toReturn = "";
  bool isFullscreen = false;
  late final List<ActionButton> _extras;
  List<ActionButton> get extras =>
      (loopy ?? onFinished) != null ? [cancel] : _extras;
  late final ActionButton cancel;
  final tagsToAddToSearch = <String>[];
  @override
  void initState() {
    super.initState();
    isFullscreen = widget.startFullscreen;
    _pageViewController = PageController(
      initialPage: widget.initialIndex,
      keepPage: false,
    );
    currentPostPageIndexNotifier = ValueNotifier<int>(widget.initialIndex);
    _currentPostPageIndex = widget.initialIndex;
    // _currentResultsPageIndex = widget.initialPageIndex;
    // if (Platform.isDesktop) {
    //   _tabController = TabController(
    //     initialIndex: widget.initialIndex,
    //     length: widget.postsObj.collection.length,
    //     vsync: this,
    //   );
    // }
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
    _pageViewController.dispose();
    // tabController?.dispose();
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
                value: currentPostPageIndexNotifier,
                builder: (context, currentPostPageIndex, child) {
                  return IndeterminatePageIndicator.builder(
                    determineNextPage: (currentPageIndex) =>
                        // (currentPageIndex == _tabController.length - 1)
                        (currentPageIndex >= widget.postsObj.numStoredPosts - 1)
                            ? null
                            : currentPageIndex + 1,
                    currentPageIndex: currentPostPageIndex,
                    // currentPageIndex: _tabController.index,//_currentPostPageIndex,
                    onUpdateCurrentPageIndex: _updateCurrentPageIndexWrapper,
                    pageIndicatorBuilder: (cxt, currentPageIndex) =>
                        IgnorePointer(
                            child:
                                Text("tabController.index: $currentPageIndex")),
                  );
                },
                selector: (context, value) => value.value,
              ),
            ],
          );
  }

  /// Presumes [index] is the overall index, not the index on current page
  Widget? _pageBuilder(BuildContext context, int index) {
    final page = widget.postsObj.getPageOfGivenPostIndexOnPage(index);
    logger.info("_pageBuilder called: Index: $index PageIndex: $page ");
    var ps = ValueAsync(value: widget.postsObj.getPostsOnPageAsObj(page)),
        t = widget.postsObj.getPostsOnPageAsObjSync(page);
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
      final p =
          t!.elementAtOrNull(widget.postsObj.getPostIndexOnPage(index, page));
      return p != null
          ? PostViewPage.overrideFullscreen(
              postListing: p,
              onAddToSearch: onAddToSearch,
              onPop: onPop,
              getFullscreen: () => isFullscreen,
              setFullscreen: (v) => setState(() {
                isFullscreen = v;
              }),
              extraActions: extras,
              selectedPosts: widget.selectedPosts,
            )
          : null;
    }
  }

  void onAddToSearch(String s) {
    toReturn = "$toReturn $s";
    // widget.tagsToAdd?.add(s);
    tagsToAddToSearch.add(s);
  }

  void onPop() {
    Navigator.pop(context, (
      tagsToAddToSearch: tagsToAddToSearch,
      selectedPosts: widget.selectedPosts,
    ));
  }

  // #region Slideshow
  ActionButton makeSlideshow(BuildContext context) {
    return ActionButton(
      icon: const Icon(Icons.timelapse),
      tooltip: "Slideshow",
      onPressed: () {
        showDialog<
            ({
              bool backwards,
              double duration,
              bool fullscreen,
              bool repeatPage
            })>(
          context: context,
          builder: (context) {
            double duration = 5;
            var backwards = false, fullscreen = false, repeatPage = false;
            return StatefulBuilder(
              builder: (BuildContext context, setState) {
                return AlertDialog(
                  title: const Text("Slideshow"),
                  content: SizedBox.expand(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Slider(
                              label: "$duration sec.",
                              onChanged: (value) =>
                                  setState(() => duration = value),
                              value: duration,
                              divisions: 29,
                              min: 1,
                              max: 30,
                            ),
                            Text("$duration sec."),
                          ],
                        ),
                        Row(
                          children: [
                            const Text("Backwards"),
                            Checkbox(
                              value: backwards,
                              onChanged: (value) =>
                                  setState(() => backwards = value!),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text("Fullscreen"),
                            Checkbox(
                              value: fullscreen,
                              onChanged: (value) =>
                                  setState(() => fullscreen = value!),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text("Repeat page"),
                            Checkbox(
                              value: repeatPage,
                              onChanged: (value) =>
                                  setState(() => repeatPage = value!),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () => Navigator.pop(context, (
                              backwards: backwards,
                              fullscreen: fullscreen,
                              repeatPage: repeatPage,
                              duration: duration,
                            )),
                        child: const Text("Accept")),
                  ],
                );
              },
            );
          },
        ).then(
          (value) {
            // const safetyBounds = 5;
            if (value == null) return;
            isFullscreen = value.fullscreen;
            final delta = value.backwards ? -1 : 1;
            onFinished = () {
              final last = widget.postsObj.getPageLastPostIndex(widget.postsObj
                      .currentPageIndex /* _currentResultsPageIndex */),
                  first = widget.postsObj.getPageFirstPostIndex(widget.postsObj
                      .currentPageIndex /* _currentResultsPageIndex */);
              var newIndex = _currentPostPageIndex + delta;
              if (value.repeatPage) {
                // int safety = 0;
                // while ((newIndex > last || newIndex < first) &&
                //     safety < safetyBounds) {
                //   newIndex = switch (newIndex) {
                //     int n when n > last =>
                //       newIndex - widget.postsObj.postsPerPage,
                //     int n when n < first =>
                //       newIndex + widget.postsObj.postsPerPage,
                //     _ => newIndex,
                //   };
                // }
                // if (safety >= safetyBounds) {
                //   logger.warning("Something's wrong in onFinished");
                // }
                newIndex = switch (newIndex) {
                  int n when n > last => first,
                  int n when n < first => last,
                  _ => newIndex,
                };
                assert(newIndex > last || newIndex < first);
              }
              _updateCurrentPageIndex(newIndex);
            };
            loopy = looper(Duration(seconds: value.duration.toInt()));
          },
        );
      },
    );
  }

  VoidCallback? onFinished;
  Future<void>? loopy;
  Future<void> looper(Duration duration) => Future.delayed(duration, () {
        onFinished?.call();
        return loopy = onFinished == null ? null : looper(duration);
      });

  void stopSlideshow() {
    loopy?.ignore();
    loopy = null;
    onFinished = null;
  }
  // #endregion Slideshow

  void _handlePageViewChanged(int currentPageIndex) {
    logger.info(
      "PageView changed from $_currentPostPageIndex to $currentPageIndex",
    );
    widget.postsObj.currentPostIndex = currentPageIndex +
        widget.postsObj.currentPageIndex * widget.postsObj.postsPerPage;
    // widget.postsObj.currentPostIndex = currentPageIndex +
    //     _currentResultsPageIndex * widget.postsObj.postsPerPage;
    // widget.postsObj.currentPostIndex =
    //     currentPageIndex + widget.initialPageIndex * SearchView.i.postsPerPage;
    // _currentResultsPageIndex = widget.postsObj.currentPageIndex;
    // if (!Platform.isDesktop) {
    //   return;
    // }
    // tabController?.index = currentPageIndex;
    // setState(() {
    _currentPostPageIndex = currentPageIndex;
    // });
    currentPostPageIndexNotifier.value = currentPageIndex;
  }

  void _updateCurrentPageIndex(int newPageViewIndex) {
    // _tabController.index = newPageViewIndex;
    _pageViewController.animateToPage(
      newPageViewIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _updateCurrentPageIndexWrapper(int newIndex, int old) =>
      _updateCurrentPageIndex(newIndex);
}
