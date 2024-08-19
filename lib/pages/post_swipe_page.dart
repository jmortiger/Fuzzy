import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/log_management.dart' as lm;
// import 'package:fuzzy/models/search_results.dart' as srn_lib;

import '../widgets/w_page_indicator.dart';

class PostSwipePage extends StatefulWidget
    implements IReturnsTags, IRoute<PostSwipePage> {
  static const routeNameString = "/";

  final bool startFullscreen;
  @override
  get routeName => routeNameString;
  final int initialIndex;
  final E6Posts? postsObj;
  final Iterable<E6PostResponse>? postsIterable;
  Iterable<E6PostResponse> get posts => postsObj?.posts ?? postsIterable!;
  final void Function(String addition)? onAddToSearch;
  @override
  final List<String>? tagsToAdd;
  // final srn_lib.SearchResultsNotifier? selectedPosts;

  const PostSwipePage.postsCollection({
    super.key,
    required this.initialIndex,
    required Iterable<E6PostResponse> posts,
    this.onAddToSearch,
    this.tagsToAdd,
    this.startFullscreen = false,
    // this.selectedPosts,
  })  : postsObj = null,
        postsIterable = posts;
  const PostSwipePage({
    super.key,
    required this.initialIndex,
    required E6Posts posts,
    this.onAddToSearch,
    this.tagsToAdd,
    this.startFullscreen = false,
    // this.selectedPosts,
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
    if (!Platform.isDesktop) {
      return PageView(
        // scrollBehavior: MyScrollBehavior(),

        /// [PageView.scrollDirection] defaults to [Axis.horizontal].
        /// Use [Axis.vertical] to scroll vertically.
        controller: _pageViewController,
        allowImplicitScrolling: true,
        // onPageChanged: _handlePageViewChanged,
        children: widget.posts.mapAsList(
          (elem, index, list) => PostViewPage.overrideFullscreen(
            postListing: elem,
            onAddToSearch: (s) {
              widget.onAddToSearch?.call(s);
              toReturn = "$toReturn $s";
              widget.tagsToAdd?.add(s);
            },
            getFullscreen: () => isFullscreen,
            setFullscreen: (v) => setState(() {
              isFullscreen = v;
            }),
            // selectedPosts: widget.selectedPosts,
          ),
        ),
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        PageView(
          // scrollBehavior: MyScrollBehavior(),

          /// [PageView.scrollDirection] defaults to [Axis.horizontal].
          /// Use [Axis.vertical] to scroll vertically.
          controller: _pageViewController,
          onPageChanged: _handlePageViewChanged,
          allowImplicitScrolling: true,
          children: widget.posts.mapAsList(
            (elem, index, list) => PostViewPage.overrideFullscreen(
              postListing: elem,
              onAddToSearch: (s) {
                widget.onAddToSearch?.call(s);
                toReturn = "$toReturn $s";
                widget.tagsToAdd?.add(s);
              },
              onPop: () => Navigator.pop(context, widget),
              getFullscreen: () => isFullscreen,
              setFullscreen: (v) => setState(() {
                isFullscreen = v;
              }),
            ),
          ),
        ),
        PageIndicator(
          tabController: _tabController,
          currentPageIndex: _currentPageIndex,
          onUpdateCurrentPageIndex: _updateCurrentPageIndex,
        ),
      ],
    );
  }

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
    implements IReturnsTags, IRoute<PostSwipePageManaged> {
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
  @override
  final List<String>? tagsToAdd;
  // final srn_lib.SearchResultsNotifier? selectedPosts;

  // const PostSwipePageManaged.postsCollection({
  //   super.key,
  //   required this.initialIndex,
  //   required this.initialPageIndex,
  //   required Iterable<E6PostEntry> posts,
  //   this.onAddToSearch,
  //   this.tagsToAdd,
  //   this.startFullscreen = false,
  // })  : postsObj = null,
  //       postsIterable = posts;
  const PostSwipePageManaged({
    super.key,
    required this.initialIndex,
    required this.initialPageIndex,
    required ManagedPostCollectionSync posts,
    this.onAddToSearch,
    this.tagsToAdd,
    this.startFullscreen = false,
    // required this.selectedPosts,
  }) : postsObj = posts;

  @override
  State<PostSwipePageManaged> createState() => _PostSwipePageManagedState();
}

/// TODO: Use PointerDeviceKind (through Listener/MouseRegion?) instead of Platform to enable mouse controls
class _PostSwipePageManagedState extends State<PostSwipePageManaged>
    with TickerProviderStateMixin {
  // #region Logger
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("PostSwipePageManagedState");
  // #endregion Logger
  late PageController _pageViewController;
  late TabController _tabController;
  late int _currentPostPageIndex;
  late int _currentResultsPageIndex;
  String toReturn = "";
  bool isFullscreen = false;
  late final List<ActionButton> _extras;
  List<ActionButton> get extras =>
      (loopy ?? onFinished) != null ? [cancel] : _extras;
  late final ActionButton cancel;
  @override
  void initState() {
    super.initState();
    isFullscreen = widget.startFullscreen;
    _pageViewController = PageController(
      initialPage: widget.initialIndex,
      keepPage: false,
    );
    _currentPostPageIndex = widget.initialIndex;
    _currentResultsPageIndex = widget.initialPageIndex;
    if (Platform.isDesktop) {
      _tabController = TabController(
        initialIndex: widget.initialIndex,
        length: widget.postsObj.collection.length,
        vsync: this,
      );
    }
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
    super.dispose();
    stopSlideshow();
    _pageViewController.dispose();
    if (Platform.isDesktop) {
      _tabController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final root = PageView.builder(
      // scrollBehavior: MyScrollBehavior(),

      /// [PageView.scrollDirection] defaults to [Axis.horizontal].
      /// Use [Axis.vertical] to scroll vertically.
      controller: _pageViewController,
      allowImplicitScrolling: true,
      onPageChanged: _handlePageViewChanged,
      itemBuilder: (context, index) => ErrorPage.errorCatcher<Widget?>(
        () => _pageBuilder(context, index),
        context: context,
        logger: logger,
      ),
    );
    if (!Platform.isDesktop) {
      return root;
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        root,
        if (Platform.isDesktop)
          // ConstrainedBox(
          //   constraints: BoxConstraints(
          //     minHeight: 32,
          //     maxHeight: 64,
          //     maxWidth: MediaQuery.sizeOf(context).width,
          //   ),
          //   child: PageIndicator(
          //     tabController: _tabController,
          //     currentPageIndex: _currentPostPageIndex,
          //     onUpdateCurrentPageIndex: _updateCurrentPageIndex,
          //   ),
          // ),
          IndeterminatePageIndicator.builder(
            determineNextPage: (currentPageIndex) =>
                (currentPageIndex == _tabController.length - 1)
                    ? null
                    : currentPageIndex + 1,
            // tabController: _tabController,
            currentPageIndex: _currentPostPageIndex,
            // onUpdateCurrentPageIndex: _updateCurrentPageIndex,
            onUpdateCurrentPageIndex: _updateCurrentPageIndexWrapper,
            pageIndicatorBuilder: (cxt, currentPageIndex) => IgnorePointer(
                child: Text("tabController.index: $currentPageIndex")),
          ),
      ],
    );
  }

  Widget? _pageBuilder(BuildContext context, int index) {
    // final page = widget.postsObj.currentPage;
    final page = widget.postsObj.getPageOfGivenPostIndexOnPage(index);
    // var ps = widget.postsObj[page], t = ps.$Safe;
    var ps = ValueAsync(value: widget.postsObj.getPostsOnPageAsObj(page)),
        t = widget.postsObj.getPostsOnPageAsObjSync(page);
    if (ps.isComplete && t == null) {
      return null;
    } else if (!ps.isComplete) {
      return FutureBuilder(
        future: ps.future,
        builder: (context, snapshot) {
          logger.info(
              "Index: $index snapshot complete ${snapshot.hasData || snapshot.hasError} ${snapshot.data}");
          if (snapshot.hasData) {
            if (snapshot.data != null) {
              return PostViewPage.overrideFullscreen(
                postListing: snapshot
                    .data![widget.postsObj.getPostIndexOnPage(index, page)],
                // snapshot.data![widget.postsObj.currentPostIndex],
                onAddToSearch: (s) {
                  widget.onAddToSearch?.call(s);
                  toReturn = "$toReturn $s";
                  widget.tagsToAdd?.add(s);
                },
                onPop: () => Navigator.pop(context, widget),
                getFullscreen: () => isFullscreen,
                setFullscreen: (v) => setState(() {
                  isFullscreen = v;
                }),
                extraActions: extras,
                // selectedPosts: widget.selectedPosts,
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
      final p =
          t!.elementAtOrNull(widget.postsObj.getPostIndexOnPage(index, page));
      return p != null
          ? PostViewPage.overrideFullscreen(
              // postListing: t![widget.postsObj.currentPostIndex],
              postListing: p,
              onAddToSearch: (s) {
                widget.onAddToSearch?.call(s);
                toReturn = "$toReturn $s";
                widget.tagsToAdd?.add(s);
              },
              onPop: () => Navigator.pop(context, widget),
              getFullscreen: () => isFullscreen,
              setFullscreen: (v) => setState(() {
                isFullscreen = v;
              }),
              extraActions: extras,
              // selectedPosts: widget.selectedPosts,
            )
          : null;
    }
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
                        Slider(
                          label: duration.toString(),
                          onChanged: (value) =>
                              setState(() => duration = value),
                          value: duration,
                          divisions: 29,
                          min: 1,
                          max: 30,
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
            if (value == null) return;
            isFullscreen = value.fullscreen;
            final delta = value.backwards ? -1 : 1;
            onFinished = () {
              // TODO: Bounds checking
              final last = widget.postsObj
                      .getPageLastPostIndex(_currentPostPageIndex),
                  first = widget.postsObj
                      .getPageFirstPostIndex(_currentPostPageIndex);
              var newIndex = _currentPostPageIndex + delta;
              if (value.repeatPage) {
                int safety = 0;
                while ((newIndex > last || newIndex < first) && safety < 5) {
                  newIndex = switch (newIndex) {
                    int n when n > last =>
                      newIndex - widget.postsObj.postsPerPage,
                    int n when n < first =>
                      newIndex + widget.postsObj.postsPerPage,
                    _ => newIndex,
                  };
                }
                if (safety >= 5) {
                  logger.warning("Something's wrong in onFinished");
                }
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

  void _handlePageViewChanged(int currentPageIndex) {
    logger.info(
      "PageView changed from $_currentPostPageIndex to $currentPageIndex",
    );
    widget.postsObj.currentPostIndex =
        currentPageIndex + widget.initialPageIndex * SearchView.i.postsPerPage;
    if (!Platform.isDesktop) {
      return;
    }
    _tabController.index = currentPageIndex;
    setState(() {
      _currentPostPageIndex = currentPageIndex;
    });
  }

  void stopSlideshow() {
    loopy?.ignore();
    loopy = null;
    onFinished = null;
  }
  // #endregion Slideshow

  void _updateCurrentPageIndex(int newPageViewIndex) {
    _tabController.index = newPageViewIndex;
    _pageViewController.animateToPage(
      newPageViewIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _updateCurrentPageIndexWrapper(int newIndex, int old) =>
      _updateCurrentPageIndex(newIndex);
}
