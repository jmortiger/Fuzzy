import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/web/e621/search_helper.dart';
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import 'package:fuzzy/log_management.dart' as lm;


class WSearchBar extends StatefulWidget {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.genLogger("WSearchBar");
  // #endregion Logger
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
  static lm.FileLogger get logger => WSearchBar.logger;
  static const whitespaceCharacters = r'\u2028\n\r\u000B\f\u2029\u0085 	';

  @override
  void initState() {
    super.initState();
    searchController = SearchController()
      ..text = currentText = (widget.initialValue ?? "");
  }

  Iterable<String> generateSortedOptions(String currentTextValue) {
    final currText = currentTextValue;
    // var lastTermIndex = currText.lastIndexOf(RegExpExt.whitespace);
    var lastTermIndex =
        currText.lastIndexOf(RegExp('[$whitespaceCharacters$tagModifiersRegexString]'));
    lastTermIndex = lastTermIndex >= 0 ? lastTermIndex + 1 : 0;
    // final currSubString = currText.substring(lastTermIndex);
    final currPrefix = currText.substring(0, lastTermIndex);
    logger.finer("currText: $currText");
    logger.finer("lastTermIndex: $lastTermIndex");
    // logger.finer("currSubString: $currSubString");
    logger.finer("currPrefix: $currPrefix");
    if (allSuggestionSourcesEmpty() || currText.isEmpty) {
      return const Iterable<String>.empty();
    }
    var db = retrieveTagDB();
    if (db == null) {
      var r = allModifierTagsList
          .map((e) => "$currPrefix$e")
          .where((v) => v.contains(currText));
      if ((AppSettings.i?.favoriteTags.isEmpty ?? true) &&
          !SavedDataE6.isInit &&
          CachedSearches.searches.isEmpty) {
        return r.toList(growable: false)
          ..sort(util.getFineInverseSimilarityComparator(
            currText,
          ));
      }
      return {
        currText,
        if (CachedSearches.searches.isNotEmpty)
          ...(() {
            var relatedSearches = CachedSearches.searches.where(
              (element) => element.searchString.contains(currText),
            );
            return relatedSearches.mapAsList((e, i, l) => e.searchString)
              ..sort(
                util.getFineInverseSimilarityComparator(currText),
              )
              ..removeRange(
                min(
                  SearchView.i.numSavedSearchesInSearchBar,
                  relatedSearches.length,
                ),
                relatedSearches.length,
              );
          })(),
        if (SavedDataE6.isInit)
          ...SavedDataE6.all
              .where(
                (v) =>
                    v.verifyUniqueness() &&
                    !currText.contains(
                      "${E621.delimiter}${v.uniqueId}",
                    ),
              )
              .map((v) => "$currPrefix ${E621.delimiter}${v.uniqueId}")
              .toList()
            ..sort(
              util.getFineInverseSimilarityComparator(currText),
            ),
        ...r,
        if (AppSettings.i?.favoriteTags.isNotEmpty ?? false)
          ...AppSettings.i!.favoriteTags
              .where((element) => !currText.contains(element))
              .map((e) => "$currPrefix$e")
              .toList()
            ..sort(
              util.getFineInverseSimilarityComparator(currText),
            ),
      };
    }
    return genSearchOptionsFromTagDB(
      db: db,
      currText: currText,
      currPrefix: currPrefix,
    );
  }

  static const tagModifiers = ['+', '~', '-'];
  static const tagModifiersString = '+~-';
  static const tagModifiersRegexString = r'\+\~\-';
  ManagedPostCollectionSync get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  ManagedPostCollectionSync get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);
  String currentText = "";
  late SearchController searchController;
  // TODO: Just launch tag search requests for autocomplete, wrap in a class
  @override
  Widget build(BuildContext context) {
    // var fn = FocusNode();
    void closeAndUnfocus() {
      // fn.unfocus();
      if (searchController.isAttached && searchController.isOpen) {
        searchController.closeView(currentText);
      }
    }

    void onSubmitted(String s) {
      setState(() {
        currentText = s;
      });
      closeAndUnfocus();
      (s.isNotEmpty)
          ? _sendSearchAndUpdateState(tags: s)
          : _sendSearchAndUpdateState();
      widget.onSelected?.call();
      sc.parameters = PostPageSearchParameters(
        limit: SearchView.i.postsPerPage,
        tags: s,
        pageIndex: 0,
      );
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
      suggestionsBuilder: (context, controller) {
        logger.finer("Text: ${controller.text}");

        /// USING THE LIBRARY CAUSES THE ERROR.
        return generateSortedOptions(controller.text).map(
          (e) {
            const ws = r'[\u2028\n\r\u000B\f\u2029\u0085 	]';
            logger.finest("e = $e Length: ${e.length}");
            e = e.trim();
            logger.finest("e.trim() = $e Length: ${e.length}");
            logger.finest(e.contains(RegExp(ws)) ? e.split(RegExp(ws)) : [e]);
            return ListTile(
              dense: true,
              title: Text(
                  (e.contains(RegExp(ws)) ? e.split(RegExp(ws)) : [e]).last),
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
    int? limit,
    String? pageModifier,
    int? postId,
    int? pageNumber,
  }) {
    var sc = Provider.of<ManagedPostCollectionSync>(context, listen: false);
    sc.launchSearch(
      context: context,
      searchViewNotifier:
          Provider.of<SearchResultsNotifier?>(context, listen: false),
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
      tags: tags,
    );
  }
}
