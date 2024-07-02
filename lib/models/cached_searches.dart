import 'dart:async' as async_lib;
import 'dart:convert';
import 'package:fuzzy/models/search_data.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';

import '../web/e621/e621.dart';

import 'package:fuzzy/log_management.dart' as lm;

final lRecord = lm.genLogger("CachedSearches");
final print = lRecord.print;
final logger = lRecord.logger;

class CachedSearches {
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
    var t = await (await file.getItem())?.readAsString();
    return (t != null)
        ? CachedSearches.loadFromJson(jsonDecode(t))
        : _searches = const <SearchData>[];
  }

  static List<SearchData> loadFromJson(JsonMap json) =>
      searches = (json as List).mapAsList((e, i, l) => SearchData.fromJson(e));
  static List toJson() => _searches;

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

  static void clear() {
    searches = const <SearchData>[];
  }

  static void onSearchBegan(SearchArgs a) {
    _searches = _searches.toList()..add(SearchData.fromList(tagList: a.tags));
    _save();
  }

  static void _save() {
    print("Writing search cache");
    file
        .getItem()
        .then<Object?>((v) =>
            v?.writeAsString(jsonEncode(CachedSearches.toJson())) ??
            Future.sync(() => null))
        .then(
          (value) => print(
              "Write ${value == null ? "not performed" : "presumably successful"}"),
        );
  }
}

class CachedSearchesEvent extends JEventArgs {
  final List<SearchData> priorValue;
  final List<SearchData> currentValue;

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
    searches.add(a.tags.foldToString(" "));
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