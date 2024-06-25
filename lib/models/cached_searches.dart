import 'dart:async' as async_lib;
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';

import '../web/e621/e621.dart';

class CachedSearches extends ChangeNotifier with Storable<CachedSearches> {
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
