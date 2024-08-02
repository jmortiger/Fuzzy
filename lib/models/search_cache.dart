import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';

class SearchCache extends ChangeNotifier {
  // #region Logger
  // ignore: unnecessary_late
  static late final lRecord = lm.genLogger("SearchCache");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  Iterable<E6PostEntry>? _posts;
  Iterable<E6PostEntry>? get posts => _posts;
  set posts(Iterable<E6PostEntry>? v) => (this.._posts = v)..notifyListeners();
  int? _firstPostIdCached;
  int? get firstPostIdCached => _firstPostIdCached;
  set firstPostIdCached(int? v) =>
      (this.._firstPostIdCached = v)..notifyListeners();
  int? _lastPostIdCached;
  int? get lastPostIdCached => _lastPostIdCached;
  set lastPostIdCached(int? v) =>
      (this.._lastPostIdCached = v)..notifyListeners();
  int? _lastPostOnPageIdCached;
  int? get lastPostOnPageIdCached => _lastPostOnPageIdCached;
  set lastPostOnPageIdCached(int? v) =>
      (this.._lastPostOnPageIdCached = v)..notifyListeners();
  bool? _hasNextPageCached;
  bool? get hasNextPageCached => _hasNextPageCached;
  set hasNextPageCached(bool? v) =>
      (this.._hasNextPageCached = v)..notifyListeners();
  int? get firstPostOnPageId => posts?. /* tryGet(0) */ firstOrNull?.$Safe?.id;
  bool? get hasPriorPage =>
      firstPostIdCached != null &&
      firstPostIdCached! > (firstPostOnPageId ?? firstPostIdCached!);
  SearchCache({
    // E6PostEntries? posts,
    Iterable<E6PostEntry>? posts,
    int? firstPostIdCached,
    int? lastPostIdCached,
    int? lastPostOnPageIdCached,
    bool? hasNextPageCached,
  })  : _posts = posts,
        _firstPostIdCached = firstPostIdCached,
        _lastPostIdCached = lastPostIdCached,
        _lastPostOnPageIdCached = lastPostOnPageIdCached,
        _hasNextPageCached = hasNextPageCached;

  Future<bool> getHasNextPage({
    required String tags,
    required E6PostEntries posts,
    int? lastPostId,
    // required BuildContext context,
    // required String priorSearchText,
  }) async {
    if (posts == null) throw StateError("No current posts");
    if (lastPostId == null) {
      if (posts.runtimeType == E6PostsLazy) {
        // Advance to the end, fully load the list
        // posts?.tryGet(E621.maxPostsPerSearch + 5);
        posts?.advanceToEnd();
      }
      lastPostId ??= posts!.tryGet(posts!.count - 1)?.$Safe?.id;
    }
    if (lastPostId == null) {
      logger.severe("Couldn't determine current page's last post's id.");
      throw StateError("Couldn't determine current page's last post's id.");
    }
    if (lastPostOnPageIdCached == lastPostId && hasNextPageCached != null) {
      return hasNextPageCached!;
    }
    try {
      lastPostOnPageIdCached = lastPostId;
    } catch (e) {
      print(e);
      lastPostOnPageIdCached = lastPostId;
    }
    // var (:username, :apiKey) = devGetAuth();
    var out = E6PostsSync.fromJson(
      jsonDecode(
        (await (await E621.sendRequest(
          E621.initSearchForLastPostRequest(
            tags: tags, //priorSearchText,
            // apiKey: apiKey,
            // username: username,
          ),
        ))
            .stream
            .bytesToString()),
      ) as JsonOut,
    );
    if (out.posts.isEmpty) {
      try {
        // setState(() {
        hasNextPageCached = false;
        // });
      } catch (e) {
        print(e);
        hasNextPageCached = false;
      }
      return hasNextPageCached = false;
    }
    if (out.posts.length != 1) {
      logger.warning(
        "Last post search gave not 1 but ${out.posts.length} results.",
      );
    }
    try {
      return hasNextPageCached =
          (lastPostId != (lastPostIdCached = out.posts.last.id));
    } catch (e) {
      lastPostIdCached = out.posts.last.id;
      return hasNextPageCached = (lastPostId != out.posts.last.id);
    }
  }
}

class SearchCacheLegacy extends ChangeNotifier {
  // #region Logger
  // ignore: unnecessary_late
  static late final lRecord = lm.genLogger("SearchCache");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  E6Posts? _posts;
  E6Posts? get posts => _posts;
  set posts(E6Posts? v) => (this.._posts = v)..notifyListeners();
  int? _firstPostIdCached;

  /// This should be set immediately upon changing the search terms.
  int? get firstPostIdCached => _firstPostIdCached;
  set firstPostIdCached(int? v) =>
      (this.._firstPostIdCached = v)..notifyListeners();
  int? _lastPostIdCached;
  int? get lastPostIdCached => _lastPostIdCached;
  set lastPostIdCached(int? v) =>
      (this.._lastPostIdCached = v)..notifyListeners();
  int? _lastPostOnPageIdCached;
  int? get lastPostOnPageIdCached => _lastPostOnPageIdCached;
  set lastPostOnPageIdCached(int? v) =>
      (this.._lastPostOnPageIdCached = v)..notifyListeners();
  bool? _hasNextPageCached;
  bool? get hasNextPageCached => _hasNextPageCached;
  set hasNextPageCached(bool? v) =>
      (this.._hasNextPageCached = v)..notifyListeners();
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
    int? lastPostId,
    // required BuildContext context,
    // required String priorSearchText,
  }) {
    if (posts == null) throw StateError("No current posts");
    if (lastPostId == null) {
      if (posts.runtimeType == E6PostsLazy) {
        // Advance to the end, fully load the list
        posts!.advanceToEnd();
      }
      lastPostId ??= posts!.tryGet(posts!.count - 1)?.id;
    }
    if (lastPostId == null) {
      logger.severe("Couldn't determine current page's last post's id.");
      throw StateError("Couldn't determine current page's last post's id.");
    }
    if (lastPostOnPageIdCached == lastPostId && hasNextPageCached != null) {
      return hasNextPageCached!;
    }
    try {
      lastPostOnPageIdCached = lastPostId;
    } catch (e) {
      print(e);
      lastPostOnPageIdCached = lastPostId;
    }
    // var out = E6PostsSync.fromJson(
    //   jsonDecode(
    //     (await (await E621.sendRequest(
    //       E621.initSearchForLastPostRequest(
    //         tags: tags, //priorSearchText,
    //       ),
    //     ))
    //         .stream
    //         .bytesToString()),
    //   ) as JsonOut,
    // );
    // if (out.posts.isEmpty) {
    //   try {
    //     // setState(() {
    //     hasNextPageCached = false;
    //     // });
    //   } catch (e) {
    //     print(e);
    //     hasNextPageCached = false;
    //   }
    //   return hasNextPageCached = false;
    // }
    // if (out.posts.length != 1) {
    //   logger.warning(
    //     "Last post search gave not 1 but ${out.posts.length} results.",
    //   );
    // }
    // try {
    //   return hasNextPageCached =
    //       (lastPostId != (lastPostIdCached = out.posts.last.id));
    // } catch (e) {
    //   lastPostIdCached = out.posts.last.id;
    //   return hasNextPageCached = (lastPostId != out.posts.last.id);
    // };
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
        try {
          // setState(() {
          hasNextPageCached = false;
          // });
        } catch (e) {
          print(e);
          hasNextPageCached = false;
        }
        return hasNextPageCached = false;
      }
      if (out.posts.length != 1) {
        logger.warning(
          "Last post search gave not 1 but ${out.posts.length} results.",
        );
      }
      try {
        return hasNextPageCached =
            (lastPostId != (lastPostIdCached = out.posts.last.id));
      } catch (e) {
        lastPostIdCached = out.posts.last.id;
        return hasNextPageCached = (lastPostId != out.posts.last.id);
      }
    });
  }
}
