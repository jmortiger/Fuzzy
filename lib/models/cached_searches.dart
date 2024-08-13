import 'dart:async' as async_lib;
import 'dart:convert';
import 'package:fuzzy/models/search_data.dart';
import 'package:fuzzy/util/util.dart';
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

  static async_lib.FutureOr<List<SearchData>> loadFromStorageAsync() async {
    E621.searchBegan.subscribe(onSearchBegan);
    Changed.subscribe(CachedSearches._save);
    var t = await (await file.getItem())?.readAsString();
    return (t != null)
        ? CachedSearches.loadFromJson(jsonDecode(t))
        : await loadFromPref(); // _searches = const <SearchData>[];
  }

  static const localStoragePrefix = 'cs';
  static const localStorageLengthKey = '$localStoragePrefix.length';
  static Future<bool> writeToPref([List<SearchData>? searches]) {
    searches ??= CachedSearches.searches;
    return pref.getItem().then((v) {
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

  static Future<List<SearchData>> loadFromPref() => pref.getItem().then((v) {
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
      searches = json.mapAsList((e, i, l) => SearchData.fromJson(e));
  static List toJson() => _searches;
  // #endregion IO

  @event
  static final Changed = JEvent<CachedSearchesEvent>();

  static List<SearchData> _searches = const <SearchData>[];
  static List<SearchData> get searches => _searches;
  static set searches(List<SearchData> v) {
    Changed.invoke(
      CachedSearchesEvent(
          priorValue: List.unmodifiable(_searches),
          currentValue: _searches = List.unmodifiable(v)),
    );
  }

  // static void clear() => searches = const <SearchData>[];
  static void clear() => Changed.invoke(CachedSearchesEvent(
      priorValue: List.unmodifiable(_searches),
      currentValue: List.unmodifiable(_searches..clear()),
    ));

  static void onSearchBegan(SearchArgs a) {
    _searches = List.unmodifiable(
      _searches.toSet()..add(SearchData.fromList(tagList: a.tags)),
    );
    _save();
  }

  static void _save([CachedSearchesEvent? e]) {
    print("Writing search cache");
    file
        .getItem()
        .then<async_lib.FutureOr<Object?>>(
          (v) =>
              v?.writeAsString(jsonEncode(CachedSearches.toJson())) ??
              // Future.sync(() => null)
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
/* class CachedSearches extends ChangeNotifier {
  static const fileName = "CachedSearches.json";
  static final fileFullPath = LazyInitializer.immediate(fileFullPathInit);
  static Future<String> fileFullPathInit() async {
    print("fileFullPathInit called");
    try {
      return Platform.isWeb ? "" : "${await appDataPath.getItem()}/$fileName";
    } catch (e) {
      print("Error in CachedSearches.fileFullPathInit():\n$e");
      return "";
    }
  }

  static async_lib.FutureOr<CachedSearches> loadFromStorageAsync() async =>
      CachedSearches.fromJson(
        jsonDecode(
          await Storable.tryLoadStringAsync(await fileFullPath.getItem()) ??
              jsonEncode(CachedSearches().toJson()),
        ),
      );
  factory CachedSearches.fromJson(JsonMap json) => CachedSearches();
  Map<String, dynamic> toJson() => {};

  @event
  final Changed = JPureEvent();

  List<String> searches;

  CachedSearches({List<String>? searches})
      : searches = searches ?? List<String>.empty(growable: true) {
    E621.searchBegan.subscribe(onSearchBegan);
  }
  void onSearchBegan(SearchArgs a) {
    searches.add(a.tags.foldToString());
    _save();
  }

  void _save() {
    notifyListeners();
    tryWriteAsync().then(
      (value) => print("Write ${value ? "successful" : "failed"}"),
    );
  }
}
 */
