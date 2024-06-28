// import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:j_util/j_util_full.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class WPostSearchResults extends StatefulWidget {
  final E6Posts posts;
  final int expectedCount;
  final void Function(Set<int> indices, int newest)? onPostsSelected;

  final JPureEvent? _onSelectionCleared;
  final bool useLazyBuilding;

  final bool disallowSelections;
  const WPostSearchResults({
    super.key,
    required this.posts,
    this.expectedCount = 50,
    this.onPostsSelected,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    JPureEvent? onSelectionCleared,
  }) : _onSelectionCleared = onSelectionCleared;

  @override
  State<WPostSearchResults> createState() => _WPostSearchResultsState();
}

class _WPostSearchResultsState extends State<WPostSearchResults> {
  Set<int> restrictedIndices = {};
  Set<int> selectedIndices = {};
  int? trueCount;

  E6PostsSync? get postSync => (widget.posts.runtimeType == E6PostsSync)
      ? (widget.posts as E6PostsSync)
      : null;
  E6PostsLazy? get postLazy => (widget.posts.runtimeType == E6PostsLazy)
      ? (widget.posts as E6PostsLazy)
      : null;

  @override
  void initState() {
    if (widget.posts.runtimeType == E6PostsSync) {
      trueCount = postSync!.posts.length;
    }
    widget._onSelectionCleared?.subscribe(() {
      if (mounted) {
        setState(() {
          selectedIndices.clear();
        });
      } else {
        print("_WPostSearchResultsState: Dismounted?");
      }
    });
    if (widget.posts.runtimeType == E6PostsLazy) {
      postLazy!.onFullyIterated.subscribe(
            (FullyIteratedArgs posts) => setState(() {
              trueCount = posts.posts.length;
            }),
          );
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TODO: Make this work lazy
        if (widget.posts.restrictedIndices.isNotEmpty)
          Linkify(
            onOpen: (link) async {
              if (!await launchUrl(Uri.parse(link.url))) {
                throw Exception('Could not launch ${link.url}');
              }
            },
            text: "${widget.posts.restrictedIndices.length} hidden by global"
            " blacklist. https://e621.net/help/global_blacklist",
            // style: TextStyle(color: Colors.yellow),
            linkStyle: const TextStyle(color: Colors.yellow),
          ),
        // if (widget.posts.restrictedIndices.isNotEmpty)
        //   Text(
        //     "${widget.posts.restrictedIndices.length} hidden by global"
        //     " blacklist. https://e621.net/help/global_blacklist",
        //   ),
        Expanded(child: _makeGridView(widget.posts)),
      ],
    );
  }

  @widgetFactory
  GridView _makeGridView(E6Posts posts) {
    return widget.useLazyBuilding
        ? GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppSettings.i!.searchView.postsPerRow,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: widget.posts.runtimeType == E6PostsSync
                ? widget.posts.count
                : trueCount ?? widget.expectedCount,
            itemBuilder: (context, index) {
              if (trueCount == null && widget.expectedCount - 1 == index) {
                posts.tryGet(index + 3);
              }
              var data = posts.tryGet(index);
              return (data == null)
                  ? null
                  : WImageResult(
                      disallowSelections: widget.disallowSelections,
                      imageListing: data,
                      index: index,
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
            crossAxisCount: AppSettings.i!.searchView.postsPerRow,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children:
                (Iterable<int>.generate(widget.expectedCount)).reduceUntilTrue(
                    (accumulator, _, index, __) => posts.tryGet(index) != null
                        ? (
                            accumulator
                              ..add(WImageResult(
                                disallowSelections: widget.disallowSelections,
                                imageListing: posts.tryGet(index)!,
                                index: index,
                                isSelected: selectedIndices.contains(index),
                                onSelectionToggle: (i) => setState(() {
                                  selectedIndices.contains(i)
                                      ? selectedIndices.remove(i)
                                      : selectedIndices.add(i);
                                  widget.onPostsSelected
                                      ?.call(selectedIndices, i);
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
