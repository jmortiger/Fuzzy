import 'dart:async' as async_lib;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';

import '../web/e621/e621.dart';

/// ## Initialization
/// * [loadFromStorageAsync] can be used with no prior initialization.
/// * [CachedFavorites.loadFromStorageSync] requires a pre-initialized [fileFullPath].
/// * [CachedFavorites.new] calls [initStorageAsync] w/o waiting.
class CachedFavorites extends ChangeNotifier with Storable<CachedFavorites> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("CachedFavorites").logger;
  static const fileName = "cachedFavorites.json";
  static final fileFullPath = LazyInitializer.immediate(fileFullPathInit);
  static Future<String> fileFullPathInit() async {
    logger.finest("fileFullPathInit called");
    try {
      return Platform.isWeb ? "" : "${await appDataPath.getItem()}/$fileName";
    } catch (e, s) {
      logger.severe("Error in CachedFavorites.fileFullPathInit", e, s);
      return "";
    }
  }

  /// TODO: Web implementation
  static async_lib.FutureOr<CachedFavorites> loadFromStorageAsync() async =>
      CachedFavorites.fromJson(jsonDecode(
        await Storable.tryLoadStringAsync(await fileFullPath.getItem()) ??
            jsonEncode(CachedFavorites().toJson()),
      ));

  /// Requires [fileFullPath] to be initialized.
  /// TODO: Web implementation
  factory CachedFavorites.loadFromStorageSync() => CachedFavorites.fromJson(
        jsonDecode(
          Storable.tryLoadStringSync(fileFullPath.$) ?? jsonEncode(emptyJson),
        ),
      );
  factory CachedFavorites.fromJson(JsonMap json) =>
      CachedFavorites(postIds: json["postIds"].cast<int>().toSet());
  static const emptyJson = {"postIds": <int>[]};
  Map<String, dynamic> toJson() => {"postIds": postIds.toList(growable: false)};

  Set<int> postIds;

  @Event(name: "Changed")
  final changed = JPureEvent();

  @override
  void dispose() {
    E621.favDeleted.unsubscribe(onFavoriteSlotOpen);
    E621.favFailed.unsubscribe(onFavFail);
    changed.unsubscribe(_save);
    super.dispose();
  }

  /// Calls [initStorageAsync]
  CachedFavorites({Iterable<int>? postIds})
      : postIds =
            (postIds is Set<int> ? postIds : postIds?.toSet()) ?? <int>{} {
    initStorageAsync(fileFullPath.$);
    E621.favDeleted.subscribe(onFavoriteSlotOpen);
    E621.favFailed.subscribe(onFavFail);
    changed.subscribe(_save);
  }
  void onFavFail(PostActionArgs p) {
    logger.info("Caching desired favorite #${p.postId}");
    if (!postIds.contains(p.postId)) {
      postIds.add(p.postId);
      changed.invoke();
    }
  }

  void onFavoriteSlotOpen() {
    if (postIds.isNotEmpty) {
      logger.info("Attempting to favorite #${postIds.first} from cache");
      E621.sendAddFavoriteRequest(postIds.first).then((v2) {
        if (v2.statusCodeInfo.isSuccessful) {
          logger.info("Successfully favorited ${postIds.first} from cache");
          postIds.remove(postIds.first);
          changed.invoke();
        } else {
          logger.severe("Failed to favorite ${postIds.first} from cache",
              "${v2.statusCode}: ${v2.reasonPhrase}\n${v2.body}");
        }
      });
    } else {
      logger.fine("No cached favorites to add.");
    }
  }

  Future<void> _save() async {
    notifyListeners();
    if (await tryWriteAsync()) {
      logger.finer("Write successful: ${jsonEncode(toJson())}");
    } else {
      logger.finer("Write failed: ${jsonEncode(toJson())}");
    }
  }
}
