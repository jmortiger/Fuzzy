import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/util/tag_db_import.dart' as dbi;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/web/e621/search_helper.dart' as sh;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import '../util/string_comparator.dart' as str_util;

class WSearchBar extends StatefulWidget {
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WSearchBar");
  static lm.FileLogger get logger => lRecord.logger;
  // #region Logger
  static lm.Printer get print => lRecord.print;
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
  // #region Static Members
  static const whitespaceCharacters = r'\u2028\n\r\u000B\f\u2029\u0085 	';
  static const tagModifiers = ['+', '~', '-'];
  static const tagModifiersString = '+~-';
  static const tagModifiersRegexString = r'\+\~\-';

  static lm.FileLogger get logger => WSearchBar.logger;
  // #endregion Static Members

  // #region Instance Fields
  bool showMetaTags = true;
  bool showSavedSearches = true;
  bool showPriorSearches = true;
  bool showFavTags = true;
  sh.MetaTagSearchData mts = sh.MetaTagSearchData(status: {});
  sh.Rating get searchRating => mts.rating;
  set searchRating(sh.Rating value) => mts.rating = value;
  bool? get doAddRating => mts.addRating;
  set doAddRating(bool? v) => mts.addRating = v;
  bool? doAddRatingForCheckbox(bool? value) => switch (value) {
        true => true,
        null => false,
        false => null,
      };
  String currentText = "";
  late SearchController searchController;
  // #endregion Instance Fields

  // #region Properties
  bool get allSuggestionSourcesEmpty =>
      (dbi.DO_NOT_USE_TAG_DB || dbi.tagDbLazy.$Safe == null) &&
      (AppSettings.i?.favoriteTags.isEmpty ?? true) &&
      !SavedDataE6.isInit &&
      CachedSearches.searches.isEmpty;
  TagDB? get retrieveTagDB =>
      !dbi.DO_NOT_USE_TAG_DB ? dbi.tagDbLazy.$Safe : null;
  ManagedPostCollectionSync get sc =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false);
  ManagedPostCollectionSync get scWatch =>
      Provider.of<ManagedPostCollectionSync>(context, listen: true);

  // #endregion Properties

  // TODO: Just launch tag search requests for autocomplete, wrap in a class
  @override
  Widget build(BuildContext context) {
    // final style = Theme.of(context).menuButtonTheme.style?.textStyle?.resolve(states)
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
            // final wsRe = RegExp(ws);
            final wsRe = RegExp(RegExpExt.whitespaceCharacters);
            logger.finest("e = $e Length: ${e.length}");
            e = e.trim();
            logger.finest("e.trim() = $e Length: ${e.length}");
            logger.finest(e.contains(wsRe) ? e.split(wsRe) : [e]);
            return ListTile(
              dense: true,
              title: Text((e.contains(wsRe) ? e.split(wsRe) : [e]).last),
              subtitle: Text(e),
              onTap: () {
                if (controller.isAttached) controller.closeView(e);
              },
            );
          },
        );
      },
      onSubmitted: sbcOnSubmitted,
      onChanged: (value) => setState(() {
        currentText = value;
      }),
      // viewOnSubmitted: onSubmitted,
      // viewOnChanged: (value) => setState(() {
      //   currentText = value;
      // }),
      viewTrailing: [
        StatefulBuilder(
          builder: (context, setState) => MenuBar(
            children: [
              SubmenuButton(
                menuChildren: [
                  SubmenuButton(
                    leadingIcon: Checkbox(
                      value: doAddRatingForCheckbox(doAddRating),
                      onChanged: (bool? v) => setState(() {
                        doAddRating = doAddRatingForCheckbox(v);
                      }),
                      tristate: true,
                    ),
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () => setState(() {
                          searchRating = sh.Rating.safe;
                        }),
                        child: const Text("Safe"),
                      ),
                      MenuItemButton(
                        onPressed: () => setState(() {
                          searchRating = sh.Rating.questionable;
                        }),
                        child: const Text("Questionable"),
                      ),
                      MenuItemButton(
                        onPressed: () => setState(() {
                          searchRating = sh.Rating.explicit;
                        }),
                        child: const Text("Explicit"),
                      ),
                    ],
                    child: Text(
                      "${doAddRating == false ? "-" : ""}${searchRating.searchStringShort}",
                      style: doAddRating == null
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.white38,
                            )
                          : null,
                    ),
                  ),
                  // TODO: FIX SETSTATE ERROR
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.status[sh.Status.deleted] = value
                              : mts.status.remove(sh.Status.deleted)),
                          value: mts.status[sh.Status.deleted],
                        ),
                        child: Text(sh.Status.deleted.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.status[sh.Status.pending] = value
                              : mts.status.remove(sh.Status.pending)),
                          value: mts.status[sh.Status.pending],
                        ),
                        child: Text(sh.Status.pending.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.status[sh.Status.active] = value
                              : mts.status.remove(sh.Status.active)),
                          value: mts.status[sh.Status.active],
                        ),
                        child: Text(sh.Status.active.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.status[sh.Status.flagged] = value
                              : mts.status.remove(sh.Status.flagged)),
                          value: mts.status[sh.Status.flagged],
                        ),
                        child: Text(sh.Status.flagged.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.status[sh.Status.modqueue] = value
                              : mts.status.remove(sh.Status.modqueue)),
                          value: mts.status[sh.Status.modqueue],
                        ),
                        child: Text(sh.Status.modqueue.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.status[sh.Status.any] = value
                              : mts.status.remove(sh.Status.any)),
                          value: mts.status[sh.Status.any],
                        ),
                        child: Text(sh.Status.any.searchString),
                      ),
                    ],
                    child: Text(
                      "status:",
                      style: mts.generateStatusString().isEmpty
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.white38,
                            )
                          : null,
                    ),
                  ),
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.types[sh.FileType.webm] = value
                              : mts.types.remove(sh.FileType.webm)),
                          value: mts.types[sh.FileType.webm],
                        ),
                        child: Text(sh.FileType.webm.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.types[sh.FileType.gif] = value
                              : mts.types.remove(sh.FileType.gif)),
                          value: mts.types[sh.FileType.gif],
                        ),
                        child: Text(sh.FileType.gif.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.types[sh.FileType.swf] = value
                              : mts.types.remove(sh.FileType.swf)),
                          value: mts.types[sh.FileType.swf],
                        ),
                        child: Text(sh.FileType.swf.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.types[sh.FileType.png] = value
                              : mts.types.remove(sh.FileType.png)),
                          value: mts.types[sh.FileType.png],
                        ),
                        child: Text(sh.FileType.png.searchString),
                      ),
                      MenuItemButton(
                        leadingIcon: DropdownButton(
                          items: sh.Modifier.dropdownItemsFull,
                          onChanged: (value) => setState(() => value != null
                              ? mts.types[sh.FileType.jpg] = value
                              : mts.types.remove(sh.FileType.jpg)),
                          value: mts.types[sh.FileType.jpg],
                        ),
                        child: Text(sh.FileType.jpg.searchString),
                      ),
                    ],
                    child: Text(
                      "type:",
                      style: mts.generateTypeString().isEmpty
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.white38,
                            )
                          : null,
                    ),
                  ),
                ],
                child: const Text("Advanced..."),
              ),
            ],
          ),
        ),
        StatefulBuilder(
            builder: (context, setState) => MenuBar(
                  children: [
                    SubmenuButton(
                      menuChildren: [
                        MenuItemButton(
                          leadingIcon: Checkbox(
                            value: showMetaTags,
                            onChanged: (value) => value != null
                                ? setState(() {
                                    showMetaTags = value;
                                  })
                                : "",
                          ),
                          onPressed: () => setState(() {
                            showMetaTags = !showMetaTags;
                          }),
                          child: const Text("Show Meta Tags"),
                        ),
                        MenuItemButton(
                          leadingIcon: Checkbox(
                            value: showSavedSearches,
                            onChanged: (value) => value != null
                                ? setState(() {
                                    showSavedSearches = value;
                                  })
                                : "",
                          ),
                          onPressed: () => setState(() {
                            showSavedSearches = !showSavedSearches;
                          }),
                          child: const Text("Show Saved Searches"),
                        ),
                        MenuItemButton(
                          leadingIcon: Checkbox(
                            value: showPriorSearches,
                            onChanged: (value) => value != null
                                ? setState(() {
                                    showPriorSearches = value;
                                  })
                                : "",
                          ),
                          onPressed: () => setState(() {
                            showPriorSearches = !showPriorSearches;
                          }),
                          child: const Text("Show Prior Searches"),
                        ),
                        MenuItemButton(
                          leadingIcon: Checkbox(
                            value: showFavTags,
                            onChanged: (value) => value != null
                                ? setState(() {
                                    showFavTags = value;
                                  })
                                : "",
                          ),
                          onPressed: () => setState(() {
                            showFavTags = !showFavTags;
                          }),
                          child: const Text("Show Fav Tags"),
                        ),
                      ],
                      child: const Icon(Icons.manage_search),
                    ),
                  ],
                )),
        // IconButton(
        //   icon: const Icon(Icons.manage_search),
        //   onPressed: () {},
        // ),
      ],
    );
  }

  // Iterable<ListTile> generateOptions(TextEditingValue value) {
  //   final currentTextValue = value.text;
  //   final currText = currentTextValue;
  //   // var lastTermIndex = currText.lastIndexOf(RegExpExt.whitespace);
  //   var lastTermIndex = currText
  //       .lastIndexOf(RegExp('[$whitespaceCharacters$tagModifiersRegexString]'));
  //   lastTermIndex = lastTermIndex >= 0 ? lastTermIndex + 1 : 0;
  //   final currSubString = currText.substring(lastTermIndex);
  //   final currPrefix = currText.substring(0, lastTermIndex);
  //   logger.finer("currText: $currText");
  //   logger.finer("lastTermIndex: $lastTermIndex");
  //   logger.finer("currSubString: $currSubString");
  //   logger.finer("currPrefix: $currPrefix");
  //   if (allSuggestionSourcesEmpty /*  || currText.isEmpty */) {
  //     return const Iterable<ListTile>.empty();
  //   }
  //   var db = retrieveTagDB;
  //   if (db == null) {
  //     var r = modifierTagsSuggestionsList
  //         .map((e) => "$currPrefix$e")
  //         .where((v) => v.contains(currText));
  //     if ((AppSettings.i?.favoriteTags.isEmpty ?? true) &&
  //         !SavedDataE6.isInit &&
  //         CachedSearches.searches.isEmpty) {
  //       return (r.toList()
  //             ..sort(
  //               str_util.getFineInverseSimilarityComparator(currText),
  //             ))
  //           .take(50);
  //     }
  //     return {
  //       currText,
  //       if (CachedSearches.searches.isNotEmpty)
  //         ...(() {
  //           var relatedSearches = CachedSearches.searches.where(
  //             (element) =>
  //                 !currText.contains(element.searchString) &&
  //                 element.searchString.contains(currText),
  //           );
  //           return relatedSearches.map((e) => e.searchString).toList()
  //             ..sort(
  //               str_util.getFineInverseSimilarityComparator(currText),
  //             )
  //             ..removeRange(
  //               relatedSearches.length -
  //                   min(
  //                     SearchView.i.numSavedSearchesInSearchBar,
  //                     relatedSearches.length,
  //                   ),
  //               relatedSearches.length,
  //             );
  //         })(),
  //       if (SavedDataE6.isInit && currSubString.contains(E621.delimiter))
  //         ...SavedDataE6.all
  //             .where(
  //               (v) =>
  //                   v.verifyUniqueness() &&
  //                   !currText.contains("${E621.delimiter}${v.uniqueId}") &&
  //                   "${E621.delimiter}${v.uniqueId}".contains(currSubString),
  //             )
  //             .map((v) => "$currPrefix ${E621.delimiter}${v.uniqueId}")
  //             .toList()
  //           ..sort(
  //             str_util.getFineInverseSimilarityComparator(currText),
  //           ),
  //       if (AppSettings.i?.favoriteTags.isNotEmpty ?? false)
  //         ...(AppSettings.i!.favoriteTags
  //                 .where((element) => !currPrefix.contains(element))
  //                 .map((e) => "$currPrefix$e")
  //                 .toList()
  //               ..sort(
  //                 str_util.getFineInverseSimilarityComparator(currText),
  //               ))
  //             .take(5),
  //       ...r.take(20),
  //     }.toList()
  //       ..sort(str_util.getFineInverseSimilarityComparator(currText));
  //   }
  // }

  Iterable<String> generateSortedOptions(String currentTextValue) {
    final currText = currentTextValue;
    // var lastTermIndex = currText.lastIndexOf(RegExpExt.whitespace);
    var lastTermIndex = currText
        .lastIndexOf(RegExp('[$whitespaceCharacters$tagModifiersRegexString]'));
    lastTermIndex = lastTermIndex >= 0 ? lastTermIndex + 1 : 0;
    final currSubString = currText.substring(lastTermIndex);
    final currPrefix = currText.substring(0, lastTermIndex);
    logger.finer("currText: $currText");
    logger.finer("lastTermIndex: $lastTermIndex");
    logger.finer("currSubString: $currSubString");
    logger.finer("currPrefix: $currPrefix");
    if (allSuggestionSourcesEmpty /*  || currText.isEmpty */) {
      return const Iterable<String>.empty();
    }
    var db = retrieveTagDB;
    if (db == null) {
      var r = showMetaTags
          ? sh.modifierTagsSuggestionsList
              .map((e) => "$currPrefix$e")
              .where((v) => v.contains(currText))
          : const Iterable<String>.empty();
      if (((AppSettings.i?.favoriteTags.isEmpty ?? true) || !showFavTags) &&
          (!SavedDataE6.isInit || !showSavedSearches) &&
          (CachedSearches.searches.isEmpty || !showPriorSearches)) {
        return (r.toList()
              ..sort(
                str_util.getFineInverseSimilarityComparator(currText),
              ))
            .take(50);
      }
      return {
        // currText,
        if (CachedSearches.searches.isNotEmpty && showPriorSearches)
          ...(() {
            var relatedSearches = CachedSearches.searches.where(
              (element) =>
                  !currText.contains(element.searchString) &&
                  element.searchString.contains(currText),
            );
            return relatedSearches.map((e) => e.searchString).toList()
              ..sort(
                str_util.getFineInverseSimilarityComparator(currText),
              )
              ..removeRange(
                relatedSearches.length -
                    min(
                      SearchView.i.numSavedSearchesInSearchBar,
                      relatedSearches.length,
                    ),
                relatedSearches.length,
              );
          })(),
        if (SavedDataE6.isInit &&
            currSubString.contains(E621.delimiter) &&
            showSavedSearches)
          ...SavedDataE6.all
              .where(
                (v) =>
                    v.verifyUniqueness() &&
                    !currText.contains("${E621.delimiter}${v.uniqueId}") &&
                    "${E621.delimiter}${v.uniqueId}".contains(currSubString),
              )
              .map((v) => "$currPrefix ${E621.delimiter}${v.uniqueId}")
              .toList()
            ..sort(
              str_util.getFineInverseSimilarityComparator(currText),
            ),
        if ((AppSettings.i?.favoriteTags.isNotEmpty ?? false) && showFavTags)
          ...(AppSettings.i!.favoriteTags
                  .where((element) => !currPrefix.contains(element))
                  .map((e) => "$currPrefix$e")
                  .toList()
                ..sort(
                  str_util.getFineInverseSimilarityComparator(currText),
                ))
              .take(5),
        ...r.take(20),
      }.toList()
        ..sort(str_util.getFineInverseSimilarityComparator(currText));
    }
    return genSearchOptionsFromTagDB(
      db: db,
      currText: currText,
      currPrefix: currPrefix,
    );
  }

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
                  return str_util.getFineInverseSimilarityComparator(currText)(
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
                return str_util.getFineInverseSimilarityComparator(
                  currText,
                )(a.name, b.name);
              },
            ))
          .map((e) => "$currPrefix ${e.name}"),
    ];
  }

  @override
  void initState() {
    super.initState();
    searchController = SearchController()
      ..text = currentText = (widget.initialValue ?? "");
  }

  // #region Search Bar Callbacks
  void sbcCloseAndUnfocus() {
    if (searchController.isAttached && searchController.isOpen) {
      searchController.closeView(currentText);
    }
  }

  void sbcOnSubmitted(String s) {
    setState(() {
      currentText = s;
    });
    sbcCloseAndUnfocus();
    _sendSearchAndUpdateState(
      limit: SearchView.i.postsPerPage,
      pageNumber: 1,
      tags: "$s${mts.toString()}",
    );
    widget.onSelected?.call();
    // sc.parameters = PostSearchQueryRecord.withIndex(
    //   limit: SearchView.i.postsPerPage,
    //   tags: s,
    //   pageIndex: 0,
    // );
  }
  // #endregion Search Bar Callbacks

  /// Call inside of setState
  void _sendSearchAndUpdateState({
    String tags = "",
    int? limit,
    String? pageModifier,
    int? postId,
    int? pageNumber,
  }) =>
      Provider.of<ManagedPostCollectionSync>(context, listen: false)
          .parameters = PostSearchQueryRecord(
        tags: tags,
        limit: limit ?? -1,
        page: encodePageParameterFromOptions(
              pageModifier: pageModifier,
              id: postId,
              pageNumber: pageNumber,
            ) ??
            "1",
      );
}

enum SuggestionType {
  favoriteTag,
  metaTag,
  savedSearch,
  cachedSearch,
}
