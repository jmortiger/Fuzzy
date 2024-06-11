// import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:j_util/j_util_full.dart';

// class WPostSearchResultsStateless extends StatelessWidget {
//   final E6Posts posts;
//   const WPostSearchResultsStateless({
//     super.key,
//     required this.posts,
//   });
//   @override
//   Widget build(BuildContext context) => _makeGridView(posts);
//
//   GridView _makeGridView(E6Posts posts) => GridView.builder(
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 3,
//           crossAxisSpacing: 4,
//           mainAxisSpacing: 4,
//         ),
//         itemBuilder: (context, index) {
//           var data = posts.tryGet(index);
//           return (data == null) ? null : WImageResult(imageListing: data, searchText: widget.searchText,);
//         },
//       );
// }

class WPostSearchResults extends StatefulWidget {
  final E6Posts posts;
  final int expectedCount;
  final String searchText;
  final void Function(Set<int> indices, int newest)? onPostsSelected;

  final JPureEvent? _onSelectionCleared;
  final bool useLazyBuilding;
  const WPostSearchResults({
    super.key,
    required this.posts,
    this.expectedCount = 50,
    this.searchText = "",
    this.onPostsSelected,
    this.useLazyBuilding = true,
    JPureEvent? onSelectionCleared,
  }) : _onSelectionCleared = onSelectionCleared;

  @override
  State<WPostSearchResults> createState() => _WPostSearchResultsState();
}

class _WPostSearchResultsState extends State<WPostSearchResults> {
  Set<int> restrictedIndices = {};
  Set<int> selectedIndices = {};

  @override
  void initState() {
    widget._onSelectionCleared?.subscribe(() => selectedIndices.clear());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TODO: Make this work lazy
        if (widget.posts.restrictedIndices.isNotEmpty)
          Text("${widget.posts.restrictedIndices.length} hidden by global"
              " blacklist."
              " https://e621.net/help/global_blacklist"),
        Expanded(child: _makeGridView(widget.posts)),
      ],
    );
  }

  @widgetFactory
  GridView _makeGridView(E6Posts posts) {
    return widget.useLazyBuilding && posts.runtimeType == E6PostsSync
        ? GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: widget.posts.runtimeType == E6PostsSync
                ? widget.posts.count
                : widget.expectedCount,
            itemBuilder: (context, index) {
              var data = posts.tryGet(index);
              // print("i: $index, url = ${data?.file.url}");
              return (data == null)
                  ? null
                  : WImageResult(
                      imageListing: data,
                      index: index,
                      searchText: widget.searchText,
                      isSelected: selectedIndices.contains(index),
                      onSelectionToggle: (i) => setState(() {
                        selectedIndices.contains(i)
                            ? selectedIndices.remove(i)
                            : selectedIndices.add(i);
                        widget.onPostsSelected?.call(selectedIndices, i);
                      }),
                      areAnySelected: selectedIndices.isNotEmpty,
                    );
            },
          )
        : GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children: ((posts as E6PostsSync).posts).reduceUntilTrue(
                (accumulator, _, index, __) => posts.tryGet(index) != null
                    ? (
                        accumulator
                          ..add(WImageResult(
                            imageListing: posts.tryGet(index)!,
                            index: index,
                            searchText: widget.searchText,
                            isSelected: selectedIndices.contains(index),
                            onSelectionToggle: (i) => setState(() {
                              selectedIndices.contains(i)
                                  ? selectedIndices.remove(i)
                                  : selectedIndices.add(i);
                              widget.onPostsSelected?.call(selectedIndices, i);
                            }),
                            areAnySelected: selectedIndices.isNotEmpty,
                          )),
                        false
                      )
                    : (accumulator, true),
                []),
          );
  }
}
