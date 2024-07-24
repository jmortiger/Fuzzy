import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:j_util/j_util_full.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

late final lRecord = lm.genLogger("TwsInterop");
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;
// #endregion Logger

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

  factory SavedSearch.fromRawJson(String str) =>
      SavedSearch.fromJson(json.decode(str));

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
        title: title,
        parent: patterns == null ? null : patterns[title.split(delimiter).first],
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
                logger.info("New value = $value");
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
