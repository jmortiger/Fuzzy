import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/util/tag_db_import.dart' as dbi;
import 'package:fuzzy/util/string_comparator.dart' as str_util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/web/e621/search_helper.dart' as sh;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

class WSearchBar extends StatefulWidget {
  // #region Logger
  static lm.FileLogger get logger => lRecord.logger;
  static lm.Printer get print => lRecord.print;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WSearchBar");
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
  static const tagModifiersRegexString = r'\+\~\-';
  static const noOutputStyle = TextStyle(
    color: Colors.white38,
    // decoration: TextDecoration.lineThrough,
  );
  static lm.FileLogger get logger => WSearchBar.logger;
  // #endregion Static Members

  // #region Instance Fields
  bool showMetaTags = true;
  bool showSavedSearches = true;
  bool showPriorSearches = true;
  bool showFavTags = true;
  sh.MetaTagSearchData mts = sh.MetaTagSearchData(status: {});
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
  // #endregion Properties

  // #region Tristate management
  bool? convertTristateForCheckbox(bool? value) => switch (value) {
        true => true,
        null => false,
        false => null,
      };
  bool? cycleTristateConverted(bool? value) => switch (value) {
        true => false,
        false => null,
        null => true,
      };
  bool? cycleTristateDirect(bool? value) => switch (value) {
        true => null,
        null => false,
        false => true,
      };
  // #endregion Tristate management

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
        /* return generateSortedOptions(controller.text).map(
          (e) => genTileFromString(e, controller: controller),
        ); */
        return generateOptions(controller.value, controller: controller);
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
        buildAdvancedSearchMenuBar(),
        StatefulBuilder(
            builder: (context, setState) => MenuBar(
                  children: [
                    SubmenuButton(
                      menuChildren: [
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.close),
                          onPressed: () => /* this. */ setState(() {
                            searchController.text = currentText = "";
                          }),
                          child: const Text("Clear text"),
                        ),
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            mts.clear();
                          }),
                          child: const Text("Clear metatags"),
                        ),
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
      ],
    );
  }

  ListTile genTileFromString(
    String e, {
    Widget? leading,
    Widget? trailing,
    SearchController? controller,
    void Function()? onTap,
  }) {
    final tAndS = genTitleAndSubtitleFromString(e);
    return ListTile(
      dense: true,
      title: Text(tAndS.$1),
      subtitle: Text(tAndS.$2),
      onTap: onTap ??
          () {
            if (controller?.isAttached ?? false) controller!.closeView(e);
          },
      leading: leading,
      trailing: trailing,
    );
  }

  (String title, String subtitle) genTitleAndSubtitleFromString(String e) {
    final wsRe = RegExp(r"\s");
    logger.finest("e = $e Length: ${e.length}");
    e = e.trim();
    logger.finest("e.trim() = $e Length: ${e.length}");
    logger.finest(e.contains(wsRe) ? e.split(wsRe) : [e]);
    return ((e.contains(wsRe) ? e.split(wsRe) : [e]).last, e);
  }

  static const _previewLength = 15;
  Widget buildAdvancedSearchMenuBar() {
    final ms = WidgetStatePropertyAll<Size?>(Size(
        0,
        Theme.of(context)
                .menuBarTheme
                .style
                ?.minimumSize
                ?.resolve({})?.height ??
            0));
    return StatefulBuilder(
      builder: (context, setState) => MenuBar(
        style:
            Theme.of(context).menuBarTheme.style?.copyWith(minimumSize: ms) ??
                MenuStyle(minimumSize: ms),
        children: [
          SelectorNotifier(
            builder: (context, v, child) {
              final r = Text(
                v,
                softWrap: true,
                style: const TextStyle(color: Colors.white70),
              );
              return v.isEmpty
                  ? const SizedBox(width: 0, height: 0)
                  : v.length > _previewLength
                      ? SubmenuButton(
                          menuChildren: [
                              MenuItemButton(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width / 2,
                                  ),
                                  child: r,
                                ),
                              ),
                            ],
                          child: Text(
                            // "...${v.substring(v.length - _previewLength - 3)}",
                            "${v.substring(0, _previewLength - 3)}...",
                            softWrap: true,
                          ))
                      : MenuItemButton(child: r);
            },
            selector: (context, value) => value.toString(),
            value: mts,
          ),
          SubmenuButton(
            menuChildren: [
              SubmenuButton(
                leadingIcon: Checkbox(
                  value: convertTristateForCheckbox(mts.addRating),
                  onChanged: (bool? v) => setState(() {
                    mts.addRating = convertTristateForCheckbox(v);
                  }),
                  tristate: true,
                ),
                menuChildren: [
                  MenuItemButton(
                    onPressed: () => setState(() {
                      mts.rating = sh.Rating.safe;
                    }),
                    child: const Text("Safe"),
                  ),
                  MenuItemButton(
                    onPressed: () => setState(() {
                      mts.rating = sh.Rating.questionable;
                    }),
                    child: const Text("Questionable"),
                  ),
                  MenuItemButton(
                    onPressed: () => setState(() {
                      mts.rating = sh.Rating.explicit;
                    }),
                    child: const Text("Explicit"),
                  ),
                ],
                child: Text(
                  "${mts.addRating == false ? "-" : ""}${mts.rating.searchStringShort}",
                  style: mts.addRating == null ? noOutputStyle : null,
                ),
              ),
              SubmenuButton(
                menuChildren: [
                  buildDropdown(
                    sh.Status.deleted,
                    mts.status,
                    setState,
                  ),
                  buildDropdown(
                    sh.Status.pending,
                    mts.status,
                    setState,
                  ),
                  buildDropdown(
                    sh.Status.active,
                    mts.status,
                    setState,
                  ),
                  buildDropdown(
                    sh.Status.flagged,
                    mts.status,
                    setState,
                  ),
                  buildDropdown(
                    sh.Status.modqueue,
                    mts.status,
                    setState,
                  ),
                  buildDropdown(
                    sh.Status.any,
                    mts.status,
                    setState,
                  ),
                ],
                child: Text(
                  "status:",
                  style: mts.statusString.isEmpty ? noOutputStyle : null,
                ),
              ),
              SubmenuButton(
                menuChildren: [
                  buildDropdown(
                    sh.FileType.webm,
                    mts.types,
                    setState,
                  ),
                  buildDropdown(
                    sh.FileType.gif,
                    mts.types,
                    setState,
                  ),
                  buildDropdown(
                    sh.FileType.swf,
                    mts.types,
                    setState,
                  ),
                  buildDropdown(
                    sh.FileType.png,
                    mts.types,
                    setState,
                  ),
                  buildDropdown(
                    sh.FileType.jpg,
                    mts.types,
                    setState,
                  ),
                ],
                child: Text(
                  "type:",
                  style: mts.typeString.isEmpty ? noOutputStyle : null,
                ),
              ),
              ...sh.BooleanSearchTag.values.map(
                (e) => buildTristateBool(e),
              ),
            ],
            child: const Text("..."),
          ),
        ],
      ),
    );
  }

  Widget buildTristateBool(sh.BooleanSearchTag tag) {
    return StatefulBuilder(
      builder: (context, setState) => MenuItemButton(
        closeOnActivate: false,
        leadingIcon: Checkbox(
          value: convertTristateForCheckbox(mts.getBooleanParameter(tag)),
          onChanged: (bool? v) => setState(() {
            mts.setBooleanParameter(tag, convertTristateForCheckbox(v));
          }),
          tristate: true,
        ),
        onPressed: () => setState(() {
          mts.setBooleanParameter(
            tag,
            cycleTristateConverted(mts.getBooleanParameter(tag)),
          );
        }),
        child: Text(
          tag.toSearchTag((mts.getBooleanParameter(tag) ?? true)),
          style: mts.getBooleanParameter(tag) == null ? noOutputStyle : null,
        ),
      ),
    );
  }

  MenuItemButton buildDropdown<E extends sh.SearchableEnum>(
      E enumValue, Map<E, sh.Modifier> map, StateSetter setState) {
    // logger.info(
    //     "X: ${util.calculateTextSize(text: "X", style: DefaultTextStyle.of(context).style).width}\n~: ${util.calculateTextSize(text: "~", style: DefaultTextStyle.of(context).style).width}\n+: ${util.calculateTextSize(text: "+", style: DefaultTextStyle.of(context).style).width}\n-: ${util.calculateTextSize(text: "-", style: DefaultTextStyle.of(context).style).width}");
    const double padding = 12 + 12 + /* 4+4+ */ 40;
    // const double allegedWidth = 9.8;
    return MenuItemButton(
      leadingIcon: DropdownMenu(
        dropdownMenuEntries: sh.Modifier.dropdownEntriesFull,
        onSelected: (value) => setState(() =>
            value != null ? map[enumValue] = value : map.remove(enumValue)),
        initialSelection: map[enumValue],
        inputDecorationTheme: const InputDecorationTheme(
            isDense: true,
            border: InputBorder.none,
            isCollapsed: true,
            constraints: BoxConstraints.tightFor(width: 12 + padding)),
        // width: 10 + padding,
      ),
      child: Text(
        enumValue.searchString,
        style: map[enumValue] == null
            ? noOutputStyle
            : const TextStyle(color: Colors.white),
      ),
    );
  }

  Iterable<ListTile> generateOptions(
    TextEditingValue currentTextValue, {
    SearchController? controller,
    void Function()? onTap,
  }) {
    final currFullText = currentTextValue.text;
    var lastTermIndex = currFullText
        .lastIndexOf(RegExp('[$whitespaceCharacters$tagModifiersRegexString]'));
    lastTermIndex = lastTermIndex >= 0 ? lastTermIndex + 1 : 0;
    final currSubString = currFullText.substring(lastTermIndex);
    final currPrefix = currFullText.substring(0, lastTermIndex);
    logger.finer("currText: $currFullText");
    logger.finer("lastTermIndex: $lastTermIndex");
    logger.finer("currSubString: $currSubString");
    logger.finer("currPrefix: $currPrefix");
    if (allSuggestionSourcesEmpty) return const Iterable<ListTile>.empty();
    final comp = str_util.getFineInverseSimilarityComparator(currFullText);
    var db = retrieveTagDB;
    if (db == null) {
      var r = showMetaTags
          ? sh.modifierTagsSuggestionsList
              .map((e) => "$currPrefix$e")
              .where((v) => v.contains(currFullText))
          : const Iterable<String>.empty();
      if (((AppSettings.i?.favoriteTags.isEmpty ?? true) || !showFavTags) &&
          (!SavedDataE6.isInit || !showSavedSearches) &&
          (CachedSearches.searches.isEmpty || !showPriorSearches)) {
        return (r.toList()..sort(comp)).take(50).map((e) => genTileFromString(
              e,
              controller: controller,
              onTap: onTap,
              leading: const Text("Meta"),
            ));
      }
      return [
        if (CachedSearches.searches.isNotEmpty && showPriorSearches)
          ...(() {
            var relatedSearches = CachedSearches.searches
                .where((e) =>
                    !currFullText.contains(e.searchString) &&
                    e.searchString.contains(currFullText))
                .toList();
            if (currFullText.isNotEmpty) {
              relatedSearches
                  .sort((e1, e2) => comp(e1.searchString, e2.searchString));
            } else {
              relatedSearches = relatedSearches.reversed.toList();
            }
            return relatedSearches
              ..removeRange(
                min(
                  SearchView.i.numSavedSearchesInSearchBar,
                  relatedSearches.length,
                ),
                relatedSearches.length,
              );
          })()
              .map(
            (e) => genTileFromString(
              e.searchString,
              controller: controller,
              onTap: onTap,
              leading: const Icon(Icons.youtube_searched_for),
              trailing: IconButton(
                // TODO: Make deleting a search remove it from suggestions
                onPressed: () => CachedSearches.removeSearch(element: e),
                icon: const Icon(Icons.delete),
                tooltip: "Delete saved search",
              ),
            ),
          ),
        if (SavedDataE6.isInit &&
            currSubString.contains(E621.delimiter) &&
            showSavedSearches)
          ...(SavedDataE6.all
                  .where(
                    (v) =>
                        v.verifyUniqueness() &&
                        !currFullText
                            .contains("${E621.delimiter}${v.uniqueId}") &&
                        "${E621.delimiter}${v.uniqueId}"
                            .contains(currSubString),
                  )
                  .map((v) => "$currPrefix ${E621.delimiter}${v.uniqueId}")
                  .toList()
                ..sort(comp))
              .map(
            (e) => genTileFromString(
              e,
              controller: controller,
              onTap: onTap,
              leading: const Icon(Icons.save),
            ),
          ),
        if ((AppSettings.i?.favoriteTags.isNotEmpty ?? false) && showFavTags)
          ...(AppSettings.i!.favoriteTags
                  .where((element) => !currPrefix.contains(element))
                  .map((e) => "$currPrefix$e")
                  .toList()
                ..sort(comp))
              .take(5)
              .map((e) => genTileFromString(
                    e,
                    controller: controller,
                    onTap: onTap,
                    leading: const Icon(Icons.favorite),
                  )),
        ...r.take(20).map((e) => genTileFromString(
              e,
              controller: controller,
              onTap: onTap,
              leading: const Text("Meta"),
            )),
      ]..sort((e1, e2) =>
          comp((e1.subtitle as Text).data!, (e2.subtitle as Text).data!));
    }
    return const Iterable<ListTile>.empty();
    // return genSearchOptionsFromTagDB(
    //   db: db,
    //   currText: currText,
    //   currPrefix: currPrefix,
    // );
  }

  Iterable<String> generateSortedOptions(String currentTextValue) {
    final currText = currentTextValue;
    var lastTermIndex = currText.lastIndexOf(
      RegExp('[$whitespaceCharacters$tagModifiersRegexString]'),
    );
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
    Provider.of<ManagedPostCollectionSync>(context, listen: false).parameters =
        PostSearchQueryRecord(
      limit: SearchView.i.postsPerPage,
      page: "1",
      tags: "$s${mts.toString()}",
    );
    widget.onSelected?.call();
  }
  // #endregion Search Bar Callbacks
}
