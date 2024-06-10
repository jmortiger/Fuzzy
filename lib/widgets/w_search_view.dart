// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:fuzzy/web/site.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:http/http.dart' as http;
import 'package:fuzzy/util/util.dart' as util;

class WSearchView extends StatefulWidget {
  final bool lazyLoad;

  const WSearchView({super.key, this.lazyLoad = false});

  @override
  State<WSearchView> createState() => _WSearchViewState();
}

// TODO: Just launch tag search requests for autocomplete, wrap in a class
class _WSearchViewState extends State<WSearchView> {
  String searchText = "";
  Future<http.StreamedResponse>? pr;
  int? currentPostCollectionExpectedSize;
  E6Posts? posts;
  // bool fire = false;

  http.Request deliverSearchRequest({
    String tags = "jun_kobayashi rating:safe",
    int limit = 50,
    String? page,
  }) {
    currentPostCollectionExpectedSize = limit;
    return E621ApiEndpoints.searchPosts.getMoreData().genRequest(
      query: {
        "limit": (0, {"LIMIT": limit}),
        "tags": (0, {"SEARCH_STRING": tags}),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // if (fire) {
    //   setState(() {
    //     fire = false;
    //     pr = deliverSearchRequest(tags: searchText).send();
    //     pr!.then((value) =>
    //         value.stream.bytesToString().then((value) => setState(() {
    //               posts = widget.lazyLoad
    //                   ? E6PostsLazy.fromJson(
    //                       json.decode(value) as Map<String, dynamic>)
    //                   : E6PostsSync.fromJson(
    //                       json.decode(value) as Map<String, dynamic>);
    //               pr = null;
    //             })));
    //     posts = null;
    //   });
    // }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: simpleTextField(),
          // child: autoCompleteTextField(),
        ),
        if (posts == null && pr != null)
          Expanded(
            child: Center(
                child: pr != null
                    ? const AspectRatio(
                        aspectRatio: 1,
                        child: CircularProgressIndicator(),
                      )
                    : const Placeholder()),
          ),
        if (posts != null)
          (() {
            pr = null;
            return Expanded(
              child: WPostSearchResults(
                posts: posts!,
                expectedCount: widget.lazyLoad
                    ? (currentPostCollectionExpectedSize ?? 50)
                    : posts!.count,
                searchText: searchText,
              ),
            );
          })()
      ],
    );
  }

  @widgetFactory
  Autocomplete<TagDBEntry> autoCompleteTextField() {
    return Autocomplete<TagDBEntry>(
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        void Function() onFieldSubmitted,
      ) =>
          TextField(
        controller: textEditingController,
        focusNode: focusNode,
        onChanged: (value) => setState(() => searchText = value),
        onSubmitted: (s) => setState(() {
          onFieldSubmitted();
          searchText = textEditingController.text;
          if (searchText.isNotEmpty) {
            print(deliverSearchRequest(tags: searchText).headers);
            pr = deliverSearchRequest(tags: searchText).send();
          } else {
            print(deliverSearchRequest().headers);
            pr = deliverSearchRequest().send();
          }
          pr!.then((value) =>
              value.stream.bytesToString().then((value) => setState(() {
                    posts = widget.lazyLoad
                        ? E6PostsLazy.fromJson(
                            json.decode(value) as Map<String, dynamic>)
                        : E6PostsSync.fromJson(
                            json.decode(value) as Map<String, dynamic>);
                    pr = null;
                  })));
        }),
      ),
      optionsBuilder: (TextEditingValue textEditingValue) {
        var db = !util.DO_NOT_USE_TAG_DB ? util.tagDbLazy.itemSafe : null;
        if (db == null || textEditingValue.text.isEmpty) {
          return const Iterable<TagDBEntry>.empty();
        }
        var (s, e) = db.getCharStartAndEnd(textEditingValue.text[0]);
        print("range For ${textEditingValue.text[0]}: $s - $e");
        if (textEditingValue.text.length == 1) {
          return db.tagsByString.queue.getRange(s, e).toList(growable: false)
            ..sort((a, b) => b.postCount - a.postCount);
        }
        var t = db.tagsByString.queue.getRange(s, e).toList(growable: false),
            s1 = t.indexWhere(
                (element) => element.name.startsWith(textEditingValue.text));
        if (s1 == -1) {
          s1 = t.indexWhere((element) => element.name.startsWith(
                textEditingValue.text.substring(
                  0,
                  textEditingValue.text.length - 1,
                ),
              ));
        }
        if (s1 == -1) return const Iterable<TagDBEntry>.empty();
        var e1 = t.lastIndexWhere(
            (element) => element.name.startsWith(textEditingValue.text));
        if (e1 == -1) {
          e1 = t.lastIndexWhere((element) => element.name.startsWith(
              textEditingValue.text
                  .substring(0, textEditingValue.text.length - 1)));
        }
        if (e1 == -1) return const Iterable<TagDBEntry>.empty();
        return t.getRange(s1, e1).toList(growable: false)
          ..sort((a, b) => b.postCount - a.postCount);
      },
      displayStringForOption: (option) => option.name,
      onSelected: (option) => setState(() {
        searchText += option.name;
      }),
    );
  }

  @widgetFactory
  TextField simpleTextField() {
    return TextField(
      autofillHints: const [AutofillHints.url],
      onChanged: (value) => setState(() => searchText = value),
      onSubmitted: (value) => setState(() {
        print(deliverSearchRequest(tags: value).headers);
        pr = deliverSearchRequest(tags: value).send();
        pr!.then((value) =>
            value.stream.bytesToString().then((value) => setState(() {
                  posts = widget.lazyLoad
                      ? E6PostsLazy.fromJson(
                          json.decode(value) as Map<String, dynamic>)
                      : E6PostsSync.fromJson(
                          json.decode(value) as Map<String, dynamic>);
                  pr = null;
                })));
      }),
    );
  }
}
