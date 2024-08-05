import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/log_management.dart' as lm;

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

  const PostSwipePage.postsCollection({
    super.key,
    required this.initialIndex,
    required Iterable<E6PostResponse> posts,
    this.onAddToSearch,
    this.tagsToAdd,
    this.startFullscreen = false,
  })  : postsObj = null,
        postsIterable = posts;
  const PostSwipePage({
    super.key,
    required this.initialIndex,
    required E6Posts posts,
    this.onAddToSearch,
    this.tagsToAdd,
    this.startFullscreen = false,
  })  : postsObj = posts,
        postsIterable = null;

  @override
  State<PostSwipePage> createState() => _PostSwipePageState();
}

/// TODO: Use PointerDeviceKind (through Listener/MouseRegion?) instead of Platform to enable mouse controls
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
  }) : postsObj = posts;

  @override
  State<PostSwipePageManaged> createState() => _PostSwipePageManagedState();
}

/// TODO: Use PointerDeviceKind (through Listener/MouseRegion?) instead of Platform to enable mouse controls
class _PostSwipePageManagedState extends State<PostSwipePageManaged>
    with TickerProviderStateMixin {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.genLogger("_PostSwipePageManagedState");
  // #endregion Logger
  late PageController _pageViewController;
  late TabController _tabController;
  late int _currentPostPageIndex;
  // late int _currentPageIndex;
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
    _currentPostPageIndex = widget.initialIndex; //widget.initialPageIndex;
    if (Platform.isDesktop) {
      _tabController = TabController(
        initialIndex: widget.initialIndex, // % SearchView.i.postsPerPage,
        length: widget.postsObj.collection.length,
        vsync: this,
      );
    }
    // _currentPageIndex = widget.initialPageIndex;
    widget.postsObj.currentPostIndex = widget.initialIndex;
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
    final root = PageView.builder(
      // scrollBehavior: MyScrollBehavior(),

      /// [PageView.scrollDirection] defaults to [Axis.horizontal].
      /// Use [Axis.vertical] to scroll vertically.
      controller: _pageViewController,
      allowImplicitScrolling: true,
      onPageChanged: _handlePageViewChanged,
      itemBuilder: (context, index) {
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
          return PostViewPage.overrideFullscreen(
            // postListing: t![widget.postsObj.currentPostIndex],
            postListing: t![widget.postsObj.getPostIndexOnPage(index, page)],
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
          );
        }
      },
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
            tabController: _tabController,
            currentPageIndex: _currentPostPageIndex,
            // onUpdateCurrentPageIndex: _updateCurrentPageIndex,
            onUpdateCurrentPageIndex: _updateCurrentPageIndexWrapper,
            pageIndicatorBuilder: (cxt, currentPageIndex) =>
                Text("tabController.index: $currentPageIndex"),
          ),
      ],
    );
  }

  void _handlePageViewChanged(int currentPageIndex) {
    logger.info(
        "PageView changed from $_currentPostPageIndex to $currentPageIndex");
    // widget.postsObj.currentPostIndex =
    //     currentPageIndex + widget.initialPageIndex * SearchView.i.postsPerPage;
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
