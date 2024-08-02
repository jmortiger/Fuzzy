import 'dart:async';
import 'dart:collection';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_cache.dart';
import 'package:fuzzy/web/e621/e621.dart';
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

  /// Currently does not load the next page.
  FutureOr<bool> goToNextPage({
    String? username,
    String? apiKey,
  }) async {
    // FutureOr<bool> doIt() {
    //   _currentPageOffset++;
    //   parameters = _parameters.copyWith(page: currentPage);
    // }
    // if (lastStoredPage > currentPage) {
    //   return doIt();
    // } else if (hasNextPageCached ?? false) {
    //   return doIt();
    // } else if (await getHasNextPage(tags: parameters.tags ?? "")) {
    //   return doIt();
    // }
    if (await tryLoadNextPage(username: username, apiKey: apiKey)) {
      _currentPageOffset++;
      parameters = _parameters.copyWith(page: currentPage);
      return true;
    } else {
      return false;
    }
  }

  FutureOr<bool> goToPriorPage({
    String? username,
    String? apiKey,
  }) async {
    // FutureOr<bool> doIt() {
    //   _currentPageOffset--;
    //   parameters = _parameters.copyWith(page: currentPage);
    // }
    // if (currentPage > startingPage) {
    //   doIt();
    // }
    // // if (hasPriorPage ??
    // //     await getHasNextPage(tags: parameters.tags ?? "")
    // //         .then((v) => hasPriorPage!)) {
    // if (hasPriorPage ?? false) {
    //   doIt();
    // }
    if (await tryLoadPriorPage(username: username, apiKey: apiKey)) {
      _currentPageOffset--;
      parameters = _parameters.copyWith(page: currentPage);
      return true;
    } else {
      return false;
    }
  }

  FutureOr<bool> tryLoadNextPage({
    String? username,
    String? apiKey,
  }) async {
    FutureOr<bool> doIt() {
      return _fetchPage(_parameters.copyWith(
              page: _currentPageOffset + 1 + _startingPage))
          .then((v) {
        if (v?.isEmpty ?? true) {
          logger.info(
            "No next page from server\n"
            "\tlimit: ${parameters.limit}\n"
            "\tpageNumber: ${parameters.pageNumber}\n"
            "\ttags: ${parameters.tags}",
          );
          return false;
        }
        logger.info(
          "Got next page from server\n"
          "\tlimit: ${parameters.limit}\n"
          "\tpageNumber: ${parameters.pageNumber}\n"
          "\ttags: ${parameters.tags}"
          "Result length: ${v?.length}",
        );
        collection._posts.addAll(v!.map((e) => E6PostEntry(value: e.value)));

        return true;
      });
    }

    if (lastStoredPage > currentPage) {
      logger.info("Next page already loaded");
      return true;
    } else if (hasNextPageCached ?? false) {
      return doIt();
    } else {
      final t = getHasNextPage(tags: parameters.tags ?? "");
      return t is Future<bool>
          ? t.then((np) => np ? doIt() : false)
          : t
              ? doIt()
              : false;
    }
  }

  FutureOr<bool> tryLoadPriorPage({
    String? username,
    String? apiKey,
  }) {
    FutureOr<bool> doIt() {
      return _fetchPage(_parameters.copyWith(
              page: _currentPageOffset - 1 + _startingPage))
          .then((v) {
        if (v?.isEmpty ?? true) {
          logger.info(
            "No prior page from server\n"
            "\tlimit: ${parameters.limit}\n"
            "\tpageNumber: ${parameters.pageNumber}\n"
            "\ttags: ${parameters.tags}",
          );
          return false;
        }
        logger.info(
          "Got prior page from server\n"
          "\tlimit: ${parameters.limit}\n"
          "\tpageNumber: ${parameters.pageNumber}\n"
          "\ttags: ${parameters.tags}"
          "Result length: ${v?.length}",
        );
        // _startingPage--;
        // final t = v!.toList();
        // do {
        //   collection._posts.addFirst(E6PostEntry(value: t.removeLast().value));
        // } while (t.isNotEmpty);
        assignPagePosts(parameters.pageNumber!, v!);
        return true;
      });
    }

    if (currentPage > startingPage) {
      logger.info("Prior page already loaded");
      return true;
    }
    // if (hasPriorPage ??
    //     await getHasNextPage(tags: parameters.tags ?? "")
    //         .then((v) => hasPriorPage!)) {
    if (hasPriorPage ?? false) {
      return doIt();
    } else {
      logger.info(
        "Should be no prior page\n"
        "\tlimit: ${parameters.limit}\n"
        "\tpageNumber: ${_currentPageOffset - 1 + _startingPage}\n"
        "\ttags: ${parameters.tags}",
      );
      return false;
    }
  }

  FutureOr<bool> tryRetrievePage(
    int pageIndex, {
    String? username,
    String? apiKey,
  }) async {
    if (pageIndex < startingPage) {
      return tryRetrieveFormerPage(pageIndex,
          username: username, apiKey: apiKey);
    } else if (pageIndex > lastStoredPage) {
      return tryRetrieveFuturePage(pageIndex,
          username: username, apiKey: apiKey);
    } else {
      return true;
    }
  }

  FutureOr<bool> tryRetrieveFuturePage(
    int pageIndex, {
    String? username,
    String? apiKey,
  }) async {
    FutureOr<bool> doIt() async {
      Future<bool> l(int p) {
        return _fetchPage(_parameters.copyWith(page: p)).then((v) {
          if (v?.isEmpty ?? true) {
            logger.info(
              "No page $p from server\n"
              "\tlimit: ${parameters.limit}\n"
              "\tpageNumber: ${parameters.pageNumber}\n"
              "\ttags: ${parameters.tags}",
            );
            return false;
          }
          logger.info(
            "Got page $p from server\n"
            "\tlimit: ${parameters.limit}\n"
            "\tpageNumber: ${parameters.pageNumber}\n"
            "\ttags: ${parameters.tags}"
            "Result length: ${v?.length}",
          );
          /* collection._posts.addAll(v!.map((e) => E6PostEntry(value: e.value))); */
          assignPagePosts(p, v!);
          return true;
        });
      }

      bool finalResult;
      for (var delta = pageIndex - currentPage;
          !(finalResult = !(delta > 0 &&
              lastStoredPage < pageIndex &&
              await l(lastStoredPage + 1)));
          delta--) {}
      return finalResult;
    }

    if (lastStoredPage > pageIndex) {
      logger.info("Page $pageIndex already loaded");
      return true;
    } else if (hasNextPageCached ?? false) {
      return doIt();
    } else {
      final t = getHasNextPage(tags: parameters.tags ?? "");
      return t is Future<bool>
          ? t.then((np) => np ? doIt() : false)
          : t
              ? doIt()
              : false;
    }
  }

  FutureOr<bool> tryRetrieveFormerPage(
    int pageIndex, {
    String? username,
    String? apiKey,
  }) {
    FutureOr<bool> doIt() async {
      Future<bool> l(int p) {
        return _fetchPage(_parameters.copyWith(page: p)).then((v) {
          if (v?.isEmpty ?? true) {
            logger.info(
              "No prior page from server\n"
              "\tlimit: ${parameters.limit}\n"
              "\tpageNumber: ${parameters.pageNumber}\n"
              "\ttags: ${parameters.tags}",
            );
            return false;
          }
          logger.info(
            "Got prior page from server\n"
            "\tlimit: ${parameters.limit}\n"
            "\tpageNumber: ${parameters.pageNumber}\n"
            "\ttags: ${parameters.tags}"
            "Result length: ${v?.length}",
          );
          /* _startingPage--;
          final t = v!.toList();
          do {
            collection._posts
                .addFirst(E6PostEntry(value: t.removeLast().value));
          } while (t.isNotEmpty); */
          assignPagePosts(p, v!);
          return true;
        });
      }

      bool finalResult;
      for (var delta = currentPage - pageIndex;
          finalResult = delta > 0 &&
              startingPage > pageIndex &&
              await l(startingPage - 1);
          delta--) {}
      return finalResult;
    }

    if (pageIndex > startingPage) {
      logger.info("Page $pageIndex already loaded");
      return true;
    }
    // if (hasPriorPage ??
    //     await getHasNextPage(tags: parameters.tags ?? "")
    //         .then((v) => hasPriorPage!)) {
    if (hasPriorPage ?? false) {
      return doIt();
    } else {
      logger.info(
        "Should be no prior page and therefore no page $pageIndex\n"
        "\tlimit: ${parameters.limit}\n"
        "\tpageNumber: ${_currentPageOffset - 1 + _startingPage}\n"
        "\ttags: ${parameters.tags}",
      );
      return false;
    }
  }

  Future<Iterable<ValueAsync<E6PostResponse>>?> _fetchPage(
      [PostPageSearchParameters? parameters]) {
    parameters ??= _parameters;
    return E621
        .performUserPostSearch(
      limit: parameters.limit,
      pageNumber: (parameters.pageNumber ?? 0) + 1,
      tags: parameters.tags ?? "",
    )
        .then((v) {
      return v.results?.posts.map((e) => ValueAsync<E6PostResponse>(value: e));
    });
  }

  int _startingPage = 0;

  /// Which page does [collection] start from? Will be used for
  /// optimization (only keep x pages in mem, discard the rest) and
  /// to start a search from page x.
  int get startingPage => _startingPage;

  int get currentPage => _startingPage + _currentPageOffset;

  /// The index in [collection] of the 1st post of the [currentPage].
  int get currentPageFirstPostIndex =>
      (_startingPage + _currentPageOffset) * SearchView.i.postsPerPage;

  /// The index in [collection] of the 1st post of the [pageIndex]th overall page.
  ///
  /// If the value is negative, the request page is not loaded,
  /// and will fail if attempted to reach before loading.
  int getPageFirstPostIndex(int pageIndex) =>
      (pageIndex - _startingPage) * SearchView.i.postsPerPage;

  /// The index in [collection] of the last post of the [pageIndex]th overall page.
  ///
  /// If the value is negative, the request page is not loaded,
  /// and will fail if attempted to reach before loading.
  int getPageLastPostIndex(int pageIndex) =>
      getPageFirstPostIndex(pageIndex + 1) - 1;

  /// How many pages of results are currently in [collection]?
  ///
  /// Defined by [SearchView.postsPerPage].
  int get numStoredPages =>
      (collection._posts.length / SearchView.i.postsPerPage).ceil();

  /// The last page of results currently in [collection].
  ///
  /// Defined by [SearchView.postsPerPage].
  int get lastStoredPage => numStoredPages + _startingPage - 1;

  ValueAsync<E6Posts?> operator [](final int index) {
    if (index < startingPage) {
      return ValueAsync<E6Posts?>(
          value: (startingPage > 0)
              ? ValueAsync.resolve(value: tryRetrieveFormerPage(index))
                  .then<E6Posts?>(
                  (v) => v
                      ? _genFromStartAndCount(
                          start: getPageFirstPostIndex(index),
                        )
                      : null,
                )
              : null);
    } else if (index > lastStoredPage) {
      return ValueAsync<E6Posts?>(
          value: (hasNextPageCached ?? true)
              ? ValueAsync.resolve(value: tryRetrieveFuturePage(index))
                  .then<E6Posts?>(
                  (v) => v
                      ? _genFromStartAndCount(
                          start: getPageFirstPostIndex(index),
                        )
                      : null,
                )
              : null);
    } else /* if (index >= startingPage &&  index <= lastStoredPage)  */ {
      return ValueAsync(
        value: _genFromStartAndCount(
            start: getPageFirstPostIndex(index),
            count: SearchView.i.postsPerPage),
      );
    }
  }

  bool assignPagePosts(
      final int pageIndex, final Iterable<ValueAsync<E6PostResponse>> toAdd) {
    var start = getPageFirstPostIndex(pageIndex);
    // TODO: Doesn't handle multiple pages past startingPage
    if (start < 0) {
      _startingPage--;
      final t = toAdd.toList();
      do {
        collection._posts.addFirst(E6PostEntry(value: t.removeLast().value));
      } while (t.isNotEmpty);
      return true;
    } else if (start >= collection._posts.length) {
      collection._posts.addAll(toAdd.map((e) => E6PostEntry(value: e.value)));
      return true;
    } else {
      // TODO: Allow Replacement
      return false;
    }
    // if (index < startingPage) {
    //   return (startingPage > 0)
    //           ? ValueAsync.resolve(value: tryRetrieveFormerPage(index))
    //               .then<E6Posts?>(
    //               (v) => v
    //                   ? _genFromStartAndCount(
    //                       start: getPageFirstPostIndex(index),
    //                     )
    //                   : false,
    //             )
    //           : false;
    // } else if (index > lastStoredPage) {
    //   return ValueAsync<E6Posts?>(
    //       value: (hasNextPageCached ?? true)
    //           ? ValueAsync.resolve(value: tryRetrieveFuturePage(index))
    //               .then<E6Posts?>(
    //               (v) => v
    //                   ? _genFromStartAndCount(
    //                       start: getPageFirstPostIndex(index),
    //                     )
    //                   : false,
    //             )
    //           : false);
    // } else /* if (index >= startingPage &&  index <= lastStoredPage)  */ {
    //   return ValueAsync(
    //     value: _genFromStartAndCount(
    //         start: getPageFirstPostIndex(index), count: SearchView.i.postsPerPage),
    //   );
    // }
  }

  int _currentPageOffset;
  E6Posts? _e6posts;
  @override
  E6Posts? get posts => treatAsNull
      ? null
      : _e6posts != null &&
              _e6posts!.tryGet(0) ==
                  collection._posts
                      .elementAtOrNull(currentPageFirstPostIndex)
                      ?.inst
                      .$
          ? _e6posts
          : _e6posts = _genFromStartAndCount(
              start: currentPageFirstPostIndex,
              count: SearchView.i.postsPerPage,
            );

  /// If null, [count] defaults to [SearchView.i.postsPerPage].
  Iterable<E6PostEntry> _getFromStartAndCount({int start = 0, int? count}) =>
      collection._posts.skip(start).take(count ?? SearchView.i.postsPerPage);

  /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  Iterable<E6PostEntry> _getFromRange({int start = 0, int? end}) =>
      _getFromStartAndCount(
        start: start,
        count: (end ?? (SearchView.i.postsPerPage + start)) - start,
      );

  /// If null, [count] defaults to [SearchView.i.postsPerPage].
  E6Posts _genFromStartAndCount({int start = 0, int? count}) => E6PostsSync(
        posts: _getFromStartAndCount(
          start: start,
          count: count,
        ).map((e) => e.$).toList(),
      );

  /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  E6Posts _genFromRange({int start = 0, int? end}) => _genFromStartAndCount(
        start: start,
        count: (end ?? (SearchView.i.postsPerPage + start)) - start,
      );
  @override
  set posts(E6Posts? v) {
    if (v == null) {
      treatAsNull = true;
      _e6posts = null;
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
    var /* i = 0,  */ unlinkIndices = <int>[];
    // for (var element in _getFromStartAndCount(
    //    start: currentPageFirstPostIndex,
    //    count: SearchView.i.postsPerPage,
    //  )) {
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
    // var subset = collection._posts
    //     .skip(currentPageFirstPostIndex)
    //     .take(SearchView.i.postsPerPage);
    var subset = _getFromStartAndCount(
      start: currentPageFirstPostIndex,
      count: SearchView.i.postsPerPage,
    );
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
      // collection._posts
      //     .skip(currentPageFirstPostIndex)
      //     .take(SearchView.i.postsPerPage)
      _getFromStartAndCount(
        start: currentPageFirstPostIndex,
        count: SearchView.i.postsPerPage,
      ).elementAt(element).unlink();
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

sealed class IE6PostEntry extends LinkedListEntry<E6PostEntry> {
  ValueAsync<E6PostResponse> get inst;

  FutureOr<E6PostResponse> get value;
  E6PostResponse get $;
  E6PostResponse? get $Safe;
}

final class E6PostEntry extends IE6PostEntry // LinkedListEntry<E6PostEntry>
    with
        ValueAsyncMixin<E6PostResponse> {
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

final class E6PostEntrySync
    extends IE6PostEntry // LinkedListEntry<E6PostEntrySync>
    with
        ValueAsyncMixin<E6PostResponse> {
  // #region Logger
  static late final lRecord = lm.genLogger("E6PostEntrySync");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger

  @override
  final ValueAsync<E6PostResponse> inst;

  @override
  final E6PostResponse value;
  @override
  E6PostResponse get $ => value;
  @override
  E6PostResponse? get $Safe => value;

  E6PostEntrySync({required this.value})
      : inst = ValueAsync.catchError(
            value: value,
            cacheErrors: false,
            catchError: (e, s) {
              logger.severe("Failed to resolve post", e, s);
              return E6PostResponse.error;
            });
}
