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
import 'package:e621/middleware.dart' as sh;
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
  static const limitPriorSearchesInSearchBar = false;
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
  late sh.MetaTagSearchData mts;
  String currentText = "";
  late SearchController searchController;
  // #endregion Instance Fields

  // #region Properties
  bool get allSuggestionSourcesEmpty =>
      !hasSuggestionsFromTagDb &&
      !hasSuggestionsFromFavTags &&
      !hasSuggestionsFromSavedSearches &&
      !hasSuggestionsFromCachedSearches;
  bool get hasSuggestionsFromCachedSearches =>
      showPriorSearches &&
      CachedSearches.searches.isNotEmpty &&
      (!limitPriorSearchesInSearchBar ||
          SearchView.i.numSavedSearchesInSearchBar > 0);
  bool get hasSuggestionsFromSavedSearches =>
      showSavedSearches && SavedDataE6.isInit;
  bool get hasSuggestionsFromFavTags =>
      (AppSettings.i?.favoriteTagsAll.isNotEmpty ?? false) && showFavTags;
  bool get hasSuggestionsFromTagDb =>
      !dbi.DO_NOT_USE_TAG_DB && dbi.tagDbLazy.$Safe != null;
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
        return _generateOptions(controller.value, controller: controller);
      },
      onSubmitted: _sbcOnSubmitted,
      onChanged: (value) => setState(() {
        currentText = value;
      }),
      // viewOnSubmitted: onSubmitted,
      // viewOnChanged: (value) => setState(() {
      //   currentText = value;
      // }),
      viewTrailing: [
        _buildAdvancedSearchMenuBar(),
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
          ),
        ),
      ],
    );
  }

  ListTile _genTileFromString(
    String e, {
    Widget? leading,
    Widget? trailing,
    SearchController? controller,
    void Function()? onTap,
  }) {
    final tAndS = _genTitleAndSubtitleWidgetFromString(e);
    return ListTile(
      dense: true,
      title: tAndS.$1,
      subtitle: tAndS.$2,
      onTap: _genCallback(e, onTap, controller),
      leading: leading,
      trailing: trailing,
    );
  }

  (String title, String subtitle) _genTitleAndSubtitleFromString(String e) {
    final wsRe = RegExp(r"\s");
    logger.finest("e = $e Length: ${e.length}");
    e = e.trim();
    logger.finest("e.trim() = $e Length: ${e.length}");
    logger.finest(e.contains(wsRe) ? e.split(wsRe) : [e]);
    return ((e.contains(wsRe) ? e.split(wsRe) : [e]).last, e);
  }

  (Text title, Text subtitle) _genTitleAndSubtitleWidgetFromString(String e) {
    final t = _genTitleAndSubtitleFromString(e);
    return (Text(t.$1), Text(t.$2));
  }

  static const _previewLength = 15;
  Widget _buildAdvancedSearchMenuBar() {
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
              MenuItemButton(
                child: DropdownMenu(
                  dropdownMenuEntries: _orderDropdownEntries,
                  onSelected: (value) => setState(() =>
                      value != sh.Order.idDesc ? mts.order = value : null),
                  initialSelection: mts.order ?? sh.Order.idDesc,
                  inputDecorationTheme: const InputDecorationTheme(
                    isDense: true,
                    border: InputBorder.none,
                    isCollapsed: true,
                    // constraints: BoxConstraints.tightFor(width: 12 + padding),
                  ),
                  // width: 10 + padding,
                ),
                // child: Text(
                //   mts.orderString.isEmpty ? "order:id_desc" : mts.orderString,
                //   style: mts.order == null
                //       ? noOutputStyle
                //       : const TextStyle(color: Colors.white),
                // ),
              ),
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
                  _buildDropdown(
                    sh.Status.deleted,
                    mts.status,
                    setState,
                  ),
                  _buildDropdown(
                    sh.Status.pending,
                    mts.status,
                    setState,
                  ),
                  _buildDropdown(
                    sh.Status.active,
                    mts.status,
                    setState,
                  ),
                  _buildDropdown(
                    sh.Status.flagged,
                    mts.status,
                    setState,
                  ),
                  _buildDropdown(
                    sh.Status.modqueue,
                    mts.status,
                    setState,
                  ),
                  _buildDropdown(
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
                  _buildDropdown(
                    sh.FileType.webm,
                    mts.types,
                    setState,
                  ),
                  _buildDropdown(
                    sh.FileType.gif,
                    mts.types,
                    setState,
                  ),
                  _buildDropdown(
                    sh.FileType.swf,
                    mts.types,
                    setState,
                  ),
                  _buildDropdown(
                    sh.FileType.png,
                    mts.types,
                    setState,
                  ),
                  _buildDropdown(
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
                (e) => _buildTristateBool(e),
              ),
            ],
            child: const Text("..."),
          ),
        ],
      ),
    );
  }

  Widget _buildTristateBool(sh.BooleanSearchTag tag) {
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
          tag.toSearch((mts.getBooleanParameter(tag) ?? true)),
          style: mts.getBooleanParameter(tag) == null ? noOutputStyle : null,
        ),
      ),
    );
  }

  MenuItemButton _buildDropdown<E extends sh.SearchableEnum>(
      E enumValue, Map<E, sh.Modifier> map, StateSetter setState) {
    // logger.info(
    //     "X: ${util.calculateTextSize(text: "X", style: DefaultTextStyle.of(context).style).width}\n~: ${util.calculateTextSize(text: "~", style: DefaultTextStyle.of(context).style).width}\n+: ${util.calculateTextSize(text: "+", style: DefaultTextStyle.of(context).style).width}\n-: ${util.calculateTextSize(text: "-", style: DefaultTextStyle.of(context).style).width}");
    const double padding = 12 + 12 + /* 4+4+ */ 40;
    // const double allegedWidth = 9.8;
    return MenuItemButton(
      leadingIcon: DropdownMenu(
        dropdownMenuEntries: _modifierDropdownEntriesFull,
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

  static String? _pullFromSubtitle(ListTile t) => (t.subtitle as Text).data;
  Iterable<ListTile> _generateOptions(
    TextEditingValue currentTextValue, {
    SearchController? controller,
    void Function()? onTap,
  }) {
    final currFullText = currentTextValue.text;
    var lastTermIndex =
        currFullText.lastIndexOf(RegExp('[\\s$tagModifiersRegexString]'));
    lastTermIndex = lastTermIndex >= 0 ? lastTermIndex + 1 : 0;

    /// The current incomplete token.
    final currSubString = currFullText.substring(lastTermIndex);

    /// All the text before the current incomplete token.
    final currPrefix = currFullText.substring(0, lastTermIndex);
    logger.finer("currText: $currFullText");
    logger.finer("lastTermIndex: $lastTermIndex");
    logger.finer("currSubString: $currSubString");
    logger.finer("currPrefix: $currPrefix");
    if (allSuggestionSourcesEmpty) return const Iterable<ListTile>.empty();
    final comp = str_util.getFineInverseSimilarityComparator(currFullText);
    var r = showMetaTags
        ? sh.modifierTagsSuggestionsList
            .map((e) => "$currPrefix$e")
            .where((v) => v.contains(currFullText))
        : const Iterable<String>.empty();
    if (allSuggestionSourcesEmpty) {
      return (r.toList()..sort(comp)).take(50).map((e) => _genTileFromString(
            e,
            controller: controller,
            onTap: onTap,
            leading: const Text("Meta"),
          ));
    }
    final addedResultantValues = <String>{};
    int compListTile(ListTile a, ListTile b) =>
        comp(_pullFromSubtitle(a)!, _pullFromSubtitle(b)!);
    Iterable<ListTile> genFromCachedSearches() {
      var relatedSearches = CachedSearches.searches;
      List<ListTile> folderCS(List<ListTile> p, e) =>
          addedResultantValues.add(e.searchString)
              ? (p
                ..add(_genTileFromString(
                  e.searchString,
                  controller: controller,
                  onTap: onTap,
                  leading: const Icon(Icons.youtube_searched_for),
                  trailing: IconButton(
                    // TODO: Make deleting a search remove it from suggestions immediately
                    onPressed: () => CachedSearches.removeSearch(element: e),
                    icon: const Icon(Icons.delete),
                    tooltip: "Delete saved search",
                  ),
                )))
              : p;
      if (limitPriorSearchesInSearchBar) {
        // Searches where its not fully typed out and some of it matches
        relatedSearches = CachedSearches.searches
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
        relatedSearches.removeRange(
          min(
            SearchView.i.numSavedSearchesInSearchBar,
            relatedSearches.length,
          ),
          relatedSearches.length,
        );
        return relatedSearches.fold<List<ListTile>>([], folderCS);
      } else {
        // Searches where its not fully typed out and some of it matches
        return relatedSearches.fold<List<ListTile>>(
          [],
          (p, e) => !currFullText.contains(e.searchString) &&
                  e.searchString.contains(currFullText)
              ? folderCS(p, e)
              : p,
        );
      }
    }

    return [
      if (hasSuggestionsFromCachedSearches) ...genFromCachedSearches(),
      if (hasSuggestionsFromSavedSearches &&
          currSubString.contains(E621.savedSearchTag))
        ...SavedDataE6.all.fold<List<ListTile>>(
          <ListTile>[],
          (p, v) => v.verifyUniqueness() &&
                  !currFullText
                      .contains("${E621.savedSearchTag}${v.uniqueId}") &&
                  "${E621.savedSearchTag}${v.uniqueId}"
                      .contains(currSubString) &&
                  addedResultantValues
                      .add("$currPrefix ${E621.savedSearchTag}${v.uniqueId}")
              ? (p
                ..add(_genTileFromString(
                  "$currPrefix ${E621.savedSearchTag}${v.uniqueId}",
                  controller: controller,
                  onTap: onTap,
                  leading: const Icon(Icons.save),
                )))
              : p,
        ),
      if (hasSuggestionsFromFavTags)
        ...(AppSettings.i!.favoriteTagsAll
                .where((element) => !currPrefix.contains(element))
                .map((e) => "$currPrefix$e")
                .toList()
              ..sort(comp))
            .take(5)
            .fold<List<ListTile>>(
                [],
                (p, e) => addedResultantValues.add(e)
                    ? (p
                      ..add(_genTileFromString(
                        e,
                        controller: controller,
                        onTap: onTap,
                        leading: const Icon(Icons.favorite),
                      )))
                    : p),
      ...r.take(20).fold<List<ListTile>>(
          [],
          (p, e) => addedResultantValues.add(e)
              ? (p
                ..add(_genTileFromString(
                  e,
                  controller: controller,
                  onTap: onTap,
                  leading: const Text("Meta"),
                )))
              : p),
      if (retrieveTagDB != null)
        ..._filterSearchOptionsFromTagDB(
          db: retrieveTagDB!,
          currText: currFullText,
          currPrefix: currPrefix,
        ).fold<List<ListTile>>(
            [],
            (p, e) => addedResultantValues.add("$currPrefix ${e.name}")
                ? (p
                  ..add(_genTagDbTile(
                    e,
                    currPrefix: currPrefix,
                    controller: controller,
                    onTap: onTap,
                  )))
                : p),
    ]..sort(compListTile);
  }

  ListTile _genTagDbTile(
    TagDBEntry element, {
    required String currPrefix,
    Widget? trailing,
    SearchController? controller,
    void Function()? onTap,
  }) {
    final e = "$currPrefix ${element.name}";
    final tAndS = _genTitleAndSubtitleFromString(e);
    return ListTile(
      dense: true,
      title: Text("${tAndS.$1} {${element.category.name}}"),
      subtitle: Text(tAndS.$2),
      onTap: _genCallback(e, onTap, controller),
      // leading: const Text("TagDB"),
      leading: const Icon(Icons.lightbulb),
      trailing: trailing,
    );
  }

  /// [currText] is all the text in the field; the value of [TextEditingValue.text].
  Iterable<TagDBEntry> _filterSearchOptionsFromTagDB({
    required TagDB db,
    required String currText,
    String? currPrefix,
    Set<String>? priorEntries,
  }) {
    Iterable<TagDBEntry> filter(Iterable<TagDBEntry> before) =>
        priorEntries != null && currPrefix != null
            ? before
                .where((e) => !priorEntries.contains("$currPrefix ${e.name}"))
            : before;

    return filter(db.getSublist(currText, charactersToBacktrack: 1));
  }

  @override
  void initState() {
    super.initState();
    mts = sh.MetaTagSearchData.fromSearchString(widget.initialValue ?? "");
    searchController = SearchController()
      // ..text = currentText = (widget.initialValue ?? "");
      ..text =
          currentText = mts.removeMatchedMetaTags(widget.initialValue ?? "");
  }

  // #region Search Bar Callbacks
  VoidCallback? _genCallback(
    String output,
    void Function()? onTap,
    SearchController? controller,
  ) =>
      onTap ??
      (controller != null
          ? () => controller.isAttached ? controller.closeView(output) : ""
          : null);

  void _sbcCloseAndUnfocus() {
    if (searchController.isAttached && searchController.isOpen) {
      searchController.closeView(currentText);
    }
  }

  void _sbcOnSubmitted(String s) {
    setState(() {
      currentText = s;
    });
    _sbcCloseAndUnfocus();
    Provider.of<ManagedPostCollectionSync>(context, listen: false)
        .launchOrReloadSearch(
      PostSearchQueryRecord(
        limit: SearchView.i.postsPerPage,
        page: "1",
        tags: "$s${mts.toString()}",
      ),
    );
    widget.onSelected?.call();
  }
  // #endregion Search Bar Callbacks
}

// const _modifierDropdownItems = <DropdownMenuItem<sh.Modifier>>[
//   DropdownMenuItem(value: sh.Modifier.add, child: Text("+")),
//   DropdownMenuItem(value: sh.Modifier.remove, child: Text("-")),
//   DropdownMenuItem(value: sh.Modifier.or, child: Text("~")),
// ];
// const _modifierDropdownItemsFull = <DropdownMenuItem<sh.Modifier?>>[
//   DropdownMenuItem(value: sh.Modifier.add, child: Text("+")),
//   DropdownMenuItem(value: sh.Modifier.remove, child: Text("-")),
//   DropdownMenuItem(value: sh.Modifier.or, child: Text("~")),
//   DropdownMenuItem(value: null, child: Icon(Icons.close)),
// ];
// const _modifierDropdownEntries = <DropdownMenuEntry<sh.Modifier>>[
//   DropdownMenuEntry(value: sh.Modifier.add, label: "+"),
//   DropdownMenuEntry(value: sh.Modifier.remove, label: "-"),
//   DropdownMenuEntry(value: sh.Modifier.or, label: "~"),
// ];
const _modifierDropdownEntriesFull = <DropdownMenuEntry<sh.Modifier?>>[
  DropdownMenuEntry(
    value: sh.Modifier.add,
    label: "+",
    labelWidget: SizedBox(
      width: 12,
      child: Text(
        "+",
        textWidthBasis: TextWidthBasis.parent,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ),
  DropdownMenuEntry(
    value: sh.Modifier.remove,
    label: "-",
    labelWidget: SizedBox(
      width: 12,
      child: Text(
        "-",
        textWidthBasis: TextWidthBasis.parent,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ),
  DropdownMenuEntry(
    value: sh.Modifier.or,
    label: "~",
    labelWidget: SizedBox(
      width: 12,
      child: Text(
        "~",
        textWidthBasis: TextWidthBasis.parent,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ),
  DropdownMenuEntry(
    value: null,
    label: "X",
    labelWidget: SizedBox(
      width: 12,
      child: Text(
        "X",
        textWidthBasis: TextWidthBasis.parent,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ),
];
const _orderDropdownEntries = [
  DropdownMenuEntry(
    value: sh.Order.change,
    label: "order:${sh.Order.changeSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.changeAsc,
    label: "order:${sh.Order.changeAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.changeDesc,
    label: "order:${sh.Order.changeDescSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.commentBumped,
    label: "order:${sh.Order.commentBumpedSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.commentBumpedAsc,
    label: "order:${sh.Order.commentBumpedAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.commentCount,
    label: "order:${sh.Order.commentCountSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.commentCountAsc,
    label: "order:${sh.Order.commentCountAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.duration,
    label: "order:${sh.Order.durationSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.durationAsc,
    label: "order:${sh.Order.durationAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.favCount,
    label: "order:${sh.Order.favCountSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.favCountAsc,
    label: "order:${sh.Order.favCountAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.fileSize,
    label: "order:${sh.Order.fileSizeSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.fileSizeAsc,
    label: "order:${sh.Order.fileSizeAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.id,
    label: "order:${sh.Order.idSuffix}",
  ),
  DropdownMenuEntry(
    value: null,
    label: "order:${sh.Order.idDescSuffix}",
    labelWidget: Text(
      "order:${sh.Order.idDescSuffix} (Default)",
      style: _WSearchBarState.noOutputStyle,
    ),
  ),
  DropdownMenuEntry(
    value: sh.Order.score,
    label: "order:${sh.Order.scoreSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.scoreAsc,
    label: "order:${sh.Order.scoreAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.tagCount,
    label: "order:${sh.Order.tagCountSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.tagCountAsc,
    label: "order:${sh.Order.tagCountAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.artTags,
    label: "order:${sh.Order.artTagsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.artTagsAsc,
    label: "order:${sh.Order.artTagsAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.charTags,
    label: "order:${sh.Order.charTagsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.charTagsAsc,
    label: "order:${sh.Order.charTagsAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.copyTags,
    label: "order:${sh.Order.copyTagsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.copyTagsAsc,
    label: "order:${sh.Order.copyTagsAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.genTags,
    label: "order:${sh.Order.genTagsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.genTagsAsc,
    label: "order:${sh.Order.genTagsAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.invTags,
    label: "order:${sh.Order.invTagsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.invTagsAsc,
    label: "order:${sh.Order.invTagsAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.lorTags,
    label: "order:${sh.Order.lorTagsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.lorTagsAsc,
    label: "order:${sh.Order.lorTagsAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.metaTags,
    label: "order:${sh.Order.metaTagsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.metaTagsAsc,
    label: "order:${sh.Order.metaTagsAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.specTags,
    label: "order:${sh.Order.specTagsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.specTagsAsc,
    label: "order:${sh.Order.specTagsAscSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.mPixels,
    label: "order:${sh.Order.mPixelsSuffix}",
  ),
  DropdownMenuEntry(
    value: sh.Order.mPixelsAsc,
    label: "order:${sh.Order.mPixelsAscSuffix}",
  ),
];
