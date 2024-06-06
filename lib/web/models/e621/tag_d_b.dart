import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';

class TagDB {
  final Set<String> tagSet;
  final List<TagDBEntryFull> tags;
  final Map<String, (TagCategory, int)> tagsMap;
  final PriorityQueue<TagDBEntryFull> tagsByPopularity;

  /// This will likely take awhile. Try async.
  TagDB({
    required this.tagSet,
    required this.tags,
    required this.tagsMap,
    required this.tagsByPopularity,
  });
  TagDB.fromEntries(List<TagDBEntryFull> entries)
      : tagSet = Set<String>.unmodifiable(
            entries.mapTo((elem, index, list) => elem.name)),
        tags = entries,
        tagsMap = Map.unmodifiable(
            {for (var e in entries) e.name: (e.category, e.postCount)}),
        tagsByPopularity = PriorityQueue(entries);
  factory TagDB.fromCsvString(String csv) =>
      TagDB.fromEntries(((csv.split("\n")..removeAt(0))..removeLast())
          .mapAsList((e, index, list) {
        var t = e.split(",");
        if (t.length != 4) print("TROUBLE: $e -> $t");
        if (e.contains('"')) {
          t = [
            t[0],
            e.substring(e.indexOf('"'), e.lastIndexOf('"')),
            t[t.length - 2],
            t.last
          ];
        }
        if (t.length != 4) print("STILL TROUBLE: $e -> $t");
        if (t.length == 5) t = [t[0], t[1] + t[2], t[3], t[4]];
        try {
          return TagDBEntryFull(
              id: int.parse(t[0]),
              name: t[1],
              category: TagCategory.values[int.parse(t[2])],
              postCount: int.parse(t[3]));
        } catch (e) {
          return TagDBEntryFull(
              id: int.parse(t[0]),
              name: t[1],
              category: TagCategory.values[int.parse(t[2])],
              postCount: int.parse(t[3]));
        }
      }));
  static Future<TagDB> makeFromCsvString(String csv) async =>
      Future.microtask(() => TagDB.fromCsvString(csv));
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

/// TODO: Inherit from other
class TagDBEntryFull implements Comparable<TagDBEntryFull> {
  final int id;
  final String name;
  final TagCategory category;
  final int postCount;

  TagDBEntryFull({
    required this.id,
    required this.name,
    required this.category,
    required this.postCount,
  });
  JsonMap toJson() => {
        "id": id,
        "name": name,
        "category": category.index,
        "post_count": postCount,
      };
  factory TagDBEntryFull.fromJson(JsonMap json) => TagDBEntryFull(
        id: json["id"] as int,
        name: json["name"] as String,
        category: json["category"] as TagCategory,
        postCount: json["post_count"] as int,
      );

  @override
  // int compareTo(TagDBEntryFull other) => other.postCount - postCount;
  int compareTo(TagDBEntryFull other) =>
      (other.postCount - (other.postCount % 5)) - (postCount - postCount % 5);
}

class TagDBEntry implements Comparable<TagDBEntry> {
  final String name;
  final TagCategory category;
  final int postCount;

  TagDBEntry({
    required this.name,
    required this.category,
    required this.postCount,
  });
  JsonMap toJson() => {
        "name": name,
        "category": category.index,
        "post_count": postCount,
      };
  factory TagDBEntry.fromJson(JsonMap json) => TagDBEntry(
        name: json["name"] as String,
        category: json["category"] as TagCategory,
        postCount: json["post_count"] as int,
      );
  factory TagDBEntry.fromFull(TagDBEntryFull entry) => TagDBEntry(
        name: entry.name,
        category: entry.category,
        postCount: entry.postCount,
      );

  @override
  // int compareTo(TagDBEntry other) => other.postCount - postCount;
  int compareTo(TagDBEntry other) =>
      (other.postCount - (other.postCount % 5)) - (postCount - postCount % 5);
}

enum TagCategory {
  /// 0
  general,

  /// 1
  artist,

  /// 2; WHY
  _error,

  /// 3
  copyright,

  /// 4
  character,

  /// 5
  species,

  /// 6
  invalid,

  /// 7
  meta,

  /// 8
  lore;
}
