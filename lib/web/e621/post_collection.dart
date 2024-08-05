import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_cache.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';

import 'post_search_parameters.dart';

final class E6PostEntry extends IE6PostEntry // LinkedListEntry<E6PostEntry>
    with
        ValueAsyncMixin<E6PostResponse> {
  // #region Logger
  static late final lRecord = lm.genLogger("E6PostEntry");
  static lm.FileLogger get logger => lRecord.logger;
  static lm.Printer get print => lRecord.print;
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

final class E6PostEntrySync extends LinkedListEntry<E6PostEntrySync>
    with ValueAsyncMixin<E6PostResponse> {
  // #region Logger
  static late final lRecord = lm.genLogger("E6PostEntrySync");
  static lm.FileLogger get logger => lRecord.logger;
  static lm.Printer get print => lRecord.print;
  // #endregion Logger

  @override
  final ValueAsync<E6PostResponse> inst;

  @override
  final E6PostResponse value;
  E6PostEntrySync({required this.value})
      : inst = ValueAsync.catchError(
            value: value,
            cacheErrors: false,
            catchError: (e, s) {
              logger.severe("Failed to resolve post", e, s);
              return E6PostResponse.error;
            });
  @override
  E6PostResponse get $ => value;

  @override
  E6PostResponse? get $Safe => value;
}

sealed class IE6PostEntry extends LinkedListEntry<E6PostEntry> {
  E6PostResponse get $;

  E6PostResponse? get $Safe;
  ValueAsync<E6PostResponse> get inst;
  FutureOr<E6PostResponse> get value;
}

/* class ManagedPostCollection extends SearchCacheLegacy {
  // #region Fields
  bool treatAsNull = true;
  final PostCollection collection;
  PostPageSearchParameters _parameters;
  int _startingPage = 0;
  int _currentPageOffset;
  E6Posts? _e6posts;
  int _currentPostIndex = 0;
  // #endregion Fields

  // #region Ctor
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
  // #endregion Ctor

  // #region Properties
  int get currentPage => _startingPage + _currentPageOffset;
  int get currentPostIndex => _currentPostIndex;
  set currentPostIndex(int value) {
    _currentPostIndex = value;
    while (getPageLastPostIndex(currentPage) < _currentPostIndex) {
      goToNextPage();
    }
    while (getPageFirstPostIndex(currentPage) > _currentPostIndex) {
      goToPriorPage();
    }
  }

  /// The index in [collection] of the 1st post of the [currentPage].
  int get currentPageFirstPostIndex =>
      (_startingPage + _currentPageOffset) * SearchView.i.postsPerPage;

  /// The last page of results currently in [collection].
  ///
  /// Defined by [SearchView.postsPerPage].
  int get lastStoredPage => numStoredPages + _startingPage - 1;

  /// How many pages of results are currently in [collection]?
  ///
  /// Defined by [SearchView.postsPerPage].
  int get numStoredPages =>
      (collection._posts.length / SearchView.i.postsPerPage).ceil();

  PostPageSearchParameters get parameters => _parameters;

  set parameters(PostPageSearchParameters value) {
    _parameters = value;
    notifyListeners();
  }

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
    var unlinkIndices = <int>[];
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
        }
      } else {
        if (t != null) {
          collection._posts.add(E6PostEntry(value: t));
        }
      }
    }
    for (var element in unlinkIndices) {
      _getFromStartAndCount(
        start: currentPageFirstPostIndex,
        count: SearchView.i.postsPerPage,
      ).elementAt(element).unlink();
    }
  }

  /// Which page does [collection] start from? Will be used for
  /// optimization (only keep x pages in mem, discard the rest) and
  /// to start a search from page x.
  int get startingPage => _startingPage;
  // #endregion Properties

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
  }

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

  FutureOr<bool> goToNextPage({
    String? username,
    String? apiKey,
  }) async {
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
      final pageIndex = _currentPageOffset - 1 + _startingPage;
      return _fetchPage(_parameters.copyWith(page: pageIndex)).then((v) {
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
        assignPagePosts(pageIndex, v!);
        return true;
      });
    }

    if (currentPage > startingPage) {
      logger.info("Prior page already loaded");
      return true;
    }
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

  /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  E6Posts _genFromRange({int start = 0, int? end}) => _genFromStartAndCount(
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
  Iterable<E6PostEntry> _getFromRange({int start = 0, int? end}) =>
      _getFromStartAndCount(
        start: start,
        count: (end ?? (SearchView.i.postsPerPage + start)) - start,
      );

  /// If null, [count] defaults to [SearchView.i.postsPerPage].
  Iterable<E6PostEntry> _getFromStartAndCount({int start = 0, int? count}) =>
      collection._posts.skip(start).take(count ?? SearchView.i.postsPerPage);
} */

class ManagedPostCollectionSync extends SearchCacheLegacy {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord =
      lm.genLogger("PostCollection", "MPCSync", lm.LogLevel.FINEST);
  // #endregion Logger
  // #region Fields
  bool treatAsNull = true;
  final PostCollectionSync collection;
  PostPageSearchParameters _parameters;
  int _startingPage = 0;
  int _currentPageOffset;
  E6Posts? _e6posts;
  int _currentPostIndex = 0;
  // #endregion Fields

  // #region Ctor
  ManagedPostCollectionSync({
    int currentPageOffset = 0,
    PostSearchParametersSlim parameters = const PostSearchParametersSlim(),
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = PostPageSearchParameters.fromSlim(s: parameters, page: 0),
        _currentPageOffset = currentPageOffset,
        collection = PostCollectionSync(); // {
  //   E621.searchBegan.subscribe(_onUserSearchBegan);
  // }
  ManagedPostCollectionSync.withE6Posts({
    int currentPageOffset = 0,
    required E6Posts posts,
    PostSearchParametersSlim parameters = const PostSearchParametersSlim(),
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = PostPageSearchParameters.fromSlim(s: parameters, page: 0),
        _currentPageOffset = currentPageOffset,
        collection = PostCollectionSync.withPosts(posts: posts.posts); // {
  //   E621.searchBegan.subscribe(_onUserSearchBegan);
  // }
  ManagedPostCollectionSync.withPosts({
    int currentPageOffset = 0,
    required Iterable<E6PostResponse> posts,
    PostSearchParametersSlim parameters = const PostSearchParametersSlim(),
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = PostPageSearchParameters.fromSlim(s: parameters, page: 0),
        _currentPageOffset = currentPageOffset,
        collection = PostCollectionSync.withPosts(posts: posts); // {
  //   E621.searchBegan.subscribe(_onUserSearchBegan);
  // }
  // #endregion Ctor

  // #region Properties
  int get currentPage => _startingPage + _currentPageOffset;

  /// The currently view post index in [collection].
  int get currentPostIndex => _currentPostIndex;

  /// The currently view post index relative to [pageIndex].
  int currentPostIndexOnPage([int? pageIndex]) =>
      getPostIndexOnPage(_currentPostIndex, pageIndex);

  /// Performs background async operation to update [currentPage] accordingly; use [updateCurrentPostIndex] to await its resolution.
  set currentPostIndex(int value) => updateCurrentPostIndex(value);

  /// The index in [collection] of the 1st post of the [currentPage].
  int get currentPageFirstPostIndex =>
      (_startingPage + _currentPageOffset) * SearchView.i.postsPerPage;

  /// The last page of results currently in [collection].
  ///
  /// Defined by [SearchView.postsPerPage].
  int get lastStoredPage => numStoredPages + _startingPage - 1;

  ({
    int minPageIndex,
    int maxPageIndex,
    int numLoadedPages,
  }) get loadedPageRange => (
        minPageIndex: startingPage,
        maxPageIndex: lastStoredPage,
        numLoadedPages: numStoredPages,
      );

  /// How many pages of results are currently in [collection]?
  ///
  /// Defined by [SearchView.postsPerPage].
  int get numStoredPages =>
      (collection._posts.length / SearchView.i.postsPerPage).ceil();

  PostPageSearchParameters get parameters => _parameters;

  set parameters(PostPageSearchParameters value) {
    logger.finest("set parameters called"
        "\n\told:"
        "\n\t\ttags:${_parameters.tags}"
        "\n\t\tlimit:${_parameters.limit}"
        "\n\t\tpageNumber:${_parameters.pageNumber}"
        "\n\tnew:"
        "\n\t\ttags:${value.tags}"
        "\n\t\tlimit:${value.limit}"
        "\n\t\tpageNumber:${value.pageNumber}");
    if (!setEquals(_parameters.tagSet, value.tagSet)) {
      logger.info("Tag Parameter changed from ${_parameters.tagSet} "
          "to ${value.tagSet}, clearing collection and notifying listeners");
      _parameters = value;
      collection.clear();
      logger.finest("Length after clearing: ${collection.length}");
      notifyListeners();
    } else {
      logger.finer("Unchanged tag parameter, not "
          "clearing collection nor notifying listeners");
      _parameters = value;
    }
  }

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

  @override
  set posts(E6Posts? v) {
    if (v == null) {
      treatAsNull = true;
      _e6posts = null;
      notifyListeners();
      return;
    }
    treatAsNull = false;
    v.advanceToEnd();
    if (v.count > collection._posts.length) {
      for (var e in v.posts) {
        collection._posts.add(E6PostEntrySync(value: e));
      }
      return;
    }
    var unlinkIndices = <int>[];
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
        }
      } else {
        if (t != null) {
          collection._posts.add(E6PostEntrySync(value: t));
        }
      }
    }
    for (var element in unlinkIndices) {
      _getFromStartAndCount(
        start: currentPageFirstPostIndex,
        count: SearchView.i.postsPerPage,
      ).elementAt(element).unlink();
    }
  }
  
  Future<SearchResultArgs>? _pr;
  Future<SearchResultArgs>? get pr => _pr;
  set pr(Future<SearchResultArgs>? value) {
    _pr = value;
    notifyListeners();
  }

  String get searchText => _parameters.tags ?? "";
  set searchText(String value) {
    parameters = parameters.copyWith(tags: value);
    // notifyListeners();
  }

  /// Which page does [collection] start from? Will be used for
  /// optimization (only keep x pages in mem, discard the rest) and
  /// to start a search from page x.
  int get startingPage => _startingPage;
  // #endregion Properties

  // ValueAsync<E6Posts?> operator [](final int index) {
  //   if (index < startingPage) {
  //     return ValueAsync<E6Posts?>(
  //         value: (startingPage > 0)
  //             ? ValueAsync.resolve(value: tryRetrieveFormerPage(index))
  //                 .then<E6Posts?>(
  //                 (v) => v
  //                     ? _genFromStartAndCount(
  //                         start: getPageFirstPostIndex(index),
  //                       )
  //                     : null,
  //               )
  //             : null);
  //   } else if (index > lastStoredPage) {
  //     return ValueAsync<E6Posts?>(
  //         value: (hasNextPageCached ?? true)
  //             ? ValueAsync.resolve(value: tryRetrieveFuturePage(index))
  //                 .then<E6Posts?>(
  //                 (v) => v
  //                     ? _genFromStartAndCount(
  //                         start: getPageFirstPostIndex(index),
  //                       )
  //                     : null,
  //               )
  //             : null);
  //   } else /* if (index >= startingPage &&  index <= lastStoredPage)  */ {
  //     return ValueAsync(
  //       value: _genFromStartAndCount(
  //           start: getPageFirstPostIndex(index),
  //           count: SearchView.i.postsPerPage),
  //     );
  //   }
  // }

  /// {@template loadWarn}
  /// If [pageIndex] is not loaded in [collection], it will attempt to load it.
  /// {@endtemplate}
  FutureOr<E6Posts?> getPostsOnPageAsObj(final int pageIndex) =>
      (getPostsOnPageAsObjSync(pageIndex) ??
          getPostsOnPageAsObjAsync(pageIndex)) as FutureOr<E6Posts?>;

  /// {@template notLoadWarn}
  /// If [pageIndex] is not loaded in [collection], it will *NOT* attempt
  ///  to load it, it will return null.
  /// {@endtemplate}
  E6Posts? getPostsOnPageAsObjSync(final int index) => (isPageLoaded(index))
      ? _genFromStartAndCount(
          start: getPageFirstPostIndex(index),
        )
      : null;

  /// {@macro loadWarn}
  Future<E6Posts?> getPostsOnPageAsObjAsync(final int index) async {
    if (lastStoredPage < 0) {
      if (index == 0) {
        return ValueAsync.resolve(value: tryRetrieveFirstPage()).then<E6Posts?>(
          (v) => v
              ? _genFromStartAndCount(
                  start: getPageFirstPostIndex(index),
                )
              : null,
        );
      }
      if (!await tryRetrieveFirstPage()) return null;
    }
    if (index < startingPage) {
      return (startingPage > 0)
          ? ValueAsync.resolve(value: tryRetrieveFormerPage(index))
              .then<E6Posts?>(
              (v) => v
                  ? _genFromStartAndCount(
                      start: getPageFirstPostIndex(index),
                    )
                  : null,
            )
          : null;
    } else if (index > lastStoredPage) {
      return (hasNextPageCached ?? true)
          ? ValueAsync.resolve(value: tryRetrieveFuturePage(index))
              .then<E6Posts?>(
              (v) => v
                  ? _genFromStartAndCount(
                      start: getPageFirstPostIndex(index),
                    )
                  : null,
            )
          : null;
    } else /* if (index >= startingPage && index <= lastStoredPage)  */ {
      return _genFromStartAndCount(
          start: getPageFirstPostIndex(index),
          count: SearchView.i.postsPerPage);
    }
  }

  /// {@macro loadWarn}
  FutureOr<Iterable<E6PostResponse>?> getPostsOnPage(final int index) =>
      (getPostsOnPageSync(index) ?? getPostsOnPageAsync(index))
          as FutureOr<Iterable<E6PostResponse>?>;

  /// {@macro notLoadWarn}
  Iterable<E6PostResponse>? getPostsOnPageSync(final int index) =>
      (isPageLoaded(index))
          ? _getRawPostFromStartAndCount(
              start: getPageFirstPostIndex(index),
            )
          : null;

  /// {@macro loadWarn}
  Future<Iterable<E6PostResponse>?> getPostsOnPageAsync(final int index) async {
    if (lastStoredPage < 0) {
      if (index == 0) {
        return ValueAsync.resolve(value: tryRetrieveFirstPage())
            .then<Iterable<E6PostResponse>?>(
          (v) => v
              ? _getRawPostFromStartAndCount(
                  start: getPageFirstPostIndex(index),
                )
              : null,
        );
      }
      if (!await tryRetrieveFirstPage()) return null;
    }
    if (index < startingPage) {
      return (startingPage > 0)
          ? ValueAsync.resolve(value: tryRetrieveFormerPage(index))
              .then<Iterable<E6PostResponse>?>(
              (v) => v
                  ? _getRawPostFromStartAndCount(
                      start: getPageFirstPostIndex(index),
                    )
                  : null,
            )
          : null;
    } else if (index > lastStoredPage) {
      return (hasNextPageCached ?? true)
          ? ValueAsync.resolve(value: tryRetrieveFuturePage(index))
              .then<Iterable<E6PostResponse>?>(
              (v) => v
                  ? _getRawPostFromStartAndCount(
                      start: getPageFirstPostIndex(index),
                    )
                  : null,
            )
          : null;
    } else /* if (index >= startingPage && index <= lastStoredPage)  */ {
      return _getRawPostFromStartAndCount(
          start: getPageFirstPostIndex(index),
          count: SearchView.i.postsPerPage);
    }
  }

  bool assignPagePosts(
      final int pageIndex, final Iterable<E6PostResponse> toAdd) {
    var start = getPageFirstPostIndex(pageIndex);
    // TODO: Doesn't handle multiple pages past startingPage
    if (start < 0) {
      _startingPage--;
      final t = toAdd.toList();
      do {
        collection._posts.addFirst(E6PostEntrySync(value: t.removeLast()));
      } while (t.isNotEmpty);
      return true;
    } else if (start >= collection._posts.length) {
      collection._posts.addAll(toAdd.map((e) => E6PostEntrySync(value: e)));
      return true;
    } else {
      // TODO: Allow Replacement
      return false;
    }
  }

  /// The index in [collection] of the 1st post of the [pageIndex]th overall page.
  ///
  /// If the value
  /// {@template negativePageIndexWarn}
  /// is negative, the page is not loaded,
  /// and will fail if attempted to reach before loading.
  /// {@endtemplate}
  int getPageFirstPostIndex(int pageIndex) =>
      (pageIndex - _startingPage) * SearchView.i.postsPerPage;

  /// The index in [collection] of the last post of the [pageIndex]th overall page.
  ///
  /// If the value
  /// {@macro negativePageIndexWarn}
  int getPageLastPostIndex(int pageIndex) =>
      getPageFirstPostIndex(pageIndex + 1) - 1;

  /// Takes the given [postIndexOverall] in [collection] and returns the page index
  /// it's on.
  ///
  /// If the return value
  /// {@macro negativePageIndexWarn}
  ///
  /// If null, [postIndexOverall] defaults to [currentPostIndex].
  int getPageOfGivenPostIndexOnPage([int? postIndexOverall]) =>
      // ((postIndexOverall ?? currentPostIndex) - (_startingPage * SearchView.i.postsPerPage)) ~/
      //     SearchView.i.postsPerPage;
      ((postIndexOverall ?? currentPostIndex) / SearchView.i.postsPerPage -
              _startingPage)
          .toInt();

  /// Takes the given [postIndexOverall] in [collection] and returns the index
  /// relative to the given [pageIndexOverall].
  ///
  /// If the value
  /// {@macro negativePageIndexWarn}
  ///
  /// If null, [pageIndexOverall] defaults to [currentPage].
  /// If null, [postIndexOverall] defaults to [currentPostIndex].
  int getPostIndexOnPage([int? postIndexOverall, int? pageIndexOverall]) =>
      (postIndexOverall ?? currentPostIndex) -
      ((pageIndexOverall ?? currentPage) - _startingPage) *
          SearchView.i.postsPerPage;

  FutureOr<bool> goToNextPage({
    String? username,
    String? apiKey,
  }) async {
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
    if (await tryLoadPriorPage(username: username, apiKey: apiKey)) {
      _currentPageOffset--;
      parameters = _parameters.copyWith(page: currentPage);
      return true;
    } else {
      return false;
    }
  }

  bool isPageLoaded(int pageIndex) =>
      pageIndex >= startingPage && pageIndex <= lastStoredPage;

  bool? couldPageBeLoadable(int pageIndex) => isPageLoaded(pageIndex) ||
          (pageIndex < startingPage && (hasPriorPage ?? false)) ||
          (pageIndex > lastStoredPage && (hasNextPageCached ?? false))
      ? true
      : (pageIndex < startingPage && (hasPriorPage == false)) ||
              (pageIndex > lastStoredPage && (hasNextPageCached == false))
          ? false
          : null;

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
        collection._posts.addAll(v!.map((e) => E6PostEntrySync(value: e)));

        return true;
      });
    }

    // if (lastStoredPage > currentPage) {
    if (isPageLoaded(currentPage + 1)) {
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
      final pageIndex = _currentPageOffset - 1 + _startingPage;
      return _fetchPage(_parameters.copyWith(page: pageIndex)).then((v) {
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
        assignPagePosts(pageIndex, v!);
        return true;
      });
    }

    // if (currentPage > startingPage) {
    if (isPageLoaded(currentPage - 1)) {
      logger.info("Prior page already loaded");
      return true;
    }
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

  FutureOr<bool> tryRetrieveFirstPage({
    String? username,
    String? apiKey,
  }) {
    return _fetchPage(_parameters.copyWith(page: 0)).then((v) {
      if (v?.isEmpty ?? true) {
        logger.info(
          "No page 0 from server\n"
          "\tlimit: ${parameters.limit}\n"
          "\tpageNumber: ${parameters.pageNumber}\n"
          "\ttags: ${parameters.tags}",
        );
        return false;
      }
      logger.info(
        "Got page 0 from server\n"
        "\tlimit: ${parameters.limit}\n"
        "\tpageNumber: ${parameters.pageNumber}\n"
        "\ttags: ${parameters.tags}"
        "Result length: ${v?.length}",
      );
      assignPagePosts(0, v!);
      return true;
    });
  }

  FutureOr<bool> tryRetrievePage(
    int pageIndex, {
    String? username,
    String? apiKey,
  }) async {
    if (lastStoredPage < 0) {
      logger.finer("No stored pages, loading first page.");
    }
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

  Future<void> updateCurrentPostIndex(int newIndex) async {
    _currentPostIndex = newIndex;
    while (getPageLastPostIndex(currentPage) < _currentPostIndex) {
      await goToNextPage();
    }
    while (getPageFirstPostIndex(currentPage) > _currentPostIndex) {
      await goToPriorPage();
    }
  }

  Future<Iterable<E6PostResponse>?> _fetchPage(
      [PostPageSearchParameters? parameters]) {
    parameters ??= _parameters;
    return E621
        .performUserPostSearch(
      limit: parameters.limit,
      pageNumber: (parameters.pageNumber ?? 0) + 1,
      tags: parameters.tags ?? "",
    )
        .then((v) {
      return v.results?.posts;
    });
  }

  /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  E6Posts _genFromRange({int start = 0, int? end}) => _genFromStartAndCount(
        start: start,
        count: (end ?? (SearchView.i.postsPerPage + start)) - start,
      );

  /// If null, [count] defaults to [SearchView.i.postsPerPage].
  E6Posts _genFromStartAndCount({int start = 0, int? count}) => E6PostsSync(
        posts: _getRawPostFromStartAndCount(
          start: start,
          count: count,
        ).toList(),
      );

  /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  Iterable<E6PostResponse> _getRawPostFromRange({int start = 0, int? end}) =>
      _getRawPostFromStartAndCount(
        start: start,
        count: (end ?? (SearchView.i.postsPerPage + start)) - start,
      );

  /// If null, [count] defaults to [SearchView.i.postsPerPage].
  Iterable<E6PostResponse> _getRawPostFromStartAndCount(
          {int start = 0, int? count}) =>
      _getFromStartAndCount(
        start: start,
        count: count,
      ).map((e) => e.$);

  /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  Iterable<E6PostEntrySync> _getFromRange({int start = 0, int? end}) =>
      _getFromStartAndCount(
        start: start,
        count: (end ?? (SearchView.i.postsPerPage + start)) - start,
      );

  /// If null, [count] defaults to [SearchView.i.postsPerPage].
  Iterable<E6PostEntrySync> _getFromStartAndCount(
          {int start = 0, int? count}) =>
      collection._posts.skip(start).take(count ?? SearchView.i.postsPerPage);

  // void _onUserSearchBegan(SearchArgs e) {
  //   if ((_parameters.tagSet?.intersection(e.tagSet).length ?? -5) !=
  //       e.tagSet.length) {
  //     (this as ChangeNotifier).dispose();
  //   }
  // }
}

class PostCollection with ListMixin<E6PostEntry> {
  final LinkedList<E6PostEntry> _posts;
  @Event(name: "addPosts")
  final addPosts = JOwnedEvent<PostCollection, PostCollectionEvent>();
  // #endregion Collection Overrides
  PostCollection() : _posts = LinkedList();
  PostCollection.withPosts({
    required Iterable<E6PostResponse> posts,
  }) : _posts = LinkedList()..addAll(posts.map((e) => E6PostEntry(value: e)));

  @override
  int get length => _posts.length;

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

  LinkedList<E6PostEntry> get posts => _posts;
  @override
  operator [](int index) => _posts.elementAt(index);
  @override
  void operator []=(int index, value) {
    _posts.elementAt(index).$ = value.$;
  }
}

class PostCollectionSync with ListMixin<E6PostEntrySync> {
  final LinkedList<E6PostEntrySync> _posts;
  @Event(name: "addPosts")
  final addPosts = JOwnedEvent<PostCollection, PostCollectionEvent>();
  // #endregion Collection Overrides
  PostCollectionSync() : _posts = LinkedList();
  PostCollectionSync.withPosts({
    required Iterable<E6PostResponse> posts,
  }) : _posts = LinkedList()
          ..addAll(posts.map((e) => E6PostEntrySync(value: e)));

  @override
  int get length => _posts.length;

  // #region Collection Overrides
  @override
  set length(int l) {
    if (l == _posts.length) {
      return;
    } else if (l > _posts.length) {
      throw ArgumentError.value(
        l,
        "l",
        "New length ($l) greater than old length (${_posts.length}). "
            "Can't extend list",
      );
    } else if (l > 0) {
      final t = _posts.take(l).toList();
      _posts.clear();
      _posts.addAll(t);
    } else if (l == 0) {
      _posts.clear();
    } else {
      throw ArgumentError.value(
        l,
        "l",
        "New length ($l) must be greater than 0. ",
      );
    }
  }

  LinkedList<E6PostEntrySync> get posts => _posts;
  @override
  operator [](int index) => _posts.elementAt(index);
  @override
  void operator []=(int index, value) {
    _posts.elementAt(index).$ = value.$;
  }
}

class PostCollectionEvent extends JEventArgs {
  final List<FutureOr<E6PostResponse>> posts;

  PostCollectionEvent({required this.posts});
}

// mixin TypeHelp on SearchCacheLegacy {
//   bool get isMpc => this is ManagedPostCollection;
//   ManagedPostCollection get mpc => this as ManagedPostCollection;
//   bool get isMpcSync => this is ManagedPostCollectionSync;
//   ManagedPostCollectionSync get mpcSync => this as ManagedPostCollectionSync;
//   bool get isScl => !isMpc && !isMpcSync;
// }

abstract interface class ISearchResultSwipePageData {
  Iterable<E6PostResponse> get posts;
  Set<int> get restrictedIndices;
  Set<int> get selectedIndices;

  ISearchResultPageData generateChildData();
}

abstract interface class ISearchResultPageData {
  Iterable<E6PostResponse> get postsOnPage;
  Set<int> get restrictedIndicesOnPage;
  Set<int> get selectedIndicesOnPage;
}

abstract interface class IPostTileData {
  E6PostResponse get post;
  bool get isSelected;
}

abstract interface class IPostTileSwipeRouteData extends IPostTileData {
  Iterable<E6PostResponse> get posts;
}

abstract interface class IPostSwipePageData {
  Iterable<E6PostResponse> get posts;
  int get postIndex;

  IPostPageData generateChildData();
}

abstract interface class IPostPageData {
  /// The post being displayed.
  E6PostResponse get post;
}

// abstract interface class ISelfManagingE6PostCollection
//     extends Iterable<E6PostResponse> {
//   final Iterable<E6PostResponse> postsIterable;
// }
