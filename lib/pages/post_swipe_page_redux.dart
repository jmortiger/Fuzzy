import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:j_util/j_util_full.dart';

final class PostLle extends LinkedListEntry<PostLle> {
  final E6PostResponse post;

  PostLle({required this.post});
}

class PostSwipePage extends StatefulWidget implements IReturnsTags {
  final int initialIndex;
  final int length;
  // final E6PostEntry post;
  final PostCollection posts;
  final void Function(String addition)? onAddToSearch;
  @override
  final List<String>? tagsToAdd;

  const PostSwipePage({
    super.key,
    required this.initialIndex,
    required this.length,
    required this.posts,
    this.onAddToSearch,
    this.tagsToAdd,
  });

  @override
  State<PostSwipePage> createState() => _PostSwipePageState();
}

class CustomPV extends SliverChildDelegate {
  final PostCollection posts;
  final void Function(String addition)? onAddToSearch;
  final List<String>? tagsToAdd;
  CustomPV({
    required this.posts,
    this.onAddToSearch,
    this.tagsToAdd,
  });
  @override
  Widget? build(BuildContext context, int index) {
    var t = posts[index]; //findPostFromIndex(index);
    return t == null
        ? null
        : t.isComplete
            ? PostViewPage(
                postListing: t.$, //post,
                onAddToSearch: (s) {
                  onAddToSearch?.call(s);
                  // toReturn = "$toReturn $s";
                  tagsToAdd?.add(s);
                },
              )
            : FutureBuilder(
                future: t.futureSafe,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return PostViewPage(
                      postListing: snapshot.data!, //post,
                      onAddToSearch: (s) {
                        onAddToSearch?.call(s);
                        // toReturn = "$toReturn $s";
                        tagsToAdd?.add(s);
                      },
                    );
                  } else if (snapshot.hasError) {
                    return ErrorPage(
                      error: snapshot.error,
                      stackTrace: snapshot.stackTrace,
                    );
                  } else {
                    return scSaCoExArCpi;
                  }
                },
              );
  }

  // @override
  // int? get estimatedChildCount => throw UnimplementedError();

  // @override
  // int? findIndexByKey(Key key) {
  //   throw UnimplementedError();
  // }

  @override
  bool shouldRebuild(covariant SliverChildDelegate oldDelegate) =>
      (((oldDelegate as CustomPV?)?.posts.length ?? -1) < posts.length);
}

/// TODO: Use PointerDeviceKind (through Listener/MouseRegion?) instead of Platform to enable mouse controls
class _PostSwipePageState extends State<PostSwipePage>
    with TickerProviderStateMixin {
  late PageController _pageViewController;
  late TabController _tabController;
  late int _currentPageIndex;
  String toReturn = "";
  late E6PostEntry current;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController(
      initialPage: widget.initialIndex,
      keepPage: false,
    );
    current = widget.posts[widget.initialIndex];
    _currentPageIndex = widget.initialIndex;
    if (Platform.isDesktop) {
      _tabController = TabController(
        initialIndex: widget.initialIndex,
        length: widget.length,
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

  E6PostEntry? findPostFromIndex(int index) {
    var delta = _currentPageIndex - index;
    E6PostEntry t = current;
    while (delta > 0) {
      if (t.previous == null) {
        return null;
      }
      t = t.previous!;
      delta--;
    }
    while (delta < 0) {
      if (t.previous == null) {
        return null;
      }
      t = t.next!;
      delta++;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isDesktop) {
      return PageView.custom(
        // scrollBehavior: MyScrollBehavior(),

        /// [PageView.scrollDirection] defaults to [Axis.horizontal].
        /// Use [Axis.vertical] to scroll vertically.
        controller: _pageViewController,
        // onPageChanged: _handlePageViewChanged,
        onPageChanged: (value) {
          current = findPostFromIndex(value)!;
        },
        childrenDelegate: CustomPV(
          posts: widget.posts,
          onAddToSearch: widget.onAddToSearch,
          tagsToAdd: widget.tagsToAdd,
        ),
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        PageView.custom(
          // scrollBehavior: MyScrollBehavior(),

          /// [PageView.scrollDirection] defaults to [Axis.horizontal].
          /// Use [Axis.vertical] to scroll vertically.
          controller: _pageViewController,
          onPageChanged: (value) {
            current = findPostFromIndex(value)!;
            _handlePageViewChanged(value);
          },
          childrenDelegate: CustomPV(
            posts: widget.posts,
            onAddToSearch: widget.onAddToSearch,
            tagsToAdd: widget.tagsToAdd,
          ),
          // itemBuilder: (context, index) {
          //   var t = findPostFromIndex(index);
          //   return t == null
          //       ? null
          //       : t.isComplete
          //           ? PostViewPage(
          //               postListing: t.$, //post,
          //               onAddToSearch: (s) {
          //                 widget.onAddToSearch?.call(s);
          //                 toReturn = "$toReturn $s";
          //                 widget.tagsToAdd?.add(s);
          //               },
          //             )
          //           : FutureBuilder(
          //               future: t.futureSafe,
          //               builder: (context, snapshot) {
          //                 if (snapshot.hasData) {
          //                   return PostViewPage(
          //                     postListing: snapshot.data!, //post,
          //                     onAddToSearch: (s) {
          //                       widget.onAddToSearch?.call(s);
          //                       toReturn = "$toReturn $s";
          //                       widget.tagsToAdd?.add(s);
          //                     },
          //                   );
          //                 } else if (snapshot.hasError) {
          //                   return ErrorPage(
          //                     error: snapshot.error,
          //                     stackTrace: snapshot.stackTrace,
          //                   );
          //                 } else {
          //                   return scSaCoExArCpi;
          //                 }
          //               },
          //             );
          // },
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
              if (currentPageIndex == 2) {
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

// class MyDelegate extends SliverChildDelegate {
//   @override
//   Widget? build(BuildContext context, int index) {
//     var t = findPostFromIndex(index);
//     return t == null
//         ? null
//         : PostViewPage(
//             postListing: t.post,
//             onAddToSearch: (s) {
//               widget.onAddToSearch?.call(s);
//               toReturn = "$toReturn $s";
//               widget.tagsToAdd?.add(s);
//             },
//           );
//   }

//   @override
//   bool shouldRebuild(covariant MyDelegate oldDelegate) {
//     // TODO: implement shouldRebuild
//     throw UnimplementedError();
//   }
// }
