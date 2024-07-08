import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';

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

/// Page indicator for desktop and web platforms.
///
/// On Desktop and Web, drag gesture for horizontal scrolling in a PageView is disabled by default.
/// You can defined a custom scroll behavior to activate drag gestures,
/// see https://docs.flutter.dev/release/breaking-changes/default-scroll-behavior-drag.
///
/// In this sample, we use a TabPageSelector to navigate between pages,
/// in order to build natural behavior similar to other desktop applications.
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.tabController,
    required this.currentPageIndex,
    required this.onUpdateCurrentPageIndex,
  });

  final int currentPageIndex;
  final TabController tabController;
  final void Function(int) onUpdateCurrentPageIndex;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isDesktop) {
      return const SizedBox.shrink();
    }
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            splashRadius: 16.0,
            padding: EdgeInsets.zero,
            onPressed: () {
              if (currentPageIndex == 0) {
                return;
              }
              onUpdateCurrentPageIndex(currentPageIndex - 1);
            },
            icon: const Icon(
              Icons.arrow_left_rounded,
              size: 32.0,
            ),
          ),
          TabPageSelector(
            controller: tabController,
            color: colorScheme.surface,
            selectedColor: colorScheme.primary,
          ),
          IconButton(
            splashRadius: 16.0,
            padding: EdgeInsets.zero,
            onPressed: () {
              if (currentPageIndex == tabController.length - 1) {
                return;
              }
              onUpdateCurrentPageIndex(currentPageIndex + 1);
            },
            icon: const Icon(
              Icons.arrow_right_rounded,
              size: 32.0,
            ),
          ),
        ],
      ),
    );
  }
}
