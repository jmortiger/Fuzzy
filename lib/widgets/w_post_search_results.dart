// import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/widgets/w_image_result.dart';

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
  const WPostSearchResults({
    super.key,
    required this.posts,
    this.expectedCount = 50,
    this.searchText = "",
  });

  @override
  State<WPostSearchResults> createState() => _WPostSearchResultsState();
}

class _WPostSearchResultsState extends State<WPostSearchResults> {
  Set<int> restrictedIndices = {};
  Set<int> selectedIndices = {};
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TODO: FIX THIS
        if (widget.posts.restrictedIndices.isNotEmpty)
          Text("${widget.posts.restrictedIndices.length} hidden by global"
              " blacklist."
              " https://e621.net/help/global_blacklist"),
        Expanded(child: _makeGridView(widget.posts)),
      ],
    );
  }

  void doTheThing() {
    print("Should Work");
    setState(() {
      print("Is Working");
      rIDirty = false;
    });
  }

  bool rIDirty = false;
  @widgetFactory
  GridView _makeGridView(E6Posts posts) {
    if (rIDirty) {
      doTheThing();
      setState(() {
        rIDirty = false;
        // restrictedIndices = restrictedIndices;
      });
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: widget.posts.runtimeType == E6PostsSync
          ? widget.posts.count
          : widget.expectedCount,
      itemBuilder: (context, index) {
        var prior = posts.count,
            data = posts.tryGet(index /* , checkForValidFileUrl: false */);
        if (prior != posts.count) {
          rIDirty = true;
        }
        print("i: $index, url = ${data?.file.url}");
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
                }),
              );
        /* index += restrictedIndices.where((element) => element < index).length;
        E6PostResponse? data;
        do {
          data = posts.tryGet(index, checkForValidFileUrl: false);
          if (data?.file.url == "") {
            restrictedIndices.add(index++);
            rIDirty = true;
          }
        } while (data?.file.url == "");
        print("i: $index, url = ${data?.file.url}");
        return (data == null)
            ? null
            : WImageResult(
                imageListing: data,
                index: index,
                searchText: widget.searchText,
              ); */
      },
    );
  }
}
