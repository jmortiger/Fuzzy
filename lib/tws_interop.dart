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
  SavedElementRecord toSer(
          [Map<String, String>? patterns, String delimiter = ": "]) =>
      (
        mainData: tags.fold(
          null,
          (previousValue, element) =>
              "${previousValue != null ? "$previousValue " : ""}$element",
        )!,
        title: title.split(delimiter).first,
        parent:
            patterns == null ? null : patterns[title.split(delimiter).first],
        uniqueId: null,
      );
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
                  SavedSearch.format(patterns),
                  delimiter ?? ": ",
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
  return FilePicker.platform.pickFiles(/* dialogTitle: "Select .tws2 or .tws2.txt file", allowedExtensions: ["tws2", "txt"] */).then((result) {
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
                String? patterns, delimiter;
                var preElems = SavedSearch.fromRawJson(data);
                Iterable<SavedSearchData> getPostElems() => preElems
                    .map((e) => e.toSer(
                          SavedSearch.format(patterns),
                          delimiter ?? ": ",
                        ))
                    .map((value) => SavedSearchData.fromTagsString(
                          searchString: value.mainData,
                          title: value.title,
                          uniqueId: value.uniqueId ?? "",
                          parent: value.parent ?? "",
                        ));
                return AlertDialog(
                  content: SizedBox(
                    width: double.maxFinite,
                    height: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ExpansionTile(
                            title: const Text("Result"),
                            children: _buildParentedView(context,
                                SavedDataE6.makeParented(getPostElems().toList())),
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
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        (jsonDecode(data) as List).mapAsList(
                          (e, _, __) => SavedSearch.fromJson(e).toSer(
                            SavedSearch.format(patterns),
                            delimiter ?? ": ",
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
}

List< Widget > _buildParentedView(
    BuildContext context, List<List<SavedEntry>> parentedCollection) {
  return /* ListView(
    children:  */parentedCollection.mapAsList(
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
