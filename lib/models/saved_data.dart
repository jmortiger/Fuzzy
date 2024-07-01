import 'dart:async' as async_lib;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';

import 'package:fuzzy/log_management.dart' as lm;

final print = lm.genPrint("main");

/// Stuff like searches and sets
/// TODO: Redo to a completely static, no instance implementation.
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
      switch (SavedDataE6.loadFromStorageAsync()) {
        case Future<SavedDataE6> t:
          t.then((v) => _instance.$ = v);
          break;
        case SavedDataE6 t:
          _instance.$ = t;
          break;
      }
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
      return (Platform.isWeb ? "" : "${await appDataPath.getItem()}/$fileName")
        ..printMe();
    } catch (e) {
      print("Error in SavedDataE6.fileFullPathInit():\n$e");
      return "";
    }
  }

  List<SavedPoolData> pools;
  List<SavedSetData> sets;
  List<SavedSearchData> searches;
  List<SavedEntry> get all => /* [... */ searches /* , ...pools, ...sets ]*/;
  int get length => /* pools.length + sets.length +  */ searches.length;
  List<List<SavedEntry>> get parented => searches.fold(
        <List<SavedEntry>>[],
        (previousValue, element) {
          try {
            return previousValue
              ..singleWhere((e) => e.firstOrNull?.parent == element.parent)
                  .add(element);
          } catch (e) {
            return previousValue..add([element]);
          }
        },
      )..sort(
          (a, b) => a.first.parent.compareTo(b.first.parent),
        );
  /* static const delimiter = "♥";
  SavedEntry operator [](String uniqueId) => all.singleWhere(
        (element) => element.uniqueId == uniqueId,
      );

  void operator []=(String uniqueId, SavedEntry e) {
    all[all.indexOf(all.singleWhere(
      (element) => element.uniqueId == uniqueId,
    ))] = e;
    _save();
  } */
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

  static async_lib.FutureOr<SavedDataE6> loadFromStorageAsync() async {
    var str = await Storable.tryLoadStringAsync(
      await fileFullPath.getItem(),
    );
    if (str == null) {
      try {
        return SavedDataE6.fromJson(
            (await devData.getItem())["e621"]["savedData"]);
      } catch (e) {
        return SavedDataE6();
      }
    } else {
      return SavedDataE6.fromJson(jsonDecode(str));
    }
  }

  factory SavedDataE6.fromJson(Map<String, dynamic> json) => SavedDataE6(
        pools: (json["pools"] as List).mapAsList(
          (e, index, list) => SavedPoolData.fromJson(e),
        ),
        sets: (json["sets"] as List).mapAsList(
          (e, index, list) => SavedSetData.fromJson(e),
        ),
        searches: (json["searches"] as List).mapAsList(
          (e, index, list) => SavedSearchData.fromJson(e),
        ),
      );
  Map<String, dynamic> toJson() => {
        "pools": pools,
        "sets": sets,
        "searches": searches,
      };
  void _save() {
    notifyListeners();
    writeAsync()
        .then(
          (value) => print("Write ${true ? "successful" : "failed"}"),
        )
        .catchError(onErrorPrintAndRethrow);
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

  /* void addAndSavePool(SavedPoolData p) {
    _modify((i) => i.pools.add(p));
    _save();
  }

  void addAndSaveSet(SavedSetData s) {
    _modify((i) => i.sets.add(s));
    _save();
  }
 */
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

/* /// Stuff like searches and sets
/// "searches": searches,
class SavedDataV2 extends ChangeNotifier with Storable<SavedDataV2> {
  // #region Singleton
  static final _instance = LateFinal<SavedDataV2>();
  static SavedDataV2 get $ =>
      _instance.isAssigned ? _instance.$ : SavedDataV2.fromStorageSync();
  static SavedDataV2 get $Copy => _instance.isAssigned
      ? _instance.$.copyWith()
      : SavedDataV2.fromStorageSync();
  static SavedDataV2? get $Safe {
    if (_instance.isAssigned) {
      return _instance.$;
    } else {
      switch (SavedDataV2.loadFromStorageAsync()) {
        case Future<SavedDataV2> t:
          t.then((v) => _instance.$ = v);
          break;
        case SavedDataV2 t:
          _instance.$ = t;
          break;
      }
      return null;
    }
  }

  static async_lib.FutureOr<SavedDataV2> get $Async =>
      _instance.isAssigned ? _instance.$ : SavedDataV2.loadFromStorageAsync();
  // #endregion Singleton

  static const fileName = "savedSearchesV2.json";
  static final fileFullPath = LazyInitializer.immediate(fileFullPathInit);

  static Future<String> fileFullPathInit() async {
    print("fileFullPathInit called");
    try {
      return Platform.isWeb ? "" : "${await appDataPath.getItem()}/$fileName";
    } catch (e) {
      print("Error in SavedDataV2.fileFullPathInit():\n$e");
      return "";
    }
  }

  factory SavedDataV2.fromStorageSync() => Platform.isWeb
      ? SavedDataV2._()
      : Storable.tryLoadToInstanceSync(fileFullPath.$) ?? SavedDataV2._();

  static async_lib.FutureOr<SavedDataV2> loadFromStorageAsync() async =>
      SavedDataV2.fromJson(jsonDecode(await Storable.tryLoadStringAsync(
            await fileFullPath.getItem(),
          ) ??
          jsonEncode(SavedDataV2._().toJson())));
  void _save() {
    notifyListeners();
    tryWriteAsync().then(
      (value) => print("Write ${value ? "successful" : "failed"}"),
    );
  }
  List<String> ids;
  List<SavedEntry> searches;
  int get length => searches.length;
  // int get searchCount => searches.fold(0, (acc, e) => acc += e.length);
  SavedEntry operator [](int index) {
    return searches[index];
  }

  void operator []=(int index, SavedEntry e) {
    searches[index] = e;
  }

  SavedDataV2._({
    List<SavedEntry>? searches,
  }) : searches = searches ?? List<SavedEntry>.empty(growable: true),
      ids = searches?.mapAsList((e, index, list) => e.uniqueId) ?? [] {
    _instance.itemSafe ??= this;
    if (!Platform.isWeb) {
      fileFullPath.getItem().then((value) {
        initStorageAsync(value);
      });
    }
  }
  SavedDataV2 copyWith({
    List<SavedEntry>? searches,
  }) =>
      SavedDataV2._(
        searches: searches ?? this.searches.toList(),
      );

  factory SavedDataV2.fromJson(Map<String, dynamic> json) => SavedDataV2(
        searches: (json["searches"] as List).mapAsList(
          (e, index, list) => SavedSearchData.fromJson(e),
        ),
      );
  Map<String, dynamic> toJson() => {
        "searches": searches,
      };

  void _modify(void Function(SavedDataV2 instance) modifier) {
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

final class SavedRecord implements Comparable<SavedRecord> with UniqueIdGenerator<SavedEntry> {
  final SavedEntry entry;
  final String myId;
  SavedRecord({
    required this.entry,
    String? myId,
  }) : myId = myId ?? ;
  static String getUniqueId(String proposed) {}
} */

abstract base class SavedEntry implements Comparable<SavedEntry> {
  String get searchString;
  String get title;
  String get parent;

  /// Allows for composed searches
  String get uniqueId;
  const SavedEntry();
}

@immutable
abstract base class SavedListData
    implements Comparable<SavedEntry>, SavedEntry {
  @override
  final String title;

  @override
  final String uniqueId;
  final int id;
  @override
  final String parent;

  const SavedListData({
    required this.title,
    required this.id,
    this.parent = "",
    this.uniqueId = "",
  });

  SavedListData copyWith({
    String? title,
    int? id,
    String? parent,
    String? uniqueId,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "parent": parent,
        "uniqueId": uniqueId,
      };

  @override
  int compareTo(SavedEntry other) => switch (other) {
        SavedListData o => (title.compareTo(o.title) != 0)
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
    super.parent = "",
    super.uniqueId = "",
  }) : super(title: title ?? "$searchStringBase$id");
  SavedSetData.fromSearchString({
    String? title,
    required String searchString,
    super.parent = "",
    super.uniqueId = "",
  }) : super(
            title: title ?? searchString,
            id: int.parse(searchString.replaceAll(searchStringBase, "")));

  @override
  SavedSetData copyWith({
    String? title,
    int? id,
    String? parent,
    String? uniqueId,
  }) =>
      SavedSetData(
        title: title ?? this.title,
        id: id ?? this.id,
        parent: parent ?? this.parent,
        uniqueId: uniqueId ?? this.uniqueId,
      );

  factory SavedSetData.fromJson(Map<String, dynamic> json) => SavedSetData(
        id: json["id"],
        title: json["title"],
        parent: json["parent"],
        uniqueId: json["uniqueId"],
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
    super.parent = "",
    super.uniqueId = "",
  }) : super(title: title ?? "$searchStringBase$id");
  SavedPoolData.fromSearchString({
    String? title,
    required String searchString,
    super.parent = "",
    super.uniqueId = "",
  }) : super(
            title: title ?? searchString,
            id: int.parse(searchString.replaceAll(searchStringBase, "")));

  @override
  SavedPoolData copyWith({
    String? title,
    int? id,
    String? parent,
    String? uniqueId,
  }) =>
      SavedPoolData(
        title: title ?? this.title,
        id: id ?? this.id,
        parent: parent ?? this.parent,
        uniqueId: uniqueId ?? this.uniqueId,
      );

  factory SavedPoolData.fromJson(Map<String, dynamic> json) => SavedPoolData(
        id: json["id"],
        title: json["title"],
        parent: json["parent"],
        uniqueId: json["uniqueId"],
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
  @override
  final String uniqueId;
  final Set<String> tags;
  @override
  String get searchString => tagListToString(tags, delimiter);
  @override
  final String parent;
  final bool isFavorite;

  const SavedSearchData({
    required this.tags,
    this.title = "",
    this.parent = "",
    this.uniqueId = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  });
  SavedSearchData.withDefaults({
    required this.tags,
    String title = "",
    this.parent = "",
    this.uniqueId = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  }) : title = title.isEmpty ? tagListToString(tags, delimiter) : title;

  SavedSearchData.fromTagsString({
    required String tags,
    String title = "",
    this.parent = "",
    this.uniqueId = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  })  : title = title.isNotEmpty ? title : tags,
        tags = tags.split(delimiter).toSet();

  SavedSearchData.fromSearchString({
    required String searchString,
    String title = "",
    String parent = "",
    String uniqueId = "",
    String delimiter = e621Delimiter,
    bool isFavorite = false,
  }) : this.fromTagsString(
            tags: searchString,
            delimiter: delimiter,
            isFavorite: isFavorite,
            parent: parent,
            title: title);

  SavedSearchData copyWith({
    String? title,
    Set<String>? tags,
    String? parent,
    String? uniqueId,
    bool? isFavorite,
    String? delimiter,
  }) =>
      SavedSearchData(
        tags: tags ?? this.tags,
        title: title ?? this.title,
        parent: parent ?? this.parent,
        isFavorite: isFavorite ?? this.isFavorite,
        delimiter: delimiter ?? this.delimiter,
      );

  @override
  int compareTo(SavedEntry other) => (title.compareTo(other.title) != 0)
      ? title.compareTo(other.title)
      : searchString.compareTo(other.searchString);

  factory SavedSearchData.fromJson(Map<String, dynamic> json) =>
      SavedSearchData(
        title: json["title"],
        parent: json["parent"],
        uniqueId: json["uniqueId"],
        isFavorite: json["isFavorite"],
        delimiter: json["delimiter"],
        tags: (json["tags"] as List).cast<String>().toSet(),
      );
  Map<String, dynamic> toJson() => {
        "tags": tags.toList(),
        "title": title,
        "parent": parent,
        "uniqueId": uniqueId,
        "isFavorite": isFavorite,
        "delimiter": delimiter,
      };
}
