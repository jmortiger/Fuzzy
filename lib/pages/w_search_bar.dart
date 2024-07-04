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

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

late final lRecord = lm.genLogger("WSearchBar");
late final print = lRecord.print;
late final logger = lRecord.logger;
// #endregion Logger

class WSearchBar extends StatefulWidget {
  final String? initialValue;
  final VoidFunction? onSelected;

  const WSearchBar({
    super.key,
    this.initialValue,
    this.onSelected,
  });

  @override
  State<WSearchBar> createState() => _WSearchBarState();
}

class _WSearchBarState extends State<WSearchBar> {
  // TODO: Just launch tag search requests for autocomplete, wrap in a class
  @override
  Widget build(BuildContext context) {
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
      optionsBuilder: (TextEditingValue textEditingValue) {
        final currText = textEditingValue.text;
        var lastTermIndex = currText.lastIndexOf(RegExpExt.whitespace);
        lastTermIndex = lastTermIndex >= 0 ? lastTermIndex + 1 : 0;
        final currSubString = currText.substring(lastTermIndex);
        final currPrefix = currText.substring(
            0, lastTermIndex);
        if (allSuggestionSourcesEmpty() || currText.isEmpty) {
          return const Iterable<String>.empty();
        }
        var db = retrieveTagDB();
        if (db == null) {
          var r = allModifierTagsList.map((e) => "$currPrefix $e");
          if ((AppSettings.i?.favoriteTags.isEmpty ?? true) &&
              SavedDataE6Legacy.$Safe == null &&
              CachedSearches.searches.isEmpty) {
            return r
              .toList(growable: false)
              ..sort(util.getFineInverseSimilarityComparator(
                currText,
              ));
          }
          return [
            currText,
            ...r,
            if (SavedDataE6Legacy.$Safe != null)
              ...SavedDataE6Legacy.$.all
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
      },
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
  }

  // SearchViewModel get svm =>
  bool allSuggestionSourcesEmpty() =>
      (util.DO_NOT_USE_TAG_DB || util.tagDbLazy.itemSafe == null) &&
      (AppSettings.i?.favoriteTags.isEmpty ?? true) &&
      SavedDataE6Legacy.$Safe == null &&
      CachedSearches.searches.isEmpty;

  TagDB? retrieveTagDB() =>
      !util.DO_NOT_USE_TAG_DB ? util.tagDbLazy.itemSafe : null;

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
    SearchCache sc = Provider.of<SearchCache>(context, listen: false);
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
    logger.finer(out);
    sc.hasNextPageCached = null;
    sc.lastPostOnPageIdCached = null;
    var (:username, :apiKey) = devGetAuth();
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

  ({String? username, String? apiKey}) devGetAuth() =>
      Provider.of<SearchViewModel>(context, listen: false).sendAuthHeaders &&
              E621AccessData.devAccessData.isAssigned
          ? (
              username: E621AccessData.devAccessData.item.username,
              apiKey: E621AccessData.devAccessData.item.apiKey,
            )
          : (username: null, apiKey: null);
}
