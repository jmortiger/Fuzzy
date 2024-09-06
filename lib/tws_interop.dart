import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/log_management.dart' as lm;

// ignore: unnecessary_late
late final _logger = lm.generateLogger("TwsInterop").logger;

class SavedSearch {
  final String title;
  String get a => title;
  final int pageNumber;
  int get b => pageNumber;
  final List<String> tags;
  List<String> get c => tags;
  final int lastSearchedPostId;
  int get d => lastSearchedPostId;
  final int lastUpdatedPostId;
  int get e => lastUpdatedPostId;
  final int newPostsSinceLastSearch;
  int get f => newPostsSinceLastSearch;

  SavedSearch({
    required this.title,
    required this.pageNumber,
    required this.tags,
    required this.lastSearchedPostId,
    required this.lastUpdatedPostId,
    required this.newPostsSinceLastSearch,
  });

  SavedSearch copyWith({
    String? title,
    int? pageNumber,
    List<String>? tags,
    int? lastSearchedPostId,
    int? lastUpdatedPostId,
    int? newPostsSinceLastSearch,
  }) =>
      SavedSearch(
        title: title ?? this.title,
        pageNumber: pageNumber ?? this.pageNumber,
        tags: tags ?? this.tags,
        lastSearchedPostId: lastSearchedPostId ?? this.lastSearchedPostId,
        lastUpdatedPostId: lastUpdatedPostId ?? this.lastUpdatedPostId,
        newPostsSinceLastSearch:
            newPostsSinceLastSearch ?? this.newPostsSinceLastSearch,
      );
  SavedSearch copyWithJsonName({
    String? a,
    int? b,
    List<String>? c,
    int? d,
    int? e,
    int? f,
  }) =>
      SavedSearch(
        title: a ?? this.a,
        pageNumber: b ?? this.b,
        tags: c ?? this.c,
        lastSearchedPostId: d ?? this.d,
        lastUpdatedPostId: e ?? this.e,
        newPostsSinceLastSearch: f ?? this.f,
      );

  static List<SavedSearch> fromRawJson(String str) =>
      (json.decode(str) as List).map((e) => SavedSearch.fromJson(e)).toList();

  String toRawJson() => json.encode(toJson());

  factory SavedSearch.fromJson(Map<String, dynamic> json) => SavedSearch(
        title: json["a"],
        pageNumber: json["b"],
        tags: List<String>.from(json["c"].map((x) => x)),
        lastSearchedPostId: json["d"],
        lastUpdatedPostId: json["e"],
        newPostsSinceLastSearch: json["f"],
      );

  Map<String, dynamic> toJson() => {
        "a": title,
        "b": pageNumber,
        "c": List<dynamic>.from(tags.map((x) => x)),
        "d": lastSearchedPostId,
        "e": lastUpdatedPostId,
        "f": newPostsSinceLastSearch,
      };
  SavedElementRecord toSer({
    Map<String, String>? patterns,
    String delimiter = ": ",
    bool addOrigToTitle = false,
    bool doNotFormatNonMatchingTitles = true,
    bool overridePoolParent = false,
    String? poolParent,
  }) {
    final String mainData = tags.fold(
          null,
          (previousValue, element) =>
              "${previousValue != null ? "$previousValue " : ""}$element",
        ) ??
        "";
    final isPoolSearch = "pool:".matchAsPrefix(mainData) != null;
    final poolFallback = isPoolSearch ? poolParent : null;
    final titleSegmented = title.split(delimiter);
    final titleSegmentsFormatted = <String>[];
    for (var i = 0; i < titleSegmented.length ~/ 2; i++) {
      titleSegmentsFormatted.add(!doNotFormatNonMatchingTitles ||
              (patterns?[titleSegmented[i * 2]]?.isNotEmpty ?? false)
          ? titleSegmented.elementAtOrNull(i * 2 + 1) ?? titleSegmented[i * 2]
          : title);
    }
    if (titleSegmented.length.isOdd) {
      titleSegmentsFormatted.add(titleSegmented.last);
    }
    return (
      mainData: mainData,
      title:
          "${titleSegmentsFormatted.isNotEmpty ? titleSegmentsFormatted.reduce((acc, e) => "$acc$e") : title}"
          "${(addOrigToTitle ? " <= $title" : "")}",
      parent: isPoolSearch && (overridePoolParent || patterns == null)
          ? poolParent
          : patterns == null
              ? poolFallback
              : patterns[titleSegmented.first] ?? poolFallback,
      uniqueId: null,
    );
  }

  static Map<String, String>? format(String? pattern) {
    if (pattern == null) return null; //"[${RegExpExt.whitespaceCharacters}]"
    return pattern.split(RegExp("[,\n]")).fold(
      <List<String>>[],
      (previousValue, element) {
        if (previousValue.isEmpty || previousValue.last.length == 2) {
          previousValue.add([element]);
        } else {
          previousValue.last.add(element);
        }
        return previousValue;
      },
    ).fold(
      <String, String>{},
      (previousValue, element) {
        previousValue![element.first] = element.last;
        return previousValue;
      },
    );
  }
}

Future<List<SavedSearch>?> showImportElementEditDialogue(BuildContext context) {
  return showDialog<List<SavedSearch>>(
    context: context,
    builder: (context) {
      var data = "";
      return AlertDialog(
        title: const Text("Enter .tws2 file contents below"),
        content: Column(
          children: [
            TextField(
              onChanged: (value) => data = value,
              // controller: defaultSelection(data),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              (jsonDecode(data) as List).mapAsList(
                (e, _, __) => SavedSearch.fromJson(e),
              ),
            ),
            child: const Text("Accept"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      );
    },
  );
}

Future<List<SavedElementRecord>?> showEnhancedImportElementEditDialogue(
    BuildContext context) {
  return showDialog<List<SavedElementRecord>>(
    context: context,
    builder: (context) {
      var data = "";
      String? patterns, delimiter;
      return AlertDialog(
        title: const Text("Enter .tws2 file contents below"),
        content: Column(
          children: [
            TextField(
              onChanged: (value) => data = value,
            ),
            const Text("Enter pattern delimiter"),
            TextField(
              onChanged: (value) => delimiter = value,
            ),
            const Text("Enter replacement patterns (delimit w/,)"),
            TextField(
              onChanged: (value) {
                _logger.info("New value = $value");
                patterns = value;
              },
              textInputAction: TextInputAction.none,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              (jsonDecode(data) as List).mapAsList(
                (e, _, __) => SavedSearch.fromJson(e).toSer(
                  patterns: SavedSearch.format(patterns),
                  delimiter: delimiter ?? ": ",
                ),
              ),
            ),
            child: const Text("Accept"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      );
    },
  );
}

Future<List<SavedElementRecord>?> showBestImportElementEditDialogue(
    BuildContext context) {
  return FilePicker.platform
      .pickFiles(
    dialogTitle: "Select .tws2 or .tws2.txt file",
    allowedExtensions: ["tws2", "txt"],
    type: FileType.custom,
  )
      .then((result) {
    Future<String?> f;
    if (result == null) {
      // User canceled the picker
      return null;
    } else {
      if (result.files.single.readStream != null) {
        f = utf8.decodeStream(result.files.single.readStream!);
      } else if (result.files.single.bytes != null) {
        f = Future.sync(() => utf8.decode(result.files.single.bytes!.toList()));
      } else {
        try {
          f = (File(result.files.single.path!).readAsString()
                  as Future<String?>)
              .onError((e, s) {
            _logger.severe("Failed import", e, s);
            return null;
          });
        } catch (e, s) {
          _logger.severe("Failed import", e, s);
          return null;
        }
      }
    }
    f.onError((e, s) {
      _logger.severe("Failed import", e, s);
      return null;
    });
    return f.then(
      (data) => data != null
          ? showDialog<List<SavedElementRecord>>(
              context: context,
              builder: (context) {
                String? patterns, delimiter, poolParent = "Pools";
                bool doNotFormatNonMatchingTitles = true;
                bool overridePoolParent = true;
                final preElements = SavedSearch.fromRawJson(data);
                Iterable<SavedSearchData> getPostElements() => preElements
                    .map((e) => e.toSer(
                          patterns: SavedSearch.format(patterns),
                          delimiter: delimiter ?? ": ",
                          addOrigToTitle: true,
                          doNotFormatNonMatchingTitles:
                              doNotFormatNonMatchingTitles,
                          poolParent: poolParent,
                          overridePoolParent: overridePoolParent,
                        ))
                    .map((value) => SavedSearchData.fromTagsString(
                          searchString: value.mainData,
                          title: value.title,
                          uniqueId: value.uniqueId ?? "",
                          parent: value.parent ?? "",
                        ));
                var currElementsCache = getPostElements().toList();
                var currTilesCache = _buildParentedView(
                    SavedDataE6.makeParented(currElementsCache));
                updateCache() {
                  currElementsCache = getPostElements().toList();
                  currTilesCache = _buildParentedView(
                      SavedDataE6.makeParented(currElementsCache));
                }

                // Future<List<Widget>>? tilesFuture;
                // Future<List<SavedSearchData>>? elementsFuture;
                // (Future<List<Widget>>, Future<List<SavedSearchData>>)
                //     updateCacheAsync(void Function(void Function()) setState) {
                //   elementsFuture =
                //       compute((void v) => getPostElements().toList(), null);
                //   currElementsCache = getPostElements().toList();
                //   currTilesCache = _buildParentedView(
                //       SavedDataE6.makeParented(currElementsCache));
                // }

                return AlertDialog(
                  content: SizedBox(
                    width: double.maxFinite,
                    height: double.maxFinite,
                    child: SingleChildScrollView(
                      child: StatefulBuilder(
                        builder: (context, setState) => Column(
                          children: [
                            ExpansionTile(
                              maintainState: true,
                              title: const Text("Preview"),
                              subtitle:
                                  Text("${preElements.length} elements added"),
                              children: currTilesCache,
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                  labelText: "Enter pattern delimiter"),
                              onChanged: (value) => setState(() {
                                delimiter = value;
                                updateCache();
                              }),
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                  labelText:
                                      "Enter replacement patterns (delimit w/,)"),
                              onSubmitted: (value) {
                                _logger.info("New value = $value");
                                setState(() {
                                  patterns = value;
                                  updateCache();
                                });
                              },
                              // onChanged: (value) {
                              //   _logger.info("New value = $value");
                              //   setState(() {
                              //     patterns = value;
                              //     updateCache();
                              //   });
                              // },
                              textInputAction: TextInputAction.none,
                            ),
                            SwitchListTile(
                              value: doNotFormatNonMatchingTitles,
                              onChanged: (value) => setState(() {
                                doNotFormatNonMatchingTitles = value;
                                updateCache();
                              }),
                              title: const Text(
                                  "Do Not Format Non-matching Titles"),
                            ),
                            SwitchListTile(
                              value: overridePoolParent,
                              onChanged: (value) => setState(() {
                                overridePoolParent = value;
                                updateCache();
                              }),
                              title: const Text("Override Pool Parent"),
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                  labelText: "Pool Parent"),
                              onChanged: (value) => setState(() {
                                poolParent = value;
                                updateCache();
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        (jsonDecode(data) as List).mapAsList(
                          (e, _, __) => SavedSearch.fromJson(e).toSer(
                            patterns: SavedSearch.format(patterns),
                            delimiter: delimiter ?? ": ",
                            doNotFormatNonMatchingTitles:
                                doNotFormatNonMatchingTitles,
                            poolParent: poolParent,
                            overridePoolParent: overridePoolParent,
                          ),
                        ),
                      ),
                      child: const Text("Accept"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ],
                );
              },
            )
          : null,
    );
  });
} //a,artist,t,tags,s,species,c,character,Set,set,*Set,set,* Set,set

List<Widget> _buildParentedView(
    /* BuildContext context,  */ List<List<SavedEntry>> parentedCollection) {
  return /* ListView(
    children:  */
      parentedCollection.mapAsList(
    (e, index, list) => ExpansionTile(
      // key: PageStorageKey(e),
      // maintainState: true,
      title: Text.rich(
        TextSpan(
          text: e.first.parent,
          children: [
            TextSpan(
                text: " (${e.length} entries)",
                style: const DefaultTextStyle.fallback().style.copyWith(
                      color: const Color.fromARGB(255, 80, 80, 80),
                    )),
          ],
        ),
      ),
      dense: true,
      children: e.mapAsList(
        (e2, i2, l2) => _buildSavedEntry(
          entry: e2,
          // index: (parentIndex: index, childIndex: i2),
        ),
      ),
    ),
    // ),
  );
}

Widget _buildSavedEntry<T extends SavedEntry>({
  required T entry,
  // ({int parentIndex, int childIndex})? index,
}) {
  // final r = index != null ? entry : null;
  return StatefulBuilder(
    builder: (context, setState) {
      // void l() {
      //   selected.removeListener(l);
      //   setState(() {});
      // }

      // selected.addListener(l);
      return ListTile(
        // leading: switch (entry.runtimeType) {
        //   SavedSearchData => const Text("S"),
        //   SavedPoolData => const Text("P"),
        //   SavedSetData => const Text("s"),
        //   _ => throw UnsupportedError("not supported"),
        // },
        leading: /* r != null && selected.isNotEmpty
              ? Checkbox(
                  value: selected.contains(r),
                  onChanged: (value) =>
                      value! ? selected.add(r) : selected.remove(r),
                )
              :  */
            switch (entry.runtimeType) {
          SavedSearchData => const Text("S"),
          SavedPoolData => const Text("P"),
          SavedSetData => const Text("s"),
          _ => throw UnsupportedError("not supported"),
        },
        title: Text(entry.title),
        subtitle: Text(entry.searchString),
        // onLongPress: r != null
        //     ? () =>
        //         selected.contains(r) ? selected.remove(r) : selected.add(r)
        //     : null,
        // onTap: () => showEntryDialog(context: context, entry: entry)
        //     .then((v) => processEntryDialogSelection(entry, v)),
      );
    },
  );
}
