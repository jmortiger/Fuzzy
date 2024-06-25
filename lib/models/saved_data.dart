import 'dart:async' as async_lib;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';

/// Stuff like searches and sets
/// "searches": searches,
class SavedDataE6 extends ChangeNotifier with Storable<SavedDataE6> {
  // #region Singleton
  static final _instance = LateFinal<SavedDataE6>();
  static SavedDataE6 get $ =>
      _instance.isAssigned ? _instance.$ : SavedDataE6.fromStorageSync();
  static SavedDataE6 get $Copy => _instance.isAssigned
      ? _instance.$.copyWith()
      : SavedDataE6.fromStorageSync();
  static SavedDataE6? get $Safe {
    if (_instance.isAssigned) {
      return _instance.$;
    } else {
      SavedDataE6.loadFromStorageAsync();
      return null;
    }
  }

  static async_lib.FutureOr<SavedDataE6> get $Async =>
      _instance.isAssigned ? _instance.$ : SavedDataE6.loadFromStorageAsync();
  // #endregion Singleton

  static const fileName = "savedSearches.json";
  static final fileFullPath = LazyInitializer.immediate(fileFullPathInit);

  static Future<String> fileFullPathInit() async {
    print("fileFullPathInit called");
    try {
      return Platform.isWeb ? "" : "${await appDataPath.getItem()}/$fileName";
    } catch (e) {
      print("Error in SavedDataE6.fileFullPathInit():\n$e");
      return "";
    }
  }

  List<SavedPoolData> pools;
  List<SavedSetData> sets;
  List<SavedSearchData> searches;
  int get length => pools.length + sets.length + searches.length;
  SavedEntry operator [](int index) {
    if (index >= 0 && searches.length > index) {
      return searches[index];
    } else if ((index -= searches.length) < pools.length) {
      return pools[index];
    } else if ((index -= pools.length) < sets.length) {
      return sets[index];
    } else {
      throw UnsupportedError("not supported");
    }
  }

  void operator []=(int index, SavedEntry e) {
    if (index >= 0 && searches.length > index) {
      searches[index] = e as SavedSearchData;
      _save();
    } else if ((index -= searches.length) < pools.length) {
      pools[index] = e as SavedPoolData;
      _save();
    } else if ((index -= pools.length) < sets.length) {
      sets[index] = e as SavedSetData;
      _save();
    } else {
      throw UnsupportedError("not supported");
    }
  }

  SavedDataE6({
    List<SavedPoolData>? pools,
    List<SavedSetData>? sets,
    List<SavedSearchData>? searches,
  })  : pools = pools ?? <SavedPoolData>[],
        sets = sets ?? <SavedSetData>[],
        searches = searches ?? <SavedSearchData>[] {
    _instance.itemSafe ??= this;
    if (!Platform.isWeb) {
      fileFullPath.getItem().then((value) {
        initStorageAsync(value);
      });
    }
  }
  SavedDataE6 copyWith({
    List<SavedPoolData>? pools,
    List<SavedSetData>? sets,
    List<SavedSearchData>? searches,
  }) =>
      SavedDataE6(
        pools: pools ?? this.pools.toList(),
        sets: sets ?? this.sets.toList(),
        searches: searches ?? this.searches.toList(),
      );
  factory SavedDataE6.fromStorageSync() => Platform.isWeb
      ? SavedDataE6()
      : Storable.tryLoadToInstanceSync(fileFullPath.$) ?? SavedDataE6();

  static async_lib.FutureOr<SavedDataE6> loadFromStorageAsync() async =>
      // (await Storable.tryLoadToInstanceAsync<SavedDataE6>(
      SavedDataE6.fromJson(jsonDecode(await Storable.tryLoadStringAsync/* <SavedDataE6> */(
        await fileFullPath.getItem(),
      ) ?? jsonEncode(SavedDataE6().toJson()))) ??
      SavedDataE6();

  factory SavedDataE6.fromJson(Map<String, dynamic> json) => SavedDataE6(
        pools: (json["pools"] as List).mapAsList((e, index, list) => SavedPoolData.fromJson(e),),
        sets: (json["sets"] as List).mapAsList((e, index, list) => SavedSetData.fromJson(e),),
        searches: (json["searches"] as List).mapAsList((e, index, list) => SavedSearchData.fromJson(e),),
      );
  Map<String, dynamic> toJson() => {
        "pools": pools,
        "sets": sets,
        "searches": searches,
      };
  void _save() {
    notifyListeners();
    tryWriteAsync().then(
      (value) => print("Write ${value ? "successful" : "failed"}"),
    );
  }

  void _modify(void Function(SavedDataE6 instance) modifier) {
    modifier(this);
    if (this != $) {
      modifier($);
    }
    notifyListeners();
    $._save();
  }

  void addAndSaveSearch(SavedSearchData s) {
    _modify((i) => i.searches.add(s));
    _save();
  }

  void addAndSavePool(SavedPoolData p) {
    _modify((i) => i.pools.add(p));
    _save();
  }

  void addAndSaveSet(SavedSetData s) {
    _modify((i) => i.sets.add(s));
    _save();
  }

  // void editAndSave({required SavedEntry original, required SavedEntry edited}) {
  //   switch ((edited, original)) {
  //     case (SavedSearchData o, SavedSearchData orig):
  //       searches[searches.indexOf(orig)] = o;
  //       break;
  //     case (SavedPoolData o, SavedPoolData orig):
  //       pools[pools.indexOf(orig)] = o;
  //       break;
  //     case (SavedSetData o, SavedSetData orig):
  //       sets[sets.indexOf(orig)] = o;
  //       break;
  //     default:
  //       throw UnsupportedError("not supported");
  //   }
  //   // _save();
  // }
  void editAndSave<T extends SavedEntry>(
      {required T original, required T edited}) {
    switch ((edited, original)) {
      case (SavedSearchData o, SavedSearchData orig):
        _modify((i) => i.searches[i.searches.indexOf(orig)] = o);
        break;
      case (SavedPoolData o, SavedPoolData orig):
        _modify((i) => i.pools[i.pools.indexOf(orig)] = o);
        break;
      case (SavedSetData o, SavedSetData orig):
        _modify((i) => i.sets[i.sets.indexOf(orig)] = o);
        break;
      default:
        throw UnsupportedError("not supported");
    }
    // _save();
  }
}

abstract base class SavedEntry implements Comparable<SavedEntry> {
  String get searchString;
  String get title;
  const SavedEntry();
}

@immutable
abstract base class SavedListData
    implements Comparable<SavedEntry>, SavedEntry {
  @override
  final String title;
  final int id;
  final String subtitle;

  const SavedListData({
    required this.title,
    required this.id,
    this.subtitle = "",
  });

  SavedListData copyWith({
    String? title,
    int? id,
    String? subtitle,
  }) /* =>
      SavedListData(
        title: title ?? this.title,
        id: id ?? this.id,
        subtitle: subtitle ?? this.subtitle,
      ) */
  ;

  // factory SavedListData.fromJson(Map<String, dynamic> json) => SavedListData(
  //       id: json["id"],
  //       title: json["title"],
  //       subtitle: json["subtitle"],
  //     );
  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "subtitle": subtitle,
      };

  @override
  int compareTo(SavedEntry other) => switch (other) {
        SavedListData o =>
          // (id == o.id) ? title.compareTo(o.title) : id.compareTo(o.id),
          (title.compareTo(o.title) != 0)
              ? title.compareTo(o.title)
              : id.compareTo(o.id),
        _ => other.compareTo(this) * -1,
      };
}

@immutable
final class SavedSetData extends SavedListData {
  static const searchStringBase = "set:";
  @override
  String get searchString => "$searchStringBase$id";

  const SavedSetData({
    String? title,
    required super.id,
    super.subtitle = "",
  }) : super(title: title ?? "$searchStringBase$id");
  SavedSetData.fromSearchString({
    String? title,
    required String searchString,
    super.subtitle = "",
  }) : super(
            title: title ?? searchString,
            id: int.parse(searchString.replaceAll(searchStringBase, "")));

  @override
  SavedSetData copyWith({
    String? title,
    int? id,
    String? subtitle,
  }) =>
      SavedSetData(
        title: title ?? this.title,
        id: id ?? this.id,
        subtitle: subtitle ?? this.subtitle,
      );

  factory SavedSetData.fromJson(Map<String, dynamic> json) => SavedSetData(
        id: json["id"],
        title: json["title"],
        subtitle: json["subtitle"],
      );
}

@immutable
final class SavedPoolData extends SavedListData {
  static const searchStringBase = "pool:";
  @override
  String get searchString => "$searchStringBase$id";

  const SavedPoolData({
    String? title,
    required super.id,
    super.subtitle = "",
  }) : super(title: title ?? "$searchStringBase$id");
  SavedPoolData.fromSearchString({
    String? title,
    required String searchString,
    super.subtitle = "",
  }) : super(
            title: title ?? searchString,
            id: int.parse(searchString.replaceAll(searchStringBase, "")));

  @override
  SavedPoolData copyWith({
    String? title,
    int? id,
    String? subtitle,
  }) =>
      SavedPoolData(
        title: title ?? this.title,
        id: id ?? this.id,
        subtitle: subtitle ?? this.subtitle,
      );

  factory SavedPoolData.fromJson(Map<String, dynamic> json) => SavedPoolData(
        id: json["id"],
        title: json["title"],
        subtitle: json["subtitle"],
      );
}

@immutable
final class SavedSearchData extends SavedEntry {
  static String tagListToString(Iterable<String> tags, String delimiter) =>
      tags.reduce((acc, e) => "$acc$delimiter$e");
  static const e621Delimiter = " ";
  final String delimiter;
  @override
  final String title;
  final Set<String> tags;
  @override
  String get searchString => tagListToString(tags, delimiter);
  final String subtitle;
  final bool isFavorite;

  const SavedSearchData({
    required this.tags,
    this.title = "",
    this.subtitle = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  });
  SavedSearchData.withDefaults({
    required this.tags,
    String title = "",
    this.subtitle = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  }) : title = title.isEmpty ? tagListToString(tags, delimiter) : title;

  SavedSearchData.fromTagsString({
    required String tags,
    String title = "",
    this.subtitle = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  })  : title = title.isNotEmpty ? title : tags,
        tags = tags.split(delimiter).toSet();

  SavedSearchData.fromSearchString({
    required String searchString,
    String title = "",
    String subtitle = "",
    String delimiter = e621Delimiter,
    bool isFavorite = false,
  }) : this.fromTagsString(
            tags: searchString,
            delimiter: delimiter,
            isFavorite: isFavorite,
            subtitle: subtitle,
            title: title);

  SavedSearchData copyWith({
    String? title = "",
    Set<String>? tags,
    String? subtitle = "",
    bool? isFavorite = false,
    String? delimiter = "",
  }) =>
      SavedSearchData(
        tags: tags ?? this.tags,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        isFavorite: isFavorite ?? this.isFavorite,
        delimiter: delimiter ?? this.delimiter,
      );

  @override
  int compareTo(SavedEntry other) =>
      // (searchString != other.searchString)
      //   ? title.compareTo(other.title)
      //   : searchString.compareTo(other.searchString);
      (title.compareTo(other.title) != 0)
          ? title.compareTo(other.title)
          : searchString.compareTo(other.searchString);

  factory SavedSearchData.fromJson(Map<String, dynamic> json) =>
      SavedSearchData(
        title: json["title"],
        subtitle: json["subtitle"],
        isFavorite: json["isFavorite"],
        delimiter: json["delimiter"],
        tags: (json["tags"] as Set).cast<String>(),
      );
  Map<String, dynamic> toJson() => {
        "tags": tags,
        "title": title,
        "subtitle": subtitle,
        "isFavorite": isFavorite,
        "delimiter": delimiter,
      };
}
