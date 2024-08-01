import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:fuzzy/web/e621/search_helper.dart';
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import 'package:fuzzy/log_management.dart' as lm;

import '../models/search_cache.dart';
import '../web/e621/e621_access_data.dart';

class WSearchBar extends StatefulWidget {
  // #region Logger
  static late final lRecord = lm.genLogger("WSearchBar");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  // final String? initialValue;
  final VoidFunction? onSelected;

  const WSearchBar({
    super.key,
    // this.initialValue,
    this.onSelected,
  });

  @override
  State<WSearchBar> createState() => _WSearchBarState();
}

class _WSearchBarState extends State<WSearchBar> {
  // #region Logger
  static late final lRecord = lm.genLogger("_WSearchBarState");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  Iterable<String> generateSortedOptions(String currentTextValue) {
    final currText = currentTextValue;
    var lastTermIndex = currText.lastIndexOf(RegExpExt.whitespace);
    lastTermIndex = lastTermIndex >= 0 ? lastTermIndex + 1 : 0;
    final currSubString = currText.substring(lastTermIndex);
    final currPrefix = currText.substring(0, lastTermIndex);
    if (allSuggestionSourcesEmpty() || currText.isEmpty) {
      return const Iterable<String>.empty();
    }
    var db = retrieveTagDB();
    if (db == null) {
      var r = allModifierTagsList.map((e) => "$currPrefix $e");
      if ((AppSettings.i?.favoriteTags.isEmpty ?? true) &&
          !SavedDataE6.isInit &&
          CachedSearches.searches.isEmpty) {
        return r.toList(growable: false)
          ..sort(util.getFineInverseSimilarityComparator(
            currText,
          ));
      }
      return [
        currText,
        ...r,
        if (SavedDataE6.isInit)
          ...SavedDataE6.all
              .where(
                (v) =>
                    v.verifyUniqueness() &&
                    !currText.contains(
                      "${E621.delimiter}${v.uniqueId}",
                    ),
              )
              .map((v) => "$currPrefix ${E621.delimiter}${v.uniqueId}"),
        if (AppSettings.i?.favoriteTags.isNotEmpty ?? false)
          ...AppSettings.i!.favoriteTags
              .where((element) => !currText.contains(element))
              .map((e) => "$currPrefix$e"),
        if (CachedSearches.searches.isNotEmpty)
          ...CachedSearches.searches
              .where(
                (element) => element.searchString.contains(currText),
              )
              .map((e) => e.searchString),
      ]..sort(
          util.getFineInverseSimilarityComparator(currText),
        );
    }
    return genSearchOptionsFromTagDB(
      db: db,
      currText: currText,
      currPrefix: currPrefix,
    );
  }

  String currentText = "";
  late SearchController searchController;
  // TODO: Just launch tag search requests for autocomplete, wrap in a class
  @override
  Widget build(BuildContext context) {
    SearchViewModel svm = Provider.of<SearchViewModel>(context, listen: false);
    var fn = FocusNode();
    // searchController.text = currentText;
    void closeAndUnfocus() {
      fn.unfocus();
      if (searchController.isAttached && searchController.isOpen) {
        searchController.closeView(currentText);
      }
    }

    void onSubmitted(String s) {
      closeAndUnfocus();
      // svm.searchText = s;//controller.text;
      // (svm.searchText.isNotEmpty)
      (s.isNotEmpty)
          ? _sendSearchAndUpdateState(tags: s) //svm.searchText)
          : _sendSearchAndUpdateState();
      widget.onSelected?.call();
      svm.searchText = s;
    }

    return SearchAnchor.bar(
      // viewConstraints: const BoxConstraints.expand(),
      constraints: BoxConstraints.expand(
        height: MediaQuery.sizeOf(context).height,
      ),
      barHintText: "Search",
      viewHintText: "Search",
      isFullScreen: true,
      searchController: searchController,
      // builder: (context, controller) {
      //   // return SearchBar(
      //   //   controller: controller,
      //   //   onTapOutside: (event) => closeAndUnfocus(),
      //   //   onTap: () => controller.openView(),
      //   //   focusNode: fn,
      //   //   textInputAction: TextInputAction.newline,
      //   //   onSubmitted: onSubmitted,
      //   //   onChanged: (value) => setState(() {
      //   //     currentText = value;
      //   //   }),
      //   // );
      //   return IconButton(
      //     icon: const Icon(Icons.search),
      //     onPressed: controller.openView,
      //   );
      // },
      suggestionsBuilder: (context, controller) {
        logger.finer("Text: ${controller.text}");

        /// USING THE LIBRARY CAUSES THE ERROR.
        return generateSortedOptions(controller.text).map(
          (e) {
            logger.finer("e = $e Length: ${e.length}");
            e = e.trim();
            logger.finer("e.trim() = $e Length: ${e.length}");
            logger.finer(
                e.contains(RegExp(r'[\u2028\n\r\u000B\f\u2029\u0085 	]'))
                    ? e.split(RegExp(r'[\u2028\n\r\u000B\f\u2029\u0085 	]'))
                    : [e]);
            return ListTile(
              dense: true,
              title: Text((e.contains(
                          RegExp(r'[\u2028\n\r\u000B\f\u2029\u0085 	]'))
                      ? e.split(RegExp(r'[\u2028\n\r\u000B\f\u2029\u0085 	]'))
                      : [e])
                  .last),
              subtitle: Text(e),
              onTap: /* closeAndUnfocus */ () {
                // setState(() {
                //   currentText = e;
                // });
                if (controller.isAttached) controller.closeView(e);
                // closeAndUnfocus();
              },
            );
          },
        );
      },
      onSubmitted: onSubmitted,
      onChanged: (value) => setState(() {
        currentText = value;
      }),
      // viewOnSubmitted: onSubmitted,
      // viewOnChanged: (value) => setState(() {
      //   currentText = value;
      // }),
    );
  }

  Widget _buildAutocomplete(BuildContext context) {
    SearchViewModel svm = Provider.of<SearchViewModel>(context, listen: false);
    return Autocomplete<String>(
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        void Function() onFieldSubmitted,
      ) {
        textEditingController.text = svm.searchText;
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          autofocus: autofocus ? !(autofocus = false) : autofocus,
          onSubmitted: (s) => setState(() {
            // onFieldSubmitted();
            svm.searchText = textEditingController.text;
            (svm.searchText.isNotEmpty)
                ? _sendSearchAndUpdateState(tags: svm.searchText)
                : _sendSearchAndUpdateState();
            widget.onSelected?.call();
          }),
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) =>
          generateSortedOptions(textEditingValue.text),
      displayStringForOption: (option) => option,
      onSelected: (option) => setState(() {
        Provider.of<SearchViewModel>(context, listen: false).searchText =
            option;
      }),
    );
  }

  bool autofocus = true;

  @override
  void initState() {
    super.initState();
    autofocus = true;
    searchController = SearchController()..text = currentText;
  }

  // SearchViewModel get svm =>
  bool allSuggestionSourcesEmpty() =>
      (util.DO_NOT_USE_TAG_DB || util.tagDbLazy.$Safe == null) &&
      (AppSettings.i?.favoriteTags.isEmpty ?? true) &&
      !SavedDataE6.isInit &&
      CachedSearches.searches.isEmpty;

  TagDB? retrieveTagDB() =>
      !util.DO_NOT_USE_TAG_DB ? util.tagDbLazy.$Safe : null;

  /// [currText] is all the text in the field; the value of [TextEditingValue.text].
  Iterable<String> genSearchOptionsFromTagDB({
    required TagDB db,
    required String currText,
    required String currPrefix,
  }) {
    var (s, e) = db.getCharStartAndEnd(currText[0]);
    logger.finer("range For ${currText[0]}: $s - $e");
    if (currText.length == 1) {
      return [
        currText,
        ...(db.tagsByString.queue.getRange(s, e).toList(growable: false)
              //..sort((a, b) => b.postCount - a.postCount))
              ..sort(
                (a, b) {
                  return util.getFineInverseSimilarityComparator(currText)(
                    a.name,
                    b.name,
                  );
                },
              ))
            .map((e) => "$currPrefix ${e.name}"),
      ];
    }
    var t = db.tagsByString.queue.getRange(s, e).toList(growable: false),
        s1 = t.indexWhere((element) => element.name.startsWith(currText));
    if (s1 == -1) {
      s1 = t.indexWhere((element) => element.name.startsWith(
            currText.substring(
              0,
              currText.length - 1,
            ),
          ));
    }
    if (s1 == -1) return const Iterable<String>.empty();
    var e1 = t.lastIndexWhere((element) => element.name.startsWith(currText));
    if (e1 == -1) {
      e1 = t.lastIndexWhere(
          (element) => element.name.startsWith(currText.substring(
                0,
                currText.length - 1,
              )));
    }
    if (e1 == -1) return const Iterable<String>.empty();
    return [
      currText,
      ...(t.getRange(s1, e1).toList(growable: false)
            //..sort((a, b) => b.postCount - a.postCount))
            ..sort(
              (a, b) {
                return util.getFineInverseSimilarityComparator(
                  currText,
                )(a.name, b.name);
              },
            ))
          .map((e) => "$currPrefix ${e.name}"),
    ];
  }

  /// Call inside of setState
  void _sendSearchAndUpdateState({
    String tags = "",
    int limit = 50,
    String? pageModifier,
    int? postId,
    int? pageNumber,
  }) {
    SearchViewModel svm = Provider.of<SearchViewModel>(context, listen: false);
    SearchCacheLegacy sc =
        Provider.of<SearchCacheLegacy>(context, listen: false);
    SearchResultsNotifier sr =
        Provider.of<SearchResultsNotifier>(context, listen: false);
    bool isNewRequest = false;
    var out = "pageModifier = $pageModifier, "
        "postId = $postId, "
        "pageNumber = $pageNumber,"
        "projectedTrueTags = ${E621.fillTagTemplate(tags)})";
    if (isNewRequest = (svm.priorSearchText != tags)) {
      out = "Request For New Terms: ${svm.priorSearchText} -> $tags ($out";
      sc.lastPostIdCached = null;
      sc.firstPostIdCached = null;
      svm.priorSearchText = tags;
    } else {
      out = "Request For Same Terms: ${svm.priorSearchText} ($out";
    }
    sr.selectedIndices.clear();
    logger.info(out);
    sc.hasNextPageCached = null;
    sc.lastPostOnPageIdCached = null;
    // var (:username, :apiKey) = devGetAuth()
    var username = E621AccessData.fallback?.username,
        apiKey = E621AccessData.fallback?.apiKey;
    svm.pr = E621.performUserPostSearch(
      tags: svm.forceSafe ? "$tags rating:safe" : tags,
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
      apiKey: apiKey,
      username: username,
    );
    svm.pr!.then((v) {
      setState(() {
        logger.finer("pr reset");
        svm.pr = null;
        var json = jsonDecode(v.responseBody);
        if (json["success"] == false) {
          logger.severe("_sendSearchAndUpdateState: Response failed: $json");
          if (json["reason"].contains("Access Denied")) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Access Denied. Did you mean to login?"),
            ));
          }
          sc.posts = E6PostsSync(posts: []);
        } else {
          sc.posts = svm.lazyLoad
              ? E6PostsLazy.fromJson(json as Map<String, dynamic>)
              : E6PostsSync.fromJson(json as Map<String, dynamic>);
        }
        if (sc.posts?.posts.firstOrNull != null) {
          if (sc.posts.runtimeType == E6PostsLazy) {
            (sc.posts as E6PostsLazy)
                .onFullyIterated
                .subscribe((a) => sc.getHasNextPage(
                      tags: svm.priorSearchText,
                      lastPostId: a.posts.last.id,
                    ));
          } else {
            sc.getHasNextPage(
                tags: svm.priorSearchText,
                lastPostId: (sc.posts as E6PostsSync).posts.last.id);
          }
        }
        if (isNewRequest) sc.firstPostIdCached = sc.firstPostOnPageId;
      });
    }).catchError((err, st) {
      logger.severe(err, err, st);
    });
  }

  // static ({String? username, String? apiKey}) devGetAuth() => (
  // E621AccessData.useLoginData
  //     ? (
  //         username: E621AccessData.fallback?.username,
  //         apiKey: E621AccessData.fallback?.apiKey,
  //       )
  //     : (username: null, apiKey: null);
}
