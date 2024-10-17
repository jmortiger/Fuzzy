import 'dart:async' as async_lib;
import 'dart:convert';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_data.dart';
import 'package:fuzzy/util/util.dart' hide pref;
import 'package:fuzzy/util/shared_preferences.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';

import '../web/e621/e621.dart';

import 'package:fuzzy/log_management.dart' as lm;

class CachedSearches {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("CachedSearches");
  // #endregion Logger
  // #region IO
  static const fileName = "CachedSearches.json";

  static final file = LazyInitializer.immediate(() async {
    // TODO: Pull into initializers
    E621.searchBegan.subscribe(onSearchBegan);
    try {
      return Platform.isWeb
          ? null
          : Storable.handleInitStorageAsync(
              "${await appDataPath.getItem()}/$fileName");
    } catch (e, s) {
      logger.warning("Error in CachedSearches.file.Init()", e, s);
      return null;
    }
  });

  static async_lib.FutureOr<List<SearchData>> loadFromStorageAsync(
      [void _]) async {
    changed.subscribe(CachedSearches._save);
    var t = await (await file.getItem())?.readAsString();
    return (t != null)
        ? CachedSearches.loadFromJson(jsonDecode(t))
        : await loadFromPref();
  }

  static const localStoragePrefix = 'cs';
  static const localStorageLengthKey = '$localStoragePrefix.length';
  static Future<bool> writeToPref([List<SearchData>? searches]) {
    searches ??= CachedSearches.searches;
    return pref.getItemAsync().then((v) {
      final l = v.setInt(localStorageLengthKey, searches!.length);
      final success = <Future<bool>>[];
      for (var i = 0; i < searches.length; i++) {
        final e1 = searches[i];
        final e = e1.toJson();
        success.add(v.setString("$localStoragePrefix.$i", e));
      }
      return success.fold(
          l,
          (previousValue, element) => (previousValue is Future<bool>)
              ? previousValue.then((s) => element.then((s1) => s && s1))
              : element.then((s1) => previousValue && s1));
    });
  }

  static Future<List<SearchData>> loadFromPref() =>
      pref.getItemAsync().then((v) {
        final length = v.getInt(localStorageLengthKey) ?? 0;
        var data = <SearchData>[];
        for (var i = 0; i < length; i++) {
          data.add(
            SearchData.fromString(
              searchString: v.getString("$localStoragePrefix.$i") ??
                  v.getString("$localStoragePrefix.$i.searchString") ??
                  "FAILURE",
            ),
          );
        }
        logger.finer("Loaded cached searches from pref: ${data.map(
          (e) => e.searchString,
        )}");
        return data;
      });
  static List<SearchData>? loadFromPrefSync() {
    if (!pref.isAssigned) return null;
    final length = pref.$.getInt(localStorageLengthKey) ?? 0;
    var data = <SearchData>[];
    for (var i = 0; i < length; i++) {
      data.add(
        SearchData.fromString(
          searchString: pref.$.getString("$localStoragePrefix.$i") ?? "FAILURE",
        ),
      );
    }
    return data;
  }

  static List<SearchData> loadFromJson(List json) =>
      searches = json.map((e) => SearchData.fromJson(e)).toList();
  static List toJson() => _searches;
  // #endregion IO

  @Event(name: "Changed")
  static final changed = JEvent<CachedSearchesEvent>();

  static List<SearchData> _searches = const <SearchData>[];
  static List<SearchData> get searches => _searches;
  static set searches(List<SearchData> v) {
    changed.invoke(
      CachedSearchesEvent(
          priorValue: List.unmodifiable(_searches),
          currentValue: _searches = List.unmodifiable(v)),
    );
  }

  static void clear() => changed.invoke(CachedSearchesEvent(
        priorValue: List.unmodifiable(_searches),
        currentValue: List.unmodifiable(searches = const []),
      ));

  static void removeSearch({
    String? searchString,
    SearchData? element,
    int? index,
  }) =>
      (searchString ?? element ?? index) != null
          ? changed.invoke(CachedSearchesEvent(
              priorValue: List.unmodifiable(_searches),
              currentValue: List.unmodifiable(searches = element != null
                  ? (searches.toList()..remove(element))
                  : searchString != null
                      ? (searches.toList()
                        ..removeWhere((e) => e.searchString == searchString))
                      : (searches.toList()..removeAt(index!))),
            ))
          : "";

  static void onSearchBegan(SearchArgs a) {
    final t = _searches.toSet()..add(SearchData.fromList(tagList: a.tags));
    changed.invoke(
      CachedSearchesEvent(
          priorValue: List.unmodifiable(_searches),
          currentValue: searches = List.unmodifiable(
              t.length > AppSettings.i!.maxSearchesToSave
                  ? (t.toList()..removeAt(0))
                  : t)),
    );
    _save();
  }

  static void _save([CachedSearchesEvent? e]) {
    print("Writing search cache");
    file
        .getItemAsync()
        .then<async_lib.FutureOr<Object?>>(
          (v) =>
              v?.writeAsString(jsonEncode(CachedSearches.toJson())) ??
              writeToPref().then((v1) => v1 ? v1 : null),
        )
        .then(
          (value) => print(
              "Write ${value == null ? "not performed" : "presumably successful"}"),
        );
  }
}

class CachedSearchesEvent extends JEventArgs {
  final List<SearchData> priorValue;
  final List<SearchData> currentValue;
  static const CachedSearchesEvent empty = CachedSearchesEvent(
    priorValue: <SearchData>[],
    currentValue: <SearchData>[],
  );
  const CachedSearchesEvent({
    required this.priorValue,
    required this.currentValue,
  });
}
