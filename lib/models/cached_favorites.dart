import 'dart:async' as async_lib;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';

import '../web/e621/e621.dart';

import 'package:fuzzy/log_management.dart' as lm;

class CachedFavorites extends ChangeNotifier with Storable<CachedFavorites> {
  // #region Logger
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("CachedFavorites");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  static const fileName = "cachedFavorites.json";
  static final fileFullPath = LazyInitializer.immediate(fileFullPathInit);
  static Future<String> fileFullPathInit() async {
    print("fileFullPathInit called");
    try {
      return Platform.isWeb ? "" : "${await appDataPath.getItem()}/$fileName";
    } catch (e) {
      print("Error in CachedFavorites.fileFullPathInit():\n$e");
      return "";
    }
  }

  static async_lib.FutureOr<CachedFavorites> loadFromStorageAsync() async =>
      CachedFavorites.fromJson(
        jsonDecode(
          await Storable.tryLoadStringAsync(await fileFullPath.getItem()) ??
              jsonEncode(CachedFavorites().toJson()),
        ),
      );

  factory CachedFavorites.loadFromStorageSync() => CachedFavorites.fromJson(
        jsonDecode(
          Storable.tryLoadStringSync(fileFullPath.$) ??
              jsonEncode(CachedFavorites().toJson()),
        ),
      );
  factory CachedFavorites.fromJson(JsonMap json) => CachedFavorites(
          postIds: (json["postIds"] as List).mapAsList(
        (e, index, list) => e as int,
      ));
  Map<String, dynamic> toJson() => {
        "postIds": postIds,
      };

  List<int> postIds;

  @Event(name: "Changed")
  final changed = JPureEvent();

  CachedFavorites({List<int>? postIds}) : postIds = postIds ?? <int>[] {
    initStorageAsync(fileFullPath.$);
    E621.favDeleted.subscribe(onFavoriteSlotOpen);
    E621.favFailed.subscribe(onFavFail);
    changed.subscribe(_save);
  }
  void onFavFail(PostActionArgs p) {
    print("cacheAttempt ${p.postId}");
    if (!postIds.contains(p.postId)) {
      postIds.add(p.postId);
      changed.invoke();
    }
  }

  void onFavoriteSlotOpen() {
    print("Fav attempt ${postIds.firstOrNull}");
    if (postIds.isNotEmpty) {
      E621.sendAddFavoriteRequest(postIds.first).then((v2) {
        print("${postIds.first}: ${v2.statusCode}");
        if (v2.statusCodeInfo.isSuccessful) {
          postIds.removeAt(0);
          print("Cached Fav removed");
          changed.invoke();
        }
      });
      // .then((v1) => v1.stream.last.then((v2) {
      //       print("${postIds.first}: ${v1.statusCode}");
      //       if (v1.statusCodeInfo.isSuccessful) {
      //         postIds.removeAt(0);
      //         print("Cached Fav removed");
      //         Changed.invoke();
      //       }
      //     }));
    }
  }

  void _save() {
    notifyListeners();
    tryWriteAsync().then(
      (value) => print(
          "Write ${value ? "successful" : "failed"}: ${jsonEncode(toJson())}"),
    );
  }
}

/* class StoredType extends ChangeNotifier with Storable<StoredType> {
  static const fileName = "StoredType.json";
  static final fileFullPath = LazyInitializer.immediate(fileFullPathInit);
  static Future<String> fileFullPathInit() async {
    print("fileFullPathInit called");
    try {
      return Platform.isWeb ? "" : "${await appDataPath.getItem()}/$fileName";
    } catch (e) {
      print("Error in StoredType.fileFullPathInit():\n$e");
      return "";
    }
  }

  static async_lib.FutureOr<StoredType> loadFromStorageAsync() async =>
      StoredType.fromJson(
        jsonDecode(
          await Storable.tryLoadStringAsync(await fileFullPath.getItem()) ??
              jsonEncode(StoredType().toJson()),
        ),
      );
  factory StoredType.fromJson(JsonMap json) => StoredType();
  Map<String, dynamic> toJson() => {};

  @event
  final Changed = JPureEvent();

  StoredType();

  void _save() {
    notifyListeners();
    tryWriteAsync().then(
      (value) => print("Write ${value ? "successful" : "failed"}"),
    );
  }
}
 */
