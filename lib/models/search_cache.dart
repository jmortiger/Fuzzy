import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';

class SearchCacheLegacy extends ChangeNotifier {
  // bool get isMpc => this is ManagedPostCollection;
  // ManagedPostCollection get mpc => this as ManagedPostCollection;
  bool get isMpcSync => this is ManagedPostCollectionSync;
  ManagedPostCollectionSync get mpcSync => this as ManagedPostCollectionSync;
  bool get isScl => /* !isMpc &&  */ !isMpcSync;
  // #region Logger
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("SearchCache");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  E6Posts? _posts;
  E6Posts? get posts => _posts;
  set posts(E6Posts? v) => (this.._posts = v) /* ..notifyListeners() */;
  int? _firstPostIdCached;

  /// This should be set immediately upon changing the search terms.
  int? get firstPostIdCached => _firstPostIdCached;
  set firstPostIdCached(int? v) =>
      (this.._firstPostIdCached = v) /* ..notifyListeners() */;
  int? _lastPostIdCached;
  int? get lastPostIdCached => _lastPostIdCached;
  set lastPostIdCached(int? v) =>
      (this.._lastPostIdCached = v) /* ..notifyListeners() */;
  int? _lastPostOnPageIdCached;
  int? get lastPostOnPageIdCached => _lastPostOnPageIdCached;
  set lastPostOnPageIdCached(int? v) =>
      (this.._lastPostOnPageIdCached = v) /* ..notifyListeners() */;
  bool? _hasNextPageCached;
  bool? get hasNextPageCached => _hasNextPageCached;
  set hasNextPageCached(bool? v) =>
      (this.._hasNextPageCached = v) /* ..notifyListeners() */;
  int? get firstPostOnPageId => posts?.tryGet(0)?.id;

  /// Assuming the [firstPostIdCached] was correctly assigned, this should always be non-null.
  bool? get hasPriorPage =>
      firstPostIdCached != null &&
      firstPostIdCached! > (firstPostOnPageId ?? firstPostIdCached!);
  SearchCacheLegacy({
    E6Posts? posts,
    int? firstPostIdCached,
    int? lastPostIdCached,
    int? lastPostOnPageIdCached,
    bool? hasNextPageCached,
  })  : _posts = posts,
        _firstPostIdCached = firstPostIdCached,
        _lastPostIdCached = lastPostIdCached,
        _lastPostOnPageIdCached = lastPostOnPageIdCached,
        _hasNextPageCached = hasNextPageCached;

  FutureOr<bool> getHasNextPage({
    required String tags,
    int? lastPostId, // = 9223372036854775807,//double.maxFinite.toInt(),
    // required BuildContext context,
    // required String priorSearchText,
  }) {
    if (posts == null) throw StateError("No current posts");
    if (lastPostId == null) {
      // if (posts.runtimeType == E6PostsLazy) {
      // Advance to the end, fully load the list
      posts!.advanceToEnd();
      // }
      lastPostId ??= posts!.tryGet(posts!.count - 1)?.id;
      // if (lastPostId == null) {
      //   logger.warning(
      //       "Couldn't determine current page's last post's id. Will default to the first page.");
      //   lastPostId = -1;
      // }
    }
    if (lastPostId == null) {
      logger.severe("Couldn't determine current page's last post's id. "
          "To default to the first page, pass in a negative value.");
      throw StateError("Couldn't determine current page's last post's id.");
    }
    if (lastPostOnPageIdCached == lastPostId && hasNextPageCached != null) {
      return hasNextPageCached!;
    }
    return E621
        .sendRequest(
          E621.initSearchForLastPostRequest(
            tags: tags, //priorSearchText,
          ),
        )
        .then((v) => v.stream.bytesToString())
        .then((v) => E6PostsSync.fromJson(
              jsonDecode(v) as JsonOut,
            ))
        .then((out) {
      if (out.posts.isEmpty) {
        // try {
        //   // setState(() {
        //   hasNextPageCached = false;
        //   // });
        // } catch (e) {
        //   print(e);
        //   hasNextPageCached = false;
        // }
        return hasNextPageCached = false;
      }
      if (out.posts.length != 1) {
        logger.warning(
          "Last post search gave not 1 but ${out.posts.length} results.",
        );
      }
      // try {
      if (lastPostId! < 0) {
        lastPostOnPageIdCached = out.posts.first.id + 1;
      }
      return hasNextPageCached =
          (lastPostId != (lastPostIdCached = out.posts.last.id));
      // } catch (e) {
      //   lastPostIdCached = out.posts.last.id;
      //   return hasNextPageCached = (lastPostId != out.posts.last.id);
      // }
    });
  }
}
