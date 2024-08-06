import 'dart:async' as async_lib;
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';

import 'package:fuzzy/log_management.dart' as lm;
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stuff like searches and sets
/// "searches": searches,
class SavedDataE6 extends ChangeNotifier {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.genLogger("SavedData");
  // #endregion Logger
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

  static final file = LazyInitializer<File?>(() async {
    return !Platform.isWeb
        ? Storable.getStorageAsync(await fileFullPath.getItem())
        : null;
  });
  static async_lib.FutureOr<T> doOnInit<T>(T Function() callback) {
    return isInit
        ? callback()
        : SavedDataE6.storageAsync.then<T>((v) => callback())
            as async_lib.FutureOr<T>;
  }

  static late ListNotifier<SavedSearchData> searches;
  ListNotifier<SavedSearchData> get $searches => SavedDataE6.searches;
  static ListNotifier<SavedEntry> get all => searches;
  static int get length => searches.length;
  ListNotifier<ListNotifier<SavedEntry>> get $parented => SavedDataE6.parented;
  static ListNotifier<ListNotifier<SavedEntry>> get parented => searches.fold(
        ListNotifier<ListNotifier<SavedEntry>>.empty(true),
        (acc, element) {
          try {
            return acc
              ..singleWhere((e) => e.firstOrNull?.parent == element.parent)
                  .add(element);
          } catch (e) {
            return acc..add(ListNotifier.filled(1, element, true));
          }
        },
      )
        ..sort(
          (a, b) => a.first.parent.compareTo(b.first.parent),
        )
        ..forEach((e) => e.sort(
              (a, b) => a.compareTo(b),
            ));
  Set<String> get $parents => SavedDataE6.parents;
  static Set<String> get parents => searches.fold(
        <String>{},
        (acc, element) => acc..add(element.parent),
      );
  Map<String, int> get $parentCount => SavedDataE6.parentCount;
  static Map<String, int> get parentCount => searches.fold(
        <String, int>{},
        (acc, element) {
          acc[element] == null
              ? acc[element.parent] = 1
              : acc[element.parent] = acc[element.parent]! + 1;
          return acc;
        },
      );

  static bool get isInit {
    try {
      searches.isEmpty;
      return true;
    } catch (e) {
      return false;
    }
  }

  static const localStoragePrefix = 'ssd';
  static const localStorageLengthKey = '$localStoragePrefix.length';
  SavedDataE6({
    ListNotifier<SavedSearchData>? searches,
  }) {
    if (searches == null) {
      if (!isInit) {
        SavedDataE6.searches = ListNotifier<SavedSearchData>.empty(true);
        storageAsync.then((v) {
          if (!validateUniqueness()) {
            _save();
          }
          SavedDataE6.searches.addListener(notifyListeners);
        });
      }
    } else {
      if (isInit) SavedDataE6.searches.dispose();
      SavedDataE6.searches = searches;
      searches.addListener(notifyListeners);
    }
  }
  SavedDataE6.recycle() {
    try {
      SavedDataE6.searches.isEmpty;
    } catch (e) {
      SavedDataE6.searches = ListNotifier<SavedSearchData>.empty(true);
      storageAsync.then((v) {
        searches = v;
        if (!validateUniqueness()) {
          _save();
        }
        searches.addListener(notifyListeners);
      });
    }
  }
  static async_lib.FutureOr<SavedDataE6> loadOrRecycle() {
    try {
      searches.isEmpty;
      return SavedDataE6.recycle();
    } catch (e) {
      return storageAsync.then((v) => SavedDataE6(searches: v));
    }
  }

  static Future<ListNotifier<SavedSearchData>> get storageAsync async =>
      await ((await file.getItem())
              ?.readAsString()
              .then((v) => SavedDataE6.fromJson(jsonDecode(v))) ??
          loadFromPref());
  static ListNotifier<SavedSearchData>? get storageSync {
    String? t = file.$Safe?.readAsStringSync();
    return (t == null)
        ? loadFromPrefSync()
        : SavedDataE6.fromJson(jsonDecode(t));
  }

  @override
  void dispose() {
    searches.removeListener(notifyListeners);
    $searches.removeListener(notifyListeners);
    super.dispose();
  }

  SavedDataE6.init() {
    if (isInit) {
      searches.addListener(notifyListeners);
      return;
    }
    file.getItem().then((value) {
      (value?.readAsString().then((v) => SavedDataE6.fromJson(jsonDecode(v))) ??
              loadFromPref())
          .then((v) {
        searches = v..addListener(notifyListeners);
        if (!validateUniqueness(searches: v)) {
          _save();
        }
      });
    });
  }
  // SavedDataE6 copyWith({
  //   // List<SavedPoolData>? pools,
  //   // List<SavedSetData>? sets,
  //   ListNotifier<SavedSearchData>? searches,
  // }) =>
  //     SavedDataE6(
  //       // pools: pools ?? this.pools.toList(),
  //       // sets: sets ?? this.sets.toList(),
  //       searches: searches ?? this.searches.toList(),
  //     );
  factory SavedDataE6.fromStorageSync() => Platform.isWeb
      ? SavedDataE6()
      : Storable.tryLoadToInstanceSync(fileFullPath.$) ?? SavedDataE6();
  static Future<bool> writeToPref([List<SavedSearchData>? searches]) {
    searches ??= SavedDataE6.searches;
    return pref.getItem().then((v) {
      final l = v.setInt(localStorageLengthKey, searches!.length);
      final success = <Future<bool>>[];
      for (var i = 0; i < searches.length; i++) {
        final e1 = searches[i];
        final e = e1.toJson();
        success.add(v.setString("$localStoragePrefix.$i.searchString",
            e1.searchString)); //e["searchString"]));
        success.add(v.setString("$localStoragePrefix.$i.delimiter",
            e1.delimiter)); //e["delimiter"]));
        success.add(v.setString(
            "$localStoragePrefix.$i.parent", e1.parent)); //e["parent"]));
        success.add(v.setString(
            "$localStoragePrefix.$i.title", e1.title)); //e["title"]));
        success.add(v.setString(
            "$localStoragePrefix.$i.uniqueId", e1.uniqueId)); //e["uniqueId"]));
        success.add(v.setBool("$localStoragePrefix.$i.isFavorite",
            e1.isFavorite)); //e["isFavorite"]));
      }
      return success.fold(
          l,
          (previousValue, element) => (previousValue is Future<bool>)
              ? previousValue.then((s) => element.then((s1) => s && s1))
              : element.then((s1) => previousValue && s1));
    });
  }

  static Future<ListNotifier<SavedSearchData>> loadFromPref() =>
      pref.getItem().then((v) {
        final length = v.getInt(localStorageLengthKey) ?? 0;
        var data = ListNotifier<SavedSearchData>();
        for (var i = 0; i < length; i++) {
          data.add(
            SavedSearchData.fromSearchString(
              searchString:
                  v.getString("$localStoragePrefix.$i.searchString") ??
                      "FAILURE",
              delimiter: SavedSearchData.e621Delimiter,
              parent: v.getString("$localStoragePrefix.$i.parent") ?? "FAILURE",
              title: v.getString("$localStoragePrefix.$i.title") ?? "FAILURE",
              uniqueId:
                  v.getString("$localStoragePrefix.$i.uniqueId") ?? "FAILURE",
              isFavorite:
                  v.getBool("$localStoragePrefix.$i.isFavorite") ?? false,
            ),
          );
        }
        return data;
      });
  static ListNotifier<SavedSearchData>? loadFromPrefSync() {
    if (!pref.isAssigned) return null;
    final length = pref.$.getInt(localStorageLengthKey) ?? 0;
    var data = ListNotifier<SavedSearchData>();
    for (var i = 0; i < length; i++) {
      data.add(
        SavedSearchData.fromSearchString(
          searchString:
              pref.$.getString("$localStoragePrefix.$i.searchString") ??
                  "FAILURE",
          delimiter: SavedSearchData.e621Delimiter,
          parent:
              pref.$.getString("$localStoragePrefix.$i.parent") ?? "FAILURE",
          title: pref.$.getString("$localStoragePrefix.$i.title") ?? "FAILURE",
          uniqueId:
              pref.$.getString("$localStoragePrefix.$i.uniqueId") ?? "FAILURE",
          isFavorite:
              pref.$.getBool("$localStoragePrefix.$i.isFavorite") ?? false,
        ),
      );
    }
    return data;
  }

  static async_lib.FutureOr<ListNotifier<SavedSearchData>>
      loadFromStorageAsync() async {
    var str = await Storable.tryLoadStringAsync(
      await fileFullPath.getItem(),
    );
    if (str == null) {
      try {
        return SavedDataE6.fromJson(
            (await devData.getItem())["e621"]["savedData"]);
      } catch (e) {
        return ListNotifier<SavedSearchData>();
      }
    } else {
      return SavedDataE6.fromJson(jsonDecode(str));
    }
  }

  static ListNotifier<SavedSearchData> fromJson(Map<String, dynamic> json) =>
      ListNotifier.of((json["searches"] as List).mapAsList(
        (e, index, list) => SavedSearchData.fromJson(e),
      ));
  static Map<String, dynamic> toJson() => {
        "searches": searches,
      };
  static void _$save() {
    if (!Platform.isWeb) {
      file.$Safe
          ?.writeAsString(jsonEncode(toJson()))
          .catchError((e, s) => print(e, Level.WARNING, e, s))
          .then(
            (value) => print("Write successful"),
          )
          .catchError((e, s) => print(e, Level.WARNING, e, s));
    } else {
      writeToPref().then((v) => v
          ? print("SavedDataE6 stored successfully: ${jsonEncode(toJson())}",
              Level.FINE)
          : print("SavedDataE6 failed to store: ${jsonEncode(toJson())}",
              Level.SEVERE));
    }
  }

  void _save() {
    _$save();
    notifyListeners();
  }

  static const validIdCharacters =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

  /// Returns [true] if was valid before entering method and false otherwise.
  bool validateUniqueness({
    ListNotifier<SavedSearchData>? searches,
    bool resolve = true,
  }) {
    searches ??= SavedDataE6.searches;
    var ret = true;
    for (var i = 0; i < searches.length; i++) {
      for (var j = i; j < searches.length; j++) {
        if (i == j) continue;
        if (searches[i].uniqueId == searches[j].uniqueId) {
          ret = false;
          if (!resolve) {
            return ret;
          }
          var store = searches[j];
          store = store.copyWith(
            uniqueId:
                "${store.uniqueId}${validIdCharacters[Random().nextInt(validIdCharacters.length)]}",
          );
          searches[j] = store;
        }
      }
    }
    return ret;
  }

  static void _$modify(void Function() modifier) {
    modifier();
    _$save();
  }

  void _modify(void Function() modifier) {
    modifier();
    _save();
  }

  static void $addAndSaveSearch(SavedSearchData s) {
    searches.add(s);
    _$save();
  }

  void addAndSaveSearch(SavedSearchData s) {
    searches.add(s);
    _save();
  }

  static void $editAndSave({
    required SavedEntry original,
    required SavedEntry edited,
  }) {
    // edited = edited.validateUniqueness();
    switch ((edited, original)) {
      case (SavedSearchData o, SavedSearchData orig):
        searches[searches.indexOf(orig)] = o;
        break;
      default:
        throw UnsupportedError("not supported");
    }
    _$save();
  }

  void editAndSave({
    required SavedEntry original,
    required SavedEntry edited,
  }) {
    // edited = edited.validateUniqueness();
    switch ((edited, original)) {
      case (SavedSearchData o, SavedSearchData orig):
        searches[searches.indexOf(orig)] = o;
        break;
      default:
        throw UnsupportedError("not supported");
    }
    _save();
  }

  static void $removeEntry(SavedEntry entry) {
    searches.remove(entry);
    _$save();
  }

  void removeEntry(SavedEntry entry) {
    searches.remove(entry);
    _save();
  }

  static Widget buildParentedView({
    required BuildContext context,
    SavedDataE6? data,
    VoidCallback Function(SavedEntry)? generateOnTap,
  }) {
    final parented = data?.$parented ?? SavedDataE6.parented;
    return ListView(
      children: parented.mapAsList(
        (e, index, list) => ExpansionTile(
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
            (e2, i2, l2) => buildSavedEntry(
              entry: e2,
              context: context,
              generateOnTap: generateOnTap,
            ),
          ),
        ),
      ),
    );
  }

  static ListTile buildSavedEntry<T extends SavedEntry>({
    required BuildContext context,
    required T entry,
    VoidCallback Function(SavedEntry)? generateOnTap,
  }) {
    return ListTile(
      leading: switch (entry.runtimeType) {
        SavedSearchData => const Text("S"),
        SavedPoolData => const Text("P"),
        SavedSetData => const Text("s"),
        _ => throw UnsupportedError("not supported"),
      },
      title: Text(entry.title),
      subtitle: Text(entry.searchString),
      onTap: generateOnTap?.call(entry),
    );
  }
}

abstract base class SavedEntry implements Comparable<SavedEntry> {
  String get searchString;
  String get title;
  String get parent;

  /// Allows for composed searches
  String get uniqueId;
  const SavedEntry();
  static const validIdCharacters =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
  SavedEntry validateUniqueness();
  bool verifyUniqueness();
  // static bool implValidateUniqueness(SavedEntry e, [bool resolve = true]) {
  //   var all = SavedDataE6._instance.$.all;
  //   while(all.any((el) => el != e && el.uniqueId == e)) {
  //     e.
  //   }
  // }
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

  @override
  SavedSetData validateUniqueness() {
    var all = SavedDataE6.all;
    var ret = this;
    while (all
        .any((e) => e.searchString != searchString && e.uniqueId == uniqueId)) {
      ret = copyWith(
        uniqueId: "$uniqueId${SavedEntry.validIdCharacters[Random().nextInt(
          SavedEntry.validIdCharacters.length,
        )]}",
      );
    }
    return ret;
  }

  @override
  bool verifyUniqueness() => !SavedDataE6.all.any(
        (e) => e.searchString != searchString && e.uniqueId == uniqueId,
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

  @override
  SavedPoolData validateUniqueness() {
    // var all = SavedDataE6._instance.$.all;
    var ret = this;
    while (!verifyUniqueness()) {
      ret = copyWith(
        uniqueId: "$uniqueId${SavedEntry.validIdCharacters[Random().nextInt(
          SavedEntry.validIdCharacters.length,
        )]}",
      );
    }
    return ret;
  }

  @override
  bool verifyUniqueness() => !SavedDataE6.all.any(
        (e) => e.searchString != searchString && e.uniqueId == uniqueId,
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
  final String searchString;
  // String get searchString => tagListToString(tags, delimiter);
  @override
  final String parent;
  final bool isFavorite;

  const SavedSearchData.$const({
    required this.tags,
    this.title = "",
    this.parent = "",
    this.uniqueId = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
    this.searchString = "",
  });
  SavedSearchData({
    required this.tags,
    this.title = "",
    this.parent = "",
    this.uniqueId = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  }) : searchString = tags.reduce((acc, e) => "$acc$delimiter$e");
  SavedSearchData.withDefaults({
    required this.tags,
    String title = "",
    this.parent = "",
    this.uniqueId = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  })  : title = title.isEmpty ? tagListToString(tags, delimiter) : title,
        searchString = tags.reduce((acc, e) => "$acc$delimiter$e");

  SavedSearchData.fromTagsString({
    required this.searchString,
    String title = "",
    this.parent = "",
    this.uniqueId = "",
    this.isFavorite = false,
    this.delimiter = e621Delimiter,
  })  : title = title.isNotEmpty ? title : searchString,
        tags = searchString.split(delimiter).toSet();

  SavedSearchData.fromSearchString({
    required String searchString,
    String title = "",
    String parent = "",
    String uniqueId = "",
    String delimiter = e621Delimiter,
    bool isFavorite = false,
  }) : this.fromTagsString(
            searchString: searchString,
            delimiter: delimiter,
            isFavorite: isFavorite,
            parent: parent,
            uniqueId: uniqueId,
            title: title);

  SavedSearchData copyWith({
    String? title,
    String? searchString,
    // Set<String>? tags,
    String? parent,
    String? uniqueId,
    bool? isFavorite,
    String? delimiter,
  }) =>
      SavedSearchData.fromTagsString(
        searchString: searchString ?? this.searchString,
        title: title ?? this.title,
        parent: parent ?? this.parent,
        isFavorite: isFavorite ?? this.isFavorite,
        delimiter: delimiter ?? this.delimiter,
        uniqueId: uniqueId ?? this.uniqueId,
      );

  @override
  int compareTo(SavedEntry other) => (title.compareTo(other.title) != 0)
      ? title.compareTo(other.title)
      : searchString.compareTo(other.searchString);

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType &&
        other is SavedSearchData &&
        other.delimiter == delimiter &&
        other.isFavorite == isFavorite &&
        other.parent == parent &&
        other.searchString == searchString &&
        other.title == title &&
        other.uniqueId == uniqueId;
    //super == other;
  }

  @override
  int get hashCode {
    return delimiter.hashCode % 32767 +
        isFavorite.hashCode % 32767 +
        parent.hashCode % 32767 +
        searchString.hashCode % 32767 +
        title.hashCode % 32767 +
        uniqueId.hashCode % 32767;
    // return super.hashCode;
  }

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
  static const localStoragePrefix = SavedDataE6.localStoragePrefix;
  factory SavedSearchData.readFromPrefSync(SharedPreferences v,
          [String? instancePrefix]) =>
      SavedSearchData.fromSearchString(
        searchString: v.getString(
                "$localStoragePrefix${instancePrefix != null ? ".$instancePrefix" : ""}.searchString") ??
            "FAILURE",
        delimiter: SavedSearchData.e621Delimiter,
        parent: v.getString(
                "$localStoragePrefix${instancePrefix != null ? ".$instancePrefix" : ""}.parent") ??
            "FAILURE",
        title: v.getString(
                "$localStoragePrefix${instancePrefix != null ? ".$instancePrefix" : ""}.title") ??
            "FAILURE",
        uniqueId: v.getString(
                "$localStoragePrefix${instancePrefix != null ? ".$instancePrefix" : ""}.uniqueId") ??
            "FAILURE",
        isFavorite: v.getBool(
                "$localStoragePrefix${instancePrefix != null ? ".$instancePrefix" : ""}.isFavorite") ??
            false,
      );

  @override
  SavedSearchData validateUniqueness() {
    var ret = this;
    while (!ret.verifyUniqueness()) {
      ret = copyWith(
        uniqueId: "$uniqueId${SavedEntry.validIdCharacters[Random().nextInt(
          SavedEntry.validIdCharacters.length,
        )]}",
      );
    }
    return ret;
  }

  @override
  bool verifyUniqueness() => !SavedDataE6.all.any(
        (e) => e.searchString != searchString && e.uniqueId == uniqueId,
      );
  // @override
  // bool verifyUniqueness() => !SavedDataE6Legacy._instance.$.all.any(
  //       (e) => e.searchString != searchString && e.uniqueId == uniqueId,
  //     );
}

Future<SavedElementRecord?> showSavedElementEditDialogue(
  BuildContext context, {
  String initialTitle = "",
  String initialData = "",
  String mainDataName = "Tags",
  String initialParent = "",
  String initialUniqueId = "",
  bool isNumeric = false,
}) {
  return showDialog<SavedElementRecord>(
    context: context,
    builder: (context) {
      var title = initialTitle,
          mainData = initialData,
          parent = initialParent,
          uniqueId = initialUniqueId;
      var searchController = SearchController()..text = initialParent;
      return AlertDialog(
        content: Column(
          children: [
            const Text("Title:"),
            TextField(
              onChanged: (value) => title = value,
              controller: defaultSelection(initialTitle),
            ),
            Text("$mainDataName:"),
            TextField(
              inputFormatters: isNumeric ? [numericFormatter] : null,
              onChanged: (value) => mainData = value,
              controller: defaultSelection(initialData),
              keyboardType: isNumeric ? TextInputType.number : null,
            ),
            const Text("Parent:"),
            // TODO: Add Autocomplete
            // TextField(
            //   onChanged: (value) => parent = value,
            //   controller: defaultSelection(initialParent),
            // ),
            SearchAnchor(
              viewHintText: "parent",
              viewOnChanged: (value) {
                // searchController.openView();
                parent = value;
              },
              // controller: controller, //defaultSelection(initialParent),
              // onTap: () => controller.openView(),
              // onTapOutside: (e) => controller.closeView(null),
              searchController: searchController,
              builder: (context, controller) {
                // controller.text = initialParent;
                /* return SearchBar(
                  hintText: "parent",
                  onChanged: (value) {
                    controller.openView();
                    parent = value;
                  },
                  controller: controller, //defaultSelection(initialParent),
                  onTap: () => controller.openView(),
                  onTapOutside: (e) => controller.closeView(null),
                ); */
                return TextField(
                  controller: controller,
                  // icon: const Icon(Icons.search),
                  // onPressed: controller.openView,
                  onTap: controller.openView,
                );
              },
              suggestionsBuilder: (context, controller) {
                return (SavedDataE6.parents..add(initialParent)).map(
                  (e) => ListTile(
                    title: Text(e),
                    onTap: () => controller.closeView(e),
                    subtitle: Text("${SavedDataE6.parentCount[e]} children"),
                  ),
                );
              },
            ),
            const Text("UniqueId:"),
            TextField(
              onChanged: (value) => uniqueId = value,
              controller: defaultSelection(initialUniqueId),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              (
                title: title,
                mainData: mainData,
                parent: parent,
                uniqueId: uniqueId
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

typedef SavedElementRecord = ({
  String mainData,
  String title,
  String? parent,
  String? uniqueId,
});

// @immutable
// final class SavedSearchDataMutable implements SavedSearchData {
//   static String tagListToString(Iterable<String> tags, String delimiter) =>
//       tags.reduce((acc, e) => "$acc$delimiter$e");
//   static const e621Delimiter = " ";
//   @override
//   final String delimiter;
//   @override
//   final String title;
//   @override
//   final String uniqueId;
//   final Set<String> tags;
//   @override
//   final String searchString;
//   // String get searchString => tagListToString(tags, delimiter);
//   @override
//   final String parent;
//   final bool isFavorite;

//   const SavedSearchDataMutable.$const({
//     required this.tags,
//     this.title = "",
//     this.parent = "",
//     this.uniqueId = "",
//     this.isFavorite = false,
//     this.delimiter = e621Delimiter,
//     this.searchString = "",
//   });
//   SavedSearchDataMutable({
//     required this.tags,
//     this.title = "",
//     this.parent = "",
//     this.uniqueId = "",
//     this.isFavorite = false,
//     this.delimiter = e621Delimiter,
//   }) : searchString = tags.reduce((acc, e) => "$acc$delimiter$e");
//   SavedSearchDataMutable.withDefaults({
//     required this.tags,
//     String title = "",
//     this.parent = "",
//     this.uniqueId = "",
//     this.isFavorite = false,
//     this.delimiter = e621Delimiter,
//   })  : title = title.isEmpty ? tagListToString(tags, delimiter) : title,
//         searchString = tags.reduce((acc, e) => "$acc$delimiter$e");

//   SavedSearchDataMutable.fromTagsString({
//     required this.searchString,
//     String title = "",
//     this.parent = "",
//     this.uniqueId = "",
//     this.isFavorite = false,
//     this.delimiter = e621Delimiter,
//   })  : title = title.isNotEmpty ? title : searchString,
//         tags = searchString.split(delimiter).toSet();

//   SavedSearchDataMutable.fromSearchString({
//     required String searchString,
//     String title = "",
//     String parent = "",
//     String uniqueId = "",
//     String delimiter = e621Delimiter,
//     bool isFavorite = false,
//   }) : this.fromTagsString(
//             searchString: searchString,
//             delimiter: delimiter,
//             isFavorite: isFavorite,
//             parent: parent,
//             uniqueId: uniqueId,
//             title: title);

//   SavedSearchDataMutable copyWith({
//     String? title,
//     String? searchString,
//     // Set<String>? tags,
//     String? parent,
//     String? uniqueId,
//     bool? isFavorite,
//     String? delimiter,
//   }) =>
//       SavedSearchDataMutable.fromTagsString(
//         searchString: searchString ?? this.searchString,
//         title: title ?? this.title,
//         parent: parent ?? this.parent,
//         isFavorite: isFavorite ?? this.isFavorite,
//         delimiter: delimiter ?? this.delimiter,
//         uniqueId: uniqueId ?? this.uniqueId,
//       );

//   @override
//   int compareTo(SavedEntry other) => (title.compareTo(other.title) != 0)
//       ? title.compareTo(other.title)
//       : searchString.compareTo(other.searchString);

//   @override
//   bool operator ==(Object other) {
//     return other.runtimeType == runtimeType &&
//         other is SavedSearchDataMutable &&
//         other.delimiter == delimiter &&
//         other.isFavorite == isFavorite &&
//         other.parent == parent &&
//         other.searchString == searchString &&
//         other.title == title &&
//         other.uniqueId == uniqueId;
//     //super == other;
//   }

//   @override
//   int get hashCode {
//     return delimiter.hashCode % 32767 +
//         isFavorite.hashCode % 32767 +
//         parent.hashCode % 32767 +
//         searchString.hashCode % 32767 +
//         title.hashCode % 32767 +
//         uniqueId.hashCode % 32767;
//     // return super.hashCode;
//   }

//   factory SavedSearchDataMutable.fromJson(Map<String, dynamic> json) =>
//       SavedSearchDataMutable(
//         title: json["title"],
//         parent: json["parent"],
//         uniqueId: json["uniqueId"],
//         isFavorite: json["isFavorite"],
//         delimiter: json["delimiter"],
//         tags: (json["tags"] as List).cast<String>().toSet(),
//       );
//   Map<String, dynamic> toJson() => {
//         "tags": tags.toList(),
//         "title": title,
//         "parent": parent,
//         "uniqueId": uniqueId,
//         "isFavorite": isFavorite,
//         "delimiter": delimiter,
//       };

//   @override
//   SavedSearchDataMutable validateUniqueness() {
//     var all = SavedDataE6Legacy._instance.$.all;
//     var ret = this;
//     while (!ret.verifyUniqueness()) {
//       ret = copyWith(
//         uniqueId: "$uniqueId${SavedEntry.validIdCharacters[Random().nextInt(
//           SavedEntry.validIdCharacters.length,
//         )]}",
//       );
//     }
//     return ret;
//   }

//   @override
//   bool verifyUniqueness() => !SavedDataE6Legacy._instance.$.all.any(
//         (e) => e.searchString != searchString && e.uniqueId == uniqueId,
//       );
// }
