import 'dart:convert' as dc;

import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:j_util/j_util_full.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

late final lRecord = lm.genLogger("WPostSearchResults");
late final print = lRecord.print;
late final logger = lRecord.logger;
// #endregion Logger

class WPostSearchResults extends StatefulWidget {
  final E6Posts posts;
  final int expectedCount;
  final void Function(Set<int> indices, int newest)? onPostsSelected;

  final JPureEvent? _onSelectionCleared;
  final bool useLazyBuilding;

  final bool disallowSelections;

  final bool stripToGridView;

  final JPureEvent? _fireRebuild;
  const WPostSearchResults({
    super.key,
    required this.posts,
    this.expectedCount = 50,
    this.onPostsSelected,
    this.useLazyBuilding = false,
    this.disallowSelections = false,
    JPureEvent? onSelectionCleared,
    this.stripToGridView = false,
    JPureEvent? fireRebuild,
  })  : _onSelectionCleared = onSelectionCleared,
        _fireRebuild = fireRebuild;

  @override
  State<WPostSearchResults> createState() => _WPostSearchResultsState();

  static Widget directResults(List<int> postIds) => FutureBuilder(
        future: (E621
            .performPostSearch(
              tags: postIds.fold(
                "order:id_asc",
                (previousValue, element) => "$previousValue ~id:$element",
              ),
              limit: E621.maxPostsPerSearch,
            )
            .then((v) => E6PostsSync.fromJson(dc.jsonDecode(v.responseBody)))),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            try {
              return WPostSearchResults(
                posts: snapshot.data!,
                disallowSelections: true,
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
  static Widget directResultFromSearch(String tags) => FutureBuilder(
        future: (E621
            .performPostSearch(
              tags: tags,
              limit: E621.maxPostsPerSearch,
            )
            .then((v) => E6PostsSync.fromJson(dc.jsonDecode(v.responseBody)))),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            try {
              return WPostSearchResults(
                posts: snapshot.data!,
                disallowSelections: true,
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
}

class _WPostSearchResultsState extends State<WPostSearchResults> {
  // Set<int> restrictedIndices = {};
  // #region Notifiers
  Set<int> _selectedIndices = {};

  SearchCache get sc => Provider.of<SearchCache>(context, listen: false);
  SearchResultsNotifier get sr =>
      Provider.of<SearchResultsNotifier>(context, listen: false);
  SearchResultsNotifier get srl =>
      Provider.of<SearchResultsNotifier>(context, listen: true);
  Set<int> get selectedIndices =>
      widget.disallowSelections ? _selectedIndices : sr.selectedIndices;

  set selectedIndices(Set<int> value) => widget.disallowSelections
      ? _selectedIndices = value
      : srl.selectedIndices = SetNotifier.from(value);
  bool getIsIndexSelected(int index) => widget.disallowSelections
      ? _selectedIndices.contains(index)
      : sr.getIsSelected(index);
  // #endregion Notifiers

  int? trueCount;

  E6PostsSync? get postSync => (widget.posts.runtimeType == E6PostsSync)
      ? (widget.posts as E6PostsSync)
      : null;
  E6PostsLazy? get postLazy => (widget.posts.runtimeType == E6PostsLazy)
      ? (widget.posts as E6PostsLazy)
      : null;
  // SearchViewModel get svm => Provider.of<SearchViewModel>(context, listen: false);
  void _clearSelectionsCallback() {
    if (mounted) {
      setState(() {
        selectedIndices.clear();
      });
    } else {
      print("_WPostSearchResultsState: Dismounted?");
    }
  }

  void _rebuildCallback() => setState(() {});

  @override
  void initState() {
    if (widget.posts.runtimeType == E6PostsSync) {
      trueCount = postSync!.posts.length;
    }
    widget._onSelectionCleared?.subscribe(_clearSelectionsCallback);
    widget._fireRebuild?.subscribe(_rebuildCallback);
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
  void dispose() {
    widget._onSelectionCleared?.unsubscribe(_clearSelectionsCallback);
    widget._fireRebuild?.unsubscribe(_rebuildCallback);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !widget.stripToGridView
        ? Column(
            children: [
              // TODO: Make this work lazy
              if (widget.posts.restrictedIndices.isNotEmpty)
                Linkify(
                  onOpen: (link) async {
                    if (!await launchUrl(Uri.parse(link.url))) {
                      throw Exception('Could not launch ${link.url}');
                    }
                  },
                  text:
                      "${widget.posts.restrictedIndices.length} hidden by global"
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
          )
        : _makeGridView(widget.posts);
  }

  int get estimatedCount => widget.posts.runtimeType == E6PostsSync
      ? widget.posts.count
      : trueCount ?? widget.expectedCount;
  @widgetFactory
  GridView _makeGridView(E6Posts posts) {
    return widget.useLazyBuilding
        ? GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppSettings.i!.searchView.postsPerRow,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: estimatedCount,
            itemBuilder: (context, index) {
              if (trueCount == null && widget.expectedCount - 1 == index) {
                posts.tryGet(index + 3);
              }
              var data = posts.tryGet(index);
              return (data == null) ? null : constructImageResult(data, index);
            },
          )
        : GridView.count(
            crossAxisCount: AppSettings.i!.searchView.postsPerRow,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children:
                (Iterable<int>.generate(estimatedCount)).reduceUntilTrue(
                    (accumulator, _, index, __) => posts.tryGet(index) != null
                        ? (
                            accumulator
                              ..add(
                                constructImageResult(
                                    posts.tryGet(index)!, index),
                              ),
                            false
                          )
                        : (accumulator, true),
                    []),
          );
  }

  @widgetFactory
  WImageResult constructImageResult(E6PostResponse data, int index) =>
      WImageResult(
        disallowSelections: widget.disallowSelections,
        imageListing: data,
        index: index,
        postsCache: widget.disallowSelections ? widget.posts.posts : null,
        isSelected: getIsIndexSelected(index),
        // onSelectionToggle: (!widget.disallowSelections)
        //     ? (i) => setState(() {
        //           sr.toggleSelection(index: i, postId: data.id);
        //           // selectedIndices.contains(i)
        //           //     ? selectedIndices.remove(i)
        //           //     : selectedIndices.add(i);
        //           widget.onPostsSelected?.call(selectedIndices, i);
        //         })
        //     : null,
        // areAnySelected: selectedIndices.isNotEmpty,
      );
}
