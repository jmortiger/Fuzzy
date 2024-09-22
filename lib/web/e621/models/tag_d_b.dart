import 'dart:convert';
import 'dart:math';

import 'package:e621/e621_models.dart'
    show Tag, TagCategory, TagDbEntry, TagDbEntrySlim;
import 'package:flutter/foundation.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util_full.dart';
import 'package:string_similarity/string_similarity.dart';

class TagDB {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("TagDB").logger;
  final Set<String> tagSet;
  final List<TagDBEntry /* Full */ > tags;
  final Map<String, (TagCategory, int)> tagsMap;
  // final PriorityQueueFlat<TagDBEntry /* Full */ > tagsByPopularity;
  final List<TagDBEntry /* Full */ > tagsByPopularity;
  // final List<PriorityQueue<TagDBEntry/* Full */>> tagsByFirstCharsThenPopularity;
  /// In alphabetical order
  final CustomPriorityQueue<TagDBEntry /* Full */ > tagsByString;
  final _startEndOfChar = <String, (int startIndex, int endIndex)>{};
  (int startIndex, int endIndex) getCharStartAndEnd(String character) =>
      _startEndOfChar[character[0]] ??= (
        tagsByString.queue.indexWhere((e) => character[0] == e.name[0]),
        tagsByString.queue.lastIndexWhere((e) => character[0] == e.name[0])
      );

  /// If there are no locations that perfectly match [query],
  /// [allowedVariance] & [charactersToBacktrack] are fallbacks.
  ///
  /// [charactersToBacktrack] searches for [query] without
  /// the last [charactersToBacktrack] characters.
  ///
  /// [allowedVariance] searches for the 1st and last string that has a
  /// [StringSimilarity.compareTwoStrings] value >= [allowedVariance].
  Iterable<TagDBEntry> getSublist(
    String query, {
    double? allowedVariance,
    int charactersToBacktrack = 0,
  }) {
    if (query.isEmpty) return const Iterable<TagDBEntry>.empty();
    var (start, end) = getCharStartAndEnd(query[0]);
    if (start < 0 || end < 0) return const Iterable<TagDBEntry>.empty();
    logger.finer("range For ${query[0]}: $start - $end");
    if (query.length == 1) {
      return start == end
          ? [tagsByString.queue[start]]
          : tagsByString.queue.getRange(start, end);
    }
    var t = tagsByString.queue.getRange(start, end).toList(growable: false);
    var comp = (TagDBEntry e) => e.name.startsWith(query);
    start = t.indexWhere(comp);
    if (start < 0) {
      if (charactersToBacktrack < 1 && !(allowedVariance?.isFinite ?? false)) {
        return const Iterable<TagDBEntry>.empty();
      } else if (charactersToBacktrack < 1) {
        comp = (e) => e.name.similarityTo(query) >= allowedVariance!;
      } else {
        charactersToBacktrack = min(query.length - 1, charactersToBacktrack);
        final querySub = query.substring(0, charactersToBacktrack);
        comp = (e) => e.name.startsWith(querySub);
      }
      start = t.indexWhere(comp);
      if (start < 0) return const Iterable<TagDBEntry>.empty();
    }
    end = t.lastIndexWhere(comp);
    if (end < 0) {
      logger.warning("getSublist: SHOULD NEVER BE ENTERED");
      if (charactersToBacktrack < 1 && !(allowedVariance?.isFinite ?? false)) {
        return const Iterable<TagDBEntry>.empty();
      } else if (charactersToBacktrack < 1) {
        comp = (e) => e.name.similarityTo(query) >= allowedVariance!;
      } else {
        charactersToBacktrack = min(query.length - 1, charactersToBacktrack);
        final querySub = query.substring(0, charactersToBacktrack);
        comp = (e) => e.name.startsWith(querySub);
      }
      end = t.lastIndexWhere(comp);
      if (end < 0) return const Iterable<TagDBEntry>.empty();
    }
    return (end == start) ? [t[start]] : t.getRange(start, end);
  }

  /// This will likely take awhile. Try async.
  TagDB({
    required this.tagSet,
    required this.tags,
    required this.tagsMap,
    required this.tagsByPopularity,
    required this.tagsByString,
  });
  TagDB.fromEntries(List<TagDBEntryFull> entries)
      : tagSet = Set<String>.unmodifiable(
            entries.mapTo((elem, index, list) => elem.name)),
        tags = entries,
        tagsMap = Map.unmodifiable(
            {for (var e in entries) e.name: (e.category, e.postCount)}),
        tagsByPopularity = entries.sublist(0)
          ..sort(coarseComparator), //PriorityQueueFlat(entries),
        tagsByString =
            CustomPriorityQueue(entries, (a, b) => a.name.compareTo(b.name));

  static int coarseComparator(TagDbEntrySlim a, TagDbEntrySlim other) =>
      (other.postCount - (other.postCount % 5)) -
      (a.postCount - a.postCount % 5);
  factory TagDB.fromCsvString(String csv) =>
      TagDB.fromEntries(fromCsvStringFull(csv));
  static Future<TagDB> makeFromCsvString(String csv) async =>
      compute((String csv) => TagDB.fromCsvString(csv), csv,
          debugLabel: "Make TagDB From CSV String");
}

// #region Parse Direct
const firstLine = "id,name,category,post_count";
String _rootEncodeCsvFromRecord(
        ({
          int id,
          String name,
          TagCategory category,
          int postCount,
        }) e) =>
    "${e.id},${e.name},${e.category.index},${e.postCount}";
String _rootEncodeCsvFromEntry(TagDBEntryFull e) =>
    "${e.id},${e.name},${e.category.index},${e.postCount}";
String encodeCsvString(List<TagDBEntryFull> entries) =>
    "${entries.map((e) => _rootEncodeCsvFromEntry(e)).fold(
          firstLine,
          (acc, e) => "$acc\n$e",
        )}\n";
String encodeCsvStringFromRecords(
        List<
                ({
                  int id,
                  String name,
                  TagCategory category,
                  int postCount,
                })>
            entries) =>
    "${entries.map((e) => _rootEncodeCsvFromRecord(e)).fold(
          firstLine,
          (acc, e) => "$acc\n$e",
        )}\n";
List<String> _rootParse(String e) {
  var t = e.split(",");
  if (e.contains('"')) {
    t = [
      t[0],
      // e.substring(e.indexOf('"'), e.lastIndexOf('"')), // + 1?
      e.substring(e.indexOf('"'), e.lastIndexOf('"') + 1),
      t[t.length - 2],
      t.last
    ];
  }
  // if (t.length == 5) t = [t[0], t[1] + t[2], t[3], t[4]];
  if (t.length == 5) throw StateError("Shouldn't be possible");
  return t;
}

/* ({
  int id,
  String name,
  TagCategory category,
  int postCount,
}) */
TagDBEntryFull parseTagEntryFullCsvString(String e) {
  final t = _rootParse(e);
  return TagDBEntryFull(
      id: int.parse(t[0]),
      name: t[1],
      category: TagCategory.values[int.parse(t[2])],
      postCount: int.parse(t[3]));
}

TagDBEntry parseTagEntryCsvString(String e) {
  final t = _rootParse(e);
  return TagDBEntry(
      // id: int.parse(t[0]),
      name: t[1],
      category: TagCategory.values[int.parse(t[2])],
      postCount: int.parse(t[3]));
}
// #endregion Parse Direct

Future<String> makeEncodedCsvStringFull(List<TagDBEntryFull> entries) async =>
    compute(encodeCsvString, entries,
        debugLabel: "Make CSV String From List Full");
List<TagDBEntryFull> fromCsvStringFull(String csv) => (csv.split("\n")
      ..removeAt(0)
      ..removeLast())
    .map(parseTagEntryFullCsvString)
    // .map((e) => /* TagDBEntryFull._fromRecord( */
    //     parseTagEntryFullCsvString(e)) //)
    .toList();
Future<List<TagDBEntryFull>> makeFromCsvStringFull(String csv) async =>
    compute(fromCsvStringFull, csv,
        debugLabel: "Make List Full From CSV String");
List<TagDBEntry> fromCsvString(String csv) => (csv.split("\n")
      ..removeAt(0)
      ..removeLast())
    .map((e) => parseTagEntryCsvString(e))
    .toList();
Future<List<TagDBEntry>> makeFromCsvString(String csv) async =>
    compute(fromCsvString, csv, debugLabel: "Make List From CSV String");
Future<List<T>> makeTypeFromCsvString<T extends TagDBEntry>(String csv) =>
    switch (T) {
      const (TagDBEntryFull) => makeFromCsvStringFull(csv),
      const (TagDBEntry) => makeFromCsvString(csv),
      Type() => throw UnimplementedError(),
    } as Future<List<T>>;
List<T> typeFromCsvString<T extends TagDBEntry>(String csv) => switch (T) {
      const (TagDBEntryFull) => fromCsvStringFull(csv),
      const (TagDBEntry) => fromCsvString(csv),
      Type() => throw UnimplementedError(),
    } as List<T>;

typedef TagDBEntryFull = TagDbEntry;
typedef TagDBEntry = TagDbEntrySlim;
// final class TagDBEntryFull extends TagDbEntry {
//   const TagDBEntryFull({
//     required super.id,
//     required super.name,
//     required super.category,
//     required super.postCount,
//   });
//   TagDBEntryFull.fromJson(super.json) : super.fromJson();
//   TagDBEntryFull.fromCsv(super.csv) : super.fromCsv();
// }

// final class TagDBEntry implements Comparable<TagDBEntry> {
//   final String name;
//   final TagCategory category;
//   final int postCount;

//   const TagDBEntry({
//     required this.name,
//     required this.category,
//     required this.postCount,
//   });
//   TagDBEntry._fromRecord(({String name, TagCategory category, int postCount}) r)
//       : this(
//           name: r.name,
//           category: r.category,
//           postCount: r.postCount,
//         );
//   JsonMap toJson() => {
//         "name": name,
//         "category": category.index,
//         "post_count": postCount,
//       };
//   TagDBEntry.fromJson(JsonMap json)
//       : name = json["name"] as String,
//         category = json["category"] as TagCategory,
//         postCount = json["post_count"] as int;
//   /* const  */ TagDBEntry.fromFull(TagDBEntryFull entry)
//       : name = entry.name,
//         category = entry.category,
//         postCount = entry.postCount;

//   @override
//   // int compareTo(TagDBEntry other) => other.postCount - postCount;
//   int compareTo(TagDBEntry other) =>
//       (other.postCount - (other.postCount % 5)) - (postCount - postCount % 5);
// }

class TagSearchModel {
  final List<Tag> tags;

  TagSearchModel({required this.tags});

  factory TagSearchModel.fromJson(JsonMap json) => TagSearchModel(
      tags: json["tags"] != null ? [] : (json as List).cast<Tag>());

  dynamic toJson() =>
      tags.isEmpty ? {"tags": []} : json.decode(tags.toString());
}
