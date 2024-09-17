import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/e621_models.dart' show TagCategory;

class TagDB {
  final Set<String> tagSet;
  final List<TagDBEntry /* Full */ > tags;
  final Map<String, (TagCategory, int)> tagsMap;
  final PriorityQueue<TagDBEntry /* Full */ > tagsByPopularity;
  // final List<PriorityQueue<TagDBEntry/* Full */>> tagsByFirstCharsThenPopularity;
  final CustomPriorityQueue<TagDBEntry /* Full */ > tagsByString;
  final Map<String, (int, int)> _startEndOfChar = <String, (int, int)>{};
  (int, int) getCharStartAndEnd(String character) =>
      _startEndOfChar[character[0]] ??
      (_startEndOfChar[character[0]] = (
        tagsByString.queue
            .indexWhere((element) => character[0] == element.name[0]),
        tagsByString.queue
            .lastIndexWhere((element) => character[0] == element.name[0])
      ));

  /// This will likely take awhile. Try async.
  TagDB({
    required this.tagSet,
    required this.tags,
    required this.tagsMap,
    required this.tagsByPopularity,
    // required this.tagsByFirstCharsThenPopularity,
    required this.tagsByString,
  });
  TagDB.fromEntries(List<TagDBEntryFull> entries)
      : tagSet = Set<String>.unmodifiable(
            entries.mapTo((elem, index, list) => elem.name)),
        tags = entries,
        tagsMap = Map.unmodifiable(
            {for (var e in entries) e.name: (e.category, e.postCount)}),
        tagsByPopularity = PriorityQueue(entries),
        tagsByString = CustomPriorityQueue(
            entries,
            (a, b) => a.name.compareTo(b
                .name)) /* ,
        tagsByFirstCharsThenPopularity = entries..sort((a, b) => a.name.compareTo(b.name))..reduceToType((accumulator, elem, index, list){
          
        }, ("")) */
  ;
  factory TagDB.fromCsvString(String csv) =>
      TagDB.fromEntries(fromCsvStringFull(csv));
  static Future<TagDB> makeFromCsvString(String csv) async =>
      compute((String csv) => TagDB.fromCsvString(csv), csv,
          debugLabel: "Make TagDB From CSV String");
  // Future.microtask(() => TagDB.fromCsvString(csv));
  // JsonMap toJson() => {
  //   "id": id,
  //   "name": name,
  //   "category": category.index,
  //   "post_count": post_count,
  // };
  // factory TagDBEntry.fromJson(JsonMap json) => TagDBEntry(
  //   id: json["id"] as int,
  //   name: json["name"] as String,
  //   category: json["category"] as TagCategory,
  //   post_count: json["post_count"] as int,
  // );
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

({
  String name,
  TagCategory category,
  int postCount,
}) parseTagEntryCsvString(String e) {
  final t = _rootParse(e);
  return (
    // id: int.parse(t[0]),
    name: t[1],
    category: TagCategory.values[int.parse(t[2])],
    postCount: int.parse(t[3])
  );
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
    .map((e) => TagDBEntry._fromRecord(parseTagEntryCsvString(e)))
    .toList();
Future<List<TagDBEntry>> makeFromCsvString(String csv) async =>
    compute(fromCsvString, csv,
        debugLabel: "Make List From CSV String");
Future<List<T>> makeTypeFromCsvString<T extends TagDBEntry>(String csv) =>
    switch (T) {
      TagDBEntryFull => makeFromCsvStringFull(csv),
      TagDBEntry => makeFromCsvString(csv),
      Type() => throw UnimplementedError(),
    } as Future<List<T>>;
List<T> typeFromCsvString<T extends TagDBEntry>(String csv) => switch (T) {
      TagDBEntryFull => fromCsvStringFull(csv),
      TagDBEntry => fromCsvString(csv),
      Type() => throw UnimplementedError(),
    } as List<T>;

final class TagDBEntryFull extends TagDBEntry {
  final int id;

  const TagDBEntryFull({
    required this.id,
    required super.name,
    required super.category,
    required super.postCount,
  });
  TagDBEntryFull._fromRecord(
      ({int id, String name, TagCategory category, int postCount}) r)
      : this(
          id: r.id,
          name: r.name,
          category: r.category,
          postCount: r.postCount,
        );
  TagDBEntryFull._fromJson({
    required this.id,
    required json,
  }) : super.fromJson(json);
  @override
  JsonMap toJson() => super.toJson()..addAll({"id": id});
  factory TagDBEntryFull.fromJson(JsonMap json) => TagDBEntryFull._fromJson(
        id: json["id"] as int,
        json: json,
      );
}

final class TagDBEntry implements Comparable<TagDBEntry> {
  final String name;
  final TagCategory category;
  final int postCount;

  const TagDBEntry({
    required this.name,
    required this.category,
    required this.postCount,
  });
  TagDBEntry._fromRecord(({String name, TagCategory category, int postCount}) r)
      : this(
          name: r.name,
          category: r.category,
          postCount: r.postCount,
        );
  JsonMap toJson() => {
        "name": name,
        "category": category.index,
        "post_count": postCount,
      };
  TagDBEntry.fromJson(JsonMap json)
      : name = json["name"] as String,
        category = json["category"] as TagCategory,
        postCount = json["post_count"] as int;
  /* const  */ TagDBEntry.fromFull(TagDBEntryFull entry)
      : name = entry.name,
        category = entry.category,
        postCount = entry.postCount;

  @override
  // int compareTo(TagDBEntry other) => other.postCount - postCount;
  int compareTo(TagDBEntry other) =>
      (other.postCount - (other.postCount % 5)) - (postCount - postCount % 5);
}

class TagSearchModel {
  final List<TagSearchEntry> tags;

  TagSearchModel({required this.tags});

  factory TagSearchModel.fromJson(JsonMap json) => TagSearchModel(
      tags: json["tags"] != null ? [] : (json as List).cast<TagSearchEntry>());

  dynamic toJson() =>
      tags.isEmpty ? {"tags": []} : json.decode(tags.toString());
}

/// TODO: Implements TagDBEntry
class TagSearchEntry {
  /// <numeric tag id>,
  final int id;

  /// <tag display name>,
  final String name;

  /// <# matching visible posts>,
  final int postCount;

  /// <space-delimited list of tags>,
  final List<String> relatedTags;

  /// <ISO8601 timestamp>,
  final DateTime relatedTagsUpdatedAt;

  /// <numeric category id>,
  final TagCategory category;

  /// <boolean>,
  final bool isLocked;

  /// <ISO8601 timestamp>,
  final DateTime createdAt;

  /// <ISO8601 timestamp>
  final DateTime updatedAt;

  TagSearchEntry({
    required this.id,
    required this.name,
    required this.postCount,
    required this.relatedTags,
    required this.relatedTagsUpdatedAt,
    required this.category,
    required this.isLocked,
    required this.createdAt,
    required this.updatedAt,
  });
  factory TagSearchEntry.fromJson(JsonMap json) => TagSearchEntry(
        id: json["id"] as int,
        name: json["name"] as String,
        postCount: json["post_count"] as int,
        relatedTags: (json["related_tags"] as List).cast<String>(),
        relatedTagsUpdatedAt: json["related_tags_updated_at"] as DateTime,
        category: json["category"] as TagCategory,
        isLocked: json["is_locked"] as bool,
        createdAt: json["created_at"] as DateTime,
        updatedAt: json["updated_at"] as DateTime,
      );
  JsonMap toJson() => {
        "id": id,
        "name": name,
        "post_count": postCount,
        "related_tags": relatedTags,
        "related_tags_updated_at": relatedTagsUpdatedAt,
        "category": category,
        "is_locked": isLocked,
        "created_at": createdAt,
        "updated_at": updatedAt,
      };
}
