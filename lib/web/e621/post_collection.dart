import 'dart:async';
import 'dart:collection';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_cache.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/log_management.dart' as lm;

import 'post_search_parameters.dart';

class PostCollectionEvent extends JEventArgs {
  final List<FutureOr<E6PostResponse>> posts;

  PostCollectionEvent({required this.posts});
}

class PostCollection with ListMixin<E6PostEntry> {
  final LinkedList<E6PostEntry> _posts;
  LinkedList<E6PostEntry> get posts => _posts;
  @Event(name: "addPosts")
  final addPosts = JOwnedEvent<PostCollection, PostCollectionEvent>();
  // #region Collection Overrides
  @override
  set length(int l) {
    if (l == _posts.length) {
      return;
    } else if (l >= _posts.length) {
      throw ArgumentError.value(
        l,
        "l",
        "New length ($l) greater than old length (${_posts.length}). "
            "Can't extend list",
      );
    }
  }

  @override
  operator [](int index) => _posts.elementAt(index);

  @override
  void operator []=(int index, value) {
    _posts.elementAt(index).$ = value.$;
  }

  @override
  int get length => _posts.length;
  // #endregion Collection Overrides
  PostCollection() : _posts = LinkedList();
  PostCollection.withPosts({
    required Iterable<E6PostResponse> posts,
  }) : _posts = LinkedList()..addAll(posts.map((e) => E6PostEntry(value: e)));
}

class ManagedPostCollection extends SearchCacheLegacy {
  ManagedPostCollection({
    int currentPageOffset = 0,
    PostSearchParametersSlim parameters = const PostSearchParametersSlim(),
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = PostPageSearchParameters.fromSlim(s: parameters, page: 0),
        _currentPageOffset = currentPageOffset,
        collection = PostCollection();
  ManagedPostCollection.withE6Posts({
    int currentPageOffset = 0,
    required E6Posts posts,
    PostSearchParametersSlim parameters = const PostSearchParametersSlim(),
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = PostPageSearchParameters.fromSlim(s: parameters, page: 0),
        _currentPageOffset = currentPageOffset,
        collection = PostCollection.withPosts(posts: posts.posts);
  ManagedPostCollection.withPosts({
    int currentPageOffset = 0,
    required Iterable<E6PostResponse> posts,
    PostSearchParametersSlim parameters = const PostSearchParametersSlim(),
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = PostPageSearchParameters.fromSlim(s: parameters, page: 0),
        _currentPageOffset = currentPageOffset,
        collection = PostCollection.withPosts(posts: posts);
  bool treatAsNull = true;
  final PostCollection collection;
  PostPageSearchParameters _parameters;
  PostPageSearchParameters get parameters => _parameters;
  set parameters(PostPageSearchParameters value) {
    _parameters = value;
    notifyListeners();
  }

  Future<void> nextPage({
    String? username,
    String? apiKey,
  }) async {
    if (await getHasNextPage(tags: parameters.tags ?? "")) {
      _currentPageOffset++;
      parameters = _parameters.copyWith(page: _parameters.pageNumber! + 1);
    }
  }
  Future<void> priorPage({
    String? username,
    String? apiKey,
  }) async {
    if (hasPriorPage ?? await getHasNextPage(tags: parameters.tags ?? "").then((v) => hasPriorPage!)) {
      _currentPageOffset--;
      parameters = _parameters.copyWith(page: _parameters.pageNumber! - 1);
    }
  }

  int _currentPageOffset;
  E6Posts? _e6posts;
  @override
  E6Posts? get posts => treatAsNull
      ? null
      : _e6posts != null &&
              _e6posts!.tryGet(0) ==
                  collection._posts
                      .elementAtOrNull(
                          SearchView.i.postsPerPage * _currentPageOffset)
                      ?.inst
                      .$
          ? _e6posts
          : _e6posts = E6PostsSync(
              posts: collection._posts
                  .skip(SearchView.i.postsPerPage * _currentPageOffset)
                  .take(SearchView.i.postsPerPage)
                  .map(
                    (e) => e.$,
                  ).toList());
  @override
  set posts(E6Posts? v) {
    if (v == null) {
      treatAsNull = true;
      return;
    }
    treatAsNull = false;
    v.advanceToEnd();
    if (v.count > collection._posts.length) {
      for (var e in v.posts) {
        collection._posts.add(E6PostEntry(value: e));
      }
      return;
    }
    var /* i = 0,  */unlinkIndices = <int>[];
    // for (var element in collection._posts
    //     .skip(SearchView.i.postsPerPage * _currentPageOffset)
    //     .take(SearchView.i.postsPerPage)) {
    //   var t = v.tryGet(i);
    //   if (t != null) {
    //     element.$ = t;
    //   } else {
    //     unlinkIndices.add(i);
    //     // element.unlink();
    //     // var temp = element.next;
    //     // element.next = element.previous
    //   }
    //   i++;
    // }
    var subset = collection._posts
        .skip(SearchView.i.postsPerPage * _currentPageOffset)
        .take(SearchView.i.postsPerPage);
    for (var i = 0; v.tryGet(i) != null; i++) {
      var element = subset.elementAtOrNull(i);
      var t = v.tryGet(i);
      if (element != null) {
        if (t != null) {
          element.$ = t;
        } else {
          unlinkIndices.add(i);
          // element.unlink();
          // var temp = element.next;
          // element.next = element.previous
        }
      } else {
        if (t != null) {
          collection._posts.add(E6PostEntry(value: t));
        }
      }
    }
    for (var element in unlinkIndices) {
      collection._posts
          .skip(SearchView.i.postsPerPage * _currentPageOffset)
          .take(SearchView.i.postsPerPage)
          .elementAt(element)
          .unlink();
      // var temp = element.next;
      // element.next = element.previous
    }
  }
}

class SelfManagedPostCollectionBad extends SearchCache
    implements E6PostEntries {
  PostCollection? _postsStash;
  PostCollection? get postsStash => _postsStash;
  set postsStash(PostCollection? value) {
    _postsStash = value;
    notifyListeners();
  }

  SelfManagedPostCollectionBad({
    PostCollection? postsStash,
  }) : _postsStash = postsStash;

  // @override
  // set posts(Iterable<E6PostEntry>? v) {
  //   postsStash?._posts.clear();
  //   postsStash?._posts.addAll(v!);
  // }

  @override
  Iterable<E6PostEntry> get posts => postsStash!._posts;
  @override
  int get count => postsStash!.length % SearchView.i.postsPerPage;

  @override
  final Set<int> restrictedIndices = {};

  @override
  E6PostEntry? tryGet(int index, {bool checkForValidFileUrl = true}) {
    // TODO: implement tryGet
    throw UnimplementedError();
  }

  @override
  E6PostEntry operator [](int index) {
    // TODO: implement
    // if (_postsStash!.length <= index && !_postCapacity.isAssigned) {
    //   bool mn = false;
    //   for (var i = _postsStash!.length;
    //       i <= index && (mn = _postsStashIterator.moveNext());
    //       i++) {
    //     _postsStash!.add(_postsStashIterator.current);
    //   }
    //   if (mn == false && !isFullyProcessed) {
    //     _postCapacity.$ = _postsStash!.length;
    //     onFullyIterated.invoke(FullyIteratedArgs(_postsStash!));
    //   }
    // }
    return _postsStash![index];
  }

  @override
  void advanceToEnd() {
    tryGet(postsStash!.length +
        (SearchView.i.postsPerPage -
            (postsStash!.length % SearchView.i.postsPerPage)));
  }
}

final class E6PostEntry extends LinkedListEntry<E6PostEntry>
    with ValueAsyncMixin<E6PostResponse> {
  // #region Logger
  static late final lRecord = lm.genLogger("E6PostEntry");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger

  @override
  final ValueAsync<E6PostResponse> inst;

  E6PostEntry({required FutureOr<E6PostResponse> value})
      : inst = ValueAsync.catchError(
            value: value,
            cacheErrors: false,
            catchError: (e, s) {
              logger.severe("Failed to resolve post", e, s);
              return E6PostResponse.error;
            });
}
