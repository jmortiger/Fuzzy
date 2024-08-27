import 'dart:async';
import 'dart:collection';
import 'dart:convert' as dc;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_cache.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';

import 'post_search_parameters.dart';

final class E6PostEntrySync extends LinkedListEntry<E6PostEntrySync>
    with ValueAsyncMixin<E6PostResponse> {
  // #region Logger
  static lm.FileLogger get logger => lRecord.logger;
  static lm.Printer get print => lRecord.print;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("E6PostEntrySync");
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

typedef CacheType = Iterable<E6PostResponse>?;

class ManagedPostCollectionSync extends SearchCacheLegacy {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("PostCollection",
      className: "MPCSync", level: lm.LogLevel.FINEST);
  // #endregion Logger
  // #region Fields
  bool treatAsNull = true;
  bool tryValidatingSearches = true;
  final PostCollectionSync collection;
  final onPageRetrievalFailure = JEvent<PostCollectionEvent>();
  PostSearchQueryRecord _parameters;
  int _startingPage = 0;
  int _maxLoadedPages;
  int _currentPageOffset;
  E6Posts? _e6posts;
  int _currentPostIndex = 0;
  final _loading = <PostSearchQueryRecord, Future<CacheType>>{};
  Future<CacheType>? checkLoading(PostSearchQueryRecord p) => _loading[p];
  Future<int> _numSearchPostsInit() => E621.findTotalPostNumber(
      tags: parameters.tags, limit: parameters.validLimit)
    ..then((v) {
      // _numPostsInSearch = v;
      _numPagesInSearch = (v / postsPerPage).ceil();
      notifyListeners();
      logger.info("tags: ${parameters.tags} numPostsInSearch: $v");
      return v;
    }).ignore();
  late LazyInitializer<int> _totalPostsInSearch;
  FutureOr<int> get retrieveNumPostsInSearch => _totalPostsInSearch.getItem();
  int? get numPostsInSearch => /* _numPostsInSearch ??  */
      _totalPostsInSearch.$Safe;
  int? _numPagesInSearch;
  int? get numPagesInSearch =>
      _numPagesInSearch ??
      (_totalPostsInSearch.isAssigned
          ? (_totalPostsInSearch.$ / postsPerPage).ceil()
          : _totalPostsInSearch.$Safe);
  int? get numAccessiblePagesInSearch {
    final n = numPagesInSearch;
    return n == null
        ? null
        : n <= E621.maxPageNumber
            ? n
            : E621.maxPageNumber;
  }
  // ValueAsync<int> get numPagesInSearch => _numPostsInSearch != null
  //     ? ValueAsync(value: (_numPostsInSearch! / postsPerPage).ceil())
  //     : ValueAsync(
  //         value: totalPostsInSearch
  //             .getItem()
  //             .then((v) => (v / postsPerPage).ceil()));
  // #endregion Fields

  // #region Ctor
  ManagedPostCollectionSync({
    // int currentPageOffset = 0,
    int maxLoadedPages = 20,
    PostSearchQueryRecord? parameters,
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = parameters ?? const PostSearchQueryRecord(),
        _currentPageOffset = 0,
        _maxLoadedPages = maxLoadedPages,
        _startingPage =
            (parameters ?? const PostSearchQueryRecord()).pageIndex ?? 0,
        collection = PostCollectionSync() {
    _totalPostsInSearch = LazyInitializer<int>(_numSearchPostsInit);
    if (parameters != null) {
      E621
          .sendSearchForFirstPostRequest(tags: parameters.tags)
          .then((v) => logger.info("firstPostId: ${firstPostIdCached = v.id}"))
          .ignore();
      // E621
      //     .findTotalPostNumber(/* limit: parameters.validLimit */)
      // .then((v) => logger.info("tags: ${parameters.tags} numPostsInSearch: ${_numPostsInSearch = v}"))
      _totalPostsInSearch.getItemAsync().onError((e, s) {
        logger.severe(e, e, s);
        return -1;
      }).ignore();
      tryRetrieveFirstPageAsync().ignore();
    }
  }
  ManagedPostCollectionSync._bare({
    // int currentPageOffset = 0,
    int maxLoadedPages = 20,
    PostSearchQueryRecord? parameters,
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = parameters ?? const PostSearchQueryRecord(),
        _currentPageOffset = 0,
        _maxLoadedPages = maxLoadedPages,
        _startingPage =
            (parameters ?? const PostSearchQueryRecord()).pageIndex ?? 0,
        collection = PostCollectionSync();
  // #endregion Ctor

  // #region Properties
  int get currentPageIndex => _startingPage + _currentPageOffset;
  int get currentPageNumber => currentPageIndex + 1;

  /// The currently view post index in [collection].
  int get currentPostIndex => _currentPostIndex;

  /// The currently view post index relative to [pageIndex].
  int currentPostIndexOnPage([int? pageIndex]) =>
      getPostIndexOnPage(_currentPostIndex, pageIndex);

  /// Performs background async operation to update [currentPageIndex] accordingly; use [updateCurrentPostIndex] to await its resolution.
  set currentPostIndex(int value) => updateCurrentPostIndex(value);

  /// The index in [collection] of the 1st post of the [currentPageIndex].
  ///
  /// Dependant on [SearchView.postsPerPage].
  int get currentPageFirstPostIndex =>
      (_startingPage + _currentPageOffset) * SearchView.i.postsPerPage;

  /// The last page of results currently in [collection].
  ///
  /// Dependant on [numStoredPages].
  int get lastStoredPageIndex => numStoredPages + _startingPage - 1;

  /// The last page of results currently in [collection].
  ///
  /// Dependant on [lastStoredPageIndex].
  int get lastStoredPageNumber => lastStoredPageIndex + 1;

  ({
    int minPageIndex,
    int maxPageIndex,
    int numLoadedPages,
  }) get loadedPageRange => (
        minPageIndex: startingPageIndex,
        maxPageIndex: lastStoredPageIndex,
        numLoadedPages: numStoredPages,
      );

  /// How many pages of results are currently in [collection]?
  ///
  /// Defined by [SearchView.postsPerPage].
  int get numStoredPages =>
      (collection.length / SearchView.i.postsPerPage).ceil();

  /// How many results are currently in [collection]?
  int get numStoredPosts => collection.length;

  int get postsPerPage => SearchView.i.postsPerPage;

  PostSearchQueryRecord get parameters => _parameters;

  set parameters(PostSearchQueryRecord value) {
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
      lastPostIdCached = firstPostIdCached = /* hasNextPageCached =  */
          lastPostOnPageIdCached = null;
      collection.clear();
      logger.finest("Length after clearing: ${collection.length}");
      _numPagesInSearch = null;
      _totalPostsInSearch = LazyInitializer<int>(_numSearchPostsInit)
        ..getItemAsync().ignore();
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
                  collection.elementAtOrNull(currentPageFirstPostIndex)?.inst.$
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
    if (v.count > collection.length) {
      collection.addAll(v.posts.map((e) => E6PostEntrySync(value: e)));
      // for (var e in v.posts) {
      //   collection.add(E6PostEntrySync(value: e));
      // }
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
      // _getFromStartAndCount(
      //   start: currentPageFirstPostIndex,
      //   count: SearchView.i.postsPerPage,
      // ).elementAt(element).unlink();
      subset.elementAt(element).unlink();
    }
  }

  Future<SearchResultArgs>? _pr;

  /// TODO: Refactor to remove
  Future<SearchResultArgs>? get pr => _pr;
  set pr(Future<SearchResultArgs>? value) {
    _pr = value;
    notifyListeners();
  }

  String get searchText => _parameters.tags;
  set searchText(String value) {
    parameters = parameters.copyWith(tags: value);
    // notifyListeners();
  }

  /// Which page does [collection] start from? Will be used for
  /// optimization (only keep x pages in mem, discard the rest) and
  /// to start a search from page x.
  int get startingPageIndex => _startingPage;

  /// Which 1 based page does [collection] start from? Will be used for
  /// optimization (only keep x pages in mem, discard the rest) and
  /// to start a search from page x.
  int get startingPageNumber => startingPageIndex + 1;
  // #endregion Properties

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
    final s = checkLoading(parameters.copyWith(pageIndex: index + 1));
    if (s != null) {
      return s.then((v) => v != null
          ? E6PostsSync(
              posts: v is List<E6PostResponse>
                  ? v
                  : v.toList()) /* _genFromStartAndCount(
              start: getPageFirstPostIndex(index),
            ) */
          : null);
    }
    return await tryRetrievePage(index)
        ? _genFromStartAndCount(start: getPageFirstPostIndex(index))
        : null;
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
    final s = checkLoading(parameters.copyWith(pageIndex: index + 1));
    if (s != null) {
      return s;
      // return s.then((v) => v != null
      //     ? _getRawPostFromStartAndCount(
      //         start: getPageFirstPostIndex(index),
      //       )
      //     : null);
    }
    return await tryRetrievePage(index)
        ? _getRawPostFromStartAndCount(start: getPageFirstPostIndex(index))
        : null;
  }

  bool _assignPagePostsContiguous(
    final int pageIndex,
    final Iterable<E6PostResponse> toAdd, {
    bool reassign = false,
  }) {
    logger.info("_assignPagePostsContiguous: (index: $pageIndex)");
    if (pageIndex >= startingPageIndex && pageIndex <= lastStoredPageIndex) {
      if (!reassign) return false;
    }
    if (pageIndex > lastStoredPageIndex + 1) {
      logger.info("WHY");
    }
    var start = getPageFirstPostIndex(pageIndex);
    if (start < 0) {
      if (pageIndex < 0) {
        throw ArgumentError.value(pageIndex, "pageIndex", "Must be >= 0");
      }
      if (startingPageIndex - pageIndex == 1) {
        _startingPage--;
        final t = toAdd.toList();
        do {
          collection._posts.addFirst(E6PostEntrySync(value: t.removeLast()));
          start++;
        } while (t.isNotEmpty);
        if (numStoredPages > _maxLoadedPages) {
          logger.info(
              "_assignPagePostsContiguous: Resolving too many pages $numStoredPages > $_maxLoadedPages");
          unloadPagesFromEnd(numStoredPages - _maxLoadedPages);
          logger.info(
              "_assignPagePostsContiguous: numStoredPages After: $numStoredPages");
        }
        return true;
      } else {
        // TODO: Implement
        throw UnimplementedError("not implemented");
      }
    } else if (start >= collection._posts.length) {
      collection._posts.addAll(toAdd.map((e) => E6PostEntrySync(value: e)));
      if (numStoredPages > _maxLoadedPages) {
        logger.info(
            "_assignPagePostsContiguous: Resolving too many pages $numStoredPages > $_maxLoadedPages");
        unloadPagesFromStart(numStoredPages - _maxLoadedPages);
        logger.info(
            "_assignPagePostsContiguous: numStoredPages After: $numStoredPages");
      }
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
  /// If null, [pageIndexOverall] defaults to [currentPageIndex].
  /// If null, [postIndexOverall] defaults to [currentPostIndex].
  int getPostIndexOnPage([int? postIndexOverall, int? pageIndexOverall]) =>
      (postIndexOverall ?? currentPostIndex) -
      ((pageIndexOverall ?? currentPageIndex) - _startingPage) *
          SearchView.i.postsPerPage;

  FutureOr<bool> goToNextPage({
    String? username,
    String? apiKey,
  }) async {
    if (await tryLoadNextPage(username: username, apiKey: apiKey)) {
      _currentPageOffset++;
      parameters = _parameters.copyWith(pageIndex: currentPageIndex);
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
      parameters = _parameters.copyWith(pageIndex: currentPageIndex);
      return true;
    } else {
      return false;
    }
  }

  FutureOr<bool> goToPage(
    int pageIndex, {
    bool allowJumping = true,
    String? username,
    String? apiKey,
  }) {
    if (currentPageIndex == pageIndex) return true;
    if (isPageLoaded(pageIndex)) {
      // pageIndex = desiredPageOffset + startingPageIndex
      // currentPageIndex = _currentPageOffset + startingPageIndex
      // currentPageIndex - pageIndex = delta
      // (_currentPageOffset + startingPageIndex) - (desiredPageOffset + startingPageIndex) = delta
      // cpo + spi - dpo - spi = delta
      // cpo - dpo = delta
      // cpo = dpo + delta
      // cpo - delta = dpo
      _currentPageOffset -= currentPageIndex - pageIndex;
      return true;
    }
    if (allowJumping &&
        (pageIndex < startingPageIndex - 1 ||
            pageIndex > lastStoredPageIndex + 1)) {
      return _tryRetrieveAndAssignPageBool(pageIndex);
    }
    if (currentPageIndex > pageIndex) {
      return goToEarlierPage(currentPageIndex - pageIndex);
    } else if (currentPageIndex < pageIndex) {
      return goToFuturePage(pageIndex - currentPageIndex);
    } else {
      return false;
    }
  }

  FutureOr<bool> goToEarlierPage(int numPagesToTravel) async {
    for (; numPagesToTravel > 0 && await goToPriorPage(); numPagesToTravel--) {}
    return numPagesToTravel == 0;
  }

  FutureOr<bool> goToFuturePage(int numPagesToTravel) async {
    for (; numPagesToTravel > 0 && await goToNextPage(); numPagesToTravel--) {}
    return numPagesToTravel == 0;
  }

  /// Is there a page after the given one?
  ///
  /// Compares the last post on the page's id to the cached last id. If ![tryValidatingSearches], use [isPageLoaded] instead.
  bool isPageAfter(int pageIndex) => (isPageLoaded(pageIndex) &&
      collection.elementAt(getPageLastPostIndex(pageIndex)).$.id !=
          lastPostIdCached);

  /// Is there a page before the given one?
  ///
  /// Compares the first post on the page's id to the cached first id. If ![tryValidatingSearches], use [isPageLoaded] instead.
  bool isPageBefore(int pageIndex) =>
      (isPageLoaded(pageIndex) &&
          collection.elementAt(getPageFirstPostIndex(pageIndex)).$.id !=
              firstPostIdCached) ||
      (pageIndex < startingPageIndex && pageIndex >= 0);
  bool isPageLoaded(int pageIndex) =>
      pageIndex >= startingPageIndex && pageIndex <= lastStoredPageIndex;

  bool? couldPageBeLoadable(int pageIndex) => isPageLoaded(pageIndex) ||
          (pageIndex < startingPageIndex && (hasPriorPage ?? false)) ||
          // (pageIndex > lastStoredPageIndex && (hasNextPageCached ?? false))
          (pageIndex > lastStoredPageIndex && (isPageAfter(pageIndex)))
      ? true
      : (pageIndex < startingPageIndex && (hasPriorPage == false)) ||
              // (pageIndex > lastStoredPageIndex && (hasNextPageCached == false))
              (pageIndex > lastStoredPageIndex &&
                  (isPageAfter(pageIndex) == false))
          ? false
          : null;

  FutureOr<bool> tryLoadNextPage({
    String? username,
    String? apiKey,
  }) async {
    FutureOr<bool> doIt() {
      final p = _parameters.copyWith(
          pageIndex: _currentPageOffset + 1 + _startingPage);
      return _fetchPage(p).then((v) {
        if (v?.isEmpty ?? true) {
          return false;
        }
        return true;
      });
    }

    if (isPageLoaded(currentPageIndex + 1)) {
      logger.info("Next page already loaded");
      return true;
    } else if (!tryValidatingSearches || isPageAfter(currentPageIndex)) {
      return doIt();
    } else {
      return getHasNextPageById(tags: parameters.tags)
          .then((np) => np ? doIt() : false);
    }
  }

  FutureOr<bool> tryLoadPriorPage({
    String? username,
    String? apiKey,
  }) {
    FutureOr<bool> doIt() {
      final p = _parameters.copyWith(
          pageIndex: _currentPageOffset - 1 + _startingPage);
      return _fetchPage(p).then((v) {
        if (v?.isEmpty ?? true) {
          return false;
        }
        return true;
      });
    }

    if (isPageLoaded(currentPageIndex - 1)) {
      logger.info("Prior page already loaded");
      return true;
    }
    if (!tryValidatingSearches || (hasPriorPage ?? false)) {
      return doIt();
    } else {
      logger.info(
        "Should be no prior page\n"
        "\tvalidLimit: ${parameters.validLimit}\n"
        "\tpageNumber: ${_currentPageOffset - 1 + _startingPage + 1}\n"
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
        final param = _parameters.copyWith(pageIndex: p);
        return _fetchPage(param).then((v) {
          if (v?.isEmpty ?? true) {
            return false;
          }
          return true;
        });
      }

      bool finalResult;
      for (var delta = currentPageIndex - pageIndex;
          finalResult = delta > 0 &&
              startingPageIndex > pageIndex &&
              await l(startingPageIndex - 1);
          delta--) {}
      return finalResult;
    }

    if (pageIndex > startingPageIndex) {
      logger.info("Page index $pageIndex already loaded");
      return true;
    }
    if (!tryValidatingSearches || (hasPriorPage ?? false)) {
      return doIt();
    } else {
      logger.info(
          "Should be no prior page and therefore no page $pageIndex\n"
              "\tvalidLimit: ${parameters.validLimit}\n"
              "\tpageNumber: ${_currentPageOffset - 1 + _startingPage}\n"
              "\ttags: ${parameters.tags}",
          "\tRequest index: $pageIndex\n");
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
        final param = _parameters.copyWith(pageIndex: p);
        return _fetchPage(param).then((v) {
          if (v?.isEmpty ?? true) {
            return false;
          }
          return true;
        });
      }

      bool finalResult;
      for (var delta = pageIndex - currentPageIndex;
          !(finalResult = !(delta > 0 &&
              lastStoredPageIndex < pageIndex &&
              await l(lastStoredPageIndex + 1)));
          delta--) {}
      return finalResult;
    }

    if (lastStoredPageIndex > pageIndex) {
      logger.info("Page index $pageIndex already loaded");
      return true;
    } else if (!tryValidatingSearches || isPageAfter(pageIndex)) {
      return doIt();
    } else {
      return getHasNextPageById(tags: parameters.tags)
          .then((np) => np ? doIt() : false);
    }
  }

  FutureOr<bool> tryRetrieveFirstPage({
    String? username,
    String? apiKey,
  }) {
    if (isPageLoaded(0)) return true;
    final param = _parameters.copyWith(pageIndex: 0);
    return _fetchPage(param).then((v) {
      if (v?.isEmpty ?? true) {
        return false;
      }
      return true;
    });
  }

  Future<bool> tryRetrieveFirstPageAsync({
    String? username,
    String? apiKey,
  }) {
    final param = _parameters.copyWith(pageIndex: 0);
    return _fetchPage(param).then((v) {
      if (v?.isEmpty ?? true) {
        return false;
      }
      return true;
    });
  }

  FutureOr<bool> tryRetrievePage(
    int pageIndex, {
    bool allowJumping = true,
    String? username,
    String? apiKey,
  }) async {
    if (lastStoredPageIndex < 0) {
      logger.finer("No stored pages, loading first page.");
      if (pageIndex == 0) {
        return tryRetrieveFirstPage();
      } else {
        if (!await tryRetrieveFirstPage()) {
          return false;
        }
      }
    }
    if (isPageLoaded(pageIndex)) return true;
    if (allowJumping &&
        (pageIndex < startingPageIndex - 1 ||
            pageIndex > lastStoredPageIndex + 1)) {
      return _tryRetrieveAndAssignPageDirect(pageIndex);
    }
    if (pageIndex < startingPageIndex) {
      return tryRetrieveFormerPage(pageIndex,
          username: username, apiKey: apiKey);
    } else if (pageIndex > lastStoredPageIndex) {
      return tryRetrieveFuturePage(pageIndex,
          username: username, apiKey: apiKey);
    } else {
      return true;
    }
  }

  bool isNewSearch(String newSearchText) => !setEquals(
      newSearchText.split(RegExp(RegExpExt.whitespacePattern)).toSet(),
      parameters.tagSet);

  Future<void> updateCurrentPostIndex(int newIndex) async {
    _currentPostIndex = newIndex;
    while (getPageLastPostIndex(currentPageIndex) < _currentPostIndex) {
      await goToNextPage();
    }
    while (getPageFirstPostIndex(currentPageIndex) > _currentPostIndex) {
      await goToPriorPage();
    }
  }

  Future<Iterable<E6PostResponse>?> _fetchPage(
    PostSearchQueryRecord parameters, {
    bool assignOnSuccess = true,
  }) {
    logger.info("Getting page ${parameters.page}");
    final t = (_loading[parameters] ??
        (_loading[parameters] = E621
            .performUserPostSearch(
          limit: parameters.validLimit,
          pageNumber: (parameters.pageNumber ?? 1),
          tags: parameters.tags,
        )
            .then((v) {
          if (v.results == null) {
            onPageRetrievalFailure.invoke(
                PostCollectionEvent(parameters: parameters, posts: collection));
          }
          return v.results?.posts;
        }).then((v) {
          _loading.remove(parameters);
          if (v?.isEmpty ?? true) {
            logger.info(
              "No page from server\n"
              "\tpageNumber: ${parameters.pageNumber}\n"
              "\ttags: ${parameters.tags}"
              "\tvalidLimit: ${parameters.validLimit}\n",
            );
          } else {
            logger.info(
              "Got page from server\n"
              "\tpageNumber: ${parameters.pageNumber}\n"
              "\ttags: ${parameters.tags}"
              "\tvalidLimit: ${parameters.validLimit}\n"
              "Result length: ${v?.length}",
            );
            if (assignOnSuccess) {
              _assignPagePostsContiguous(parameters.pageIndex!, v!);
            }
          }
          return v;
        })));
    return /* assignOnSuccess
        ? (t
          ..then((v) {
            if (/* ( */ v?.isNotEmpty ?? false /* ) && assignOnSuccess */) {
              _assignPagePostsContiguous(parameters.pageIndex!, v!);
            }
          }).ignore())
        :  */
        t;
  }

  // Map<int, Iterable<E6PostResponse>>
  Future<bool> _tryRetrieveAndAssignPageBool(
    final int pageIndex, {
    bool reload = false,
  }) async {
    final details = _RequestDetails.loadPage(
        pageIndexToLoad: pageIndex,
        maxLoadedPages: _maxLoadedPages,
        startingPageIndex: startingPageIndex,
        lastStoredPageIndex: lastStoredPageIndex);
    if (details.unloadAny) {
      final pageIndices = List.generate(
        details.requiredPageCount,
        details.unloadFromStart
            ? (index) => index + details.requiredStart
            : (index) => details.requiredEnd - index,
      );
      if (!details.isContiguous) {
        Iterable<E6PostResponse>? assign(
          Iterable<E6PostResponse>? p,
          int e, [
          bool first = false,
        ]) {
          if (p != null) {
            if (first) {
              // if (numStoredPages + 1 > _maxLoadedPages) {
              if (details.unloadFromStart) {
                unloadPagesFromStart(/* 1 */ numStoredPages);
                /* if (first)  */ _startingPage = e;
              } else {
                unloadPagesFromEnd(/* 1 */ numStoredPages);
              }
            }
            _assignPagePostsContiguous(e, p);
          }
          return p;
        }

        Future<bool> i(int e, [bool first = false]) async =>
            ((!reload ? getPostsOnPageSync(e) : null) ??
                assign(
                    await _fetchPage(parameters.copyWith(pageIndex: e),
                        assignOnSuccess: false),
                    e,
                    first)) !=
            null;
        return pageIndices.fold(
                null,
                (prior, e) => (prior is Future<bool>
                    ? prior.then((v) => (v ? i(e) : false) as FutureOr<bool>)
                        as FutureOr<bool>
                    : prior != null
                        ? prior
                            ? i(e)
                            : false as FutureOr<bool>
                        : i(e, true))) ??
            false;
      }
      Future<bool> i(int e) async =>
          ((!reload ? getPostsOnPageSync(e) : null) ??
              await _fetchPage(parameters.copyWith(pageIndex: e),
                  assignOnSuccess: true)) !=
          null;
      return pageIndices.fold(
          true,
          (prior, e) => (prior is Future<bool>
              ? prior.then((v) => (v ? i(e) : false) as FutureOr<bool>)
                  as FutureOr<bool>
              : prior
                  ? i(e)
                  : false as FutureOr<bool>));
    } else {
      return _tryRetrieveAndAssignPages(_RequestDetails.determineRange(
          pageIndex, startingPageIndex, lastStoredPageIndex));
      // return tryRetrievePage(pageIndex);
    }
  }

  Future<bool> _tryRetrieveAndAssignPageDirect(
    final int pageIndex, {
    bool reload = false,
  }) async {
    if (isPageLoaded(pageIndex)) return true;
    var details = _RequestDetails.loadPage(
        pageIndexToLoad: pageIndex,
        maxLoadedPages: _maxLoadedPages,
        startingPageIndex: startingPageIndex,
        lastStoredPageIndex: lastStoredPageIndex);
    if (details.unloadAny) {
      Iterable<int> pageIndices = List.generate(
        details.requiredPageCount,
        /* details.unloadFromStart
            ?  */
        (index) =>
            index +
            details
                .requiredStart /* : (index) => details.requiredEnd - index */,
      );
      Iterable<E6PostResponse>? assign(
        Iterable<E6PostResponse>? p,
        int e, {
        int? toUnload,
        bool first = false,
      }) {
        toUnload ??= numStoredPages;
        if (p != null) {
          if (toUnload > 0) {
            if (details.unloadFromStart) {
              unloadPagesFromStart(toUnload);
              if (first) _startingPage = e;
            } else {
              unloadPagesFromEnd(toUnload);
            }
          }
          _assignPagePostsContiguous(e, p);
        }
        return p;
      }

      if (reload || getPostsOnPageSync(details.requiredEnd) == null) {
        var e = (pageIndices as List<int>).removeLast(),
            f = await _fetchPage(parameters.copyWith(pageIndex: e),
                assignOnSuccess: false);
        for (;
            f == null && pageIndices.isNotEmpty;
            details = _RequestDetails.loadPage(
                pageIndexToLoad: e,
                maxLoadedPages: _maxLoadedPages,
                startingPageIndex: startingPageIndex,
                lastStoredPageIndex: lastStoredPageIndex),
            e = pageIndices.removeLast(),
            f = await _fetchPage(parameters.copyWith(pageIndex: e),
                assignOnSuccess: false)) {}
        if (f == null) {
          return false;
        } else {
          pageIndices =
              details.unloadFromStart ? pageIndices : pageIndices.reversed;
          if (!details.isContiguous) {
            FutureOr<List<Iterable<E6PostResponse>?>> iSlim(
                    int e, FutureOr<List<Iterable<E6PostResponse>?>> c) async =>
                await c
                  ..add((!reload ? getPostsOnPageSync(e) : null) ??
                      await _fetchPage(parameters.copyWith(pageIndex: e),
                          assignOnSuccess: false));
            final r = pageIndices
                .fold<FutureOr<List<Iterable<E6PostResponse>?>>>([],
                    (prior, e) {
              return iSlim(e, prior);
            });
            parse(v) {
              if (details.unloadFromStart) {
                unloadPagesFromStart(numStoredPages);
                _startingPage = pageIndices.first;
                // bool wasAnyNonNull = false;
                for (var i = 0; i < v.length; i++) {
                  // wasAnyNonNull &= v[i] != null;
                  assign(v[i], pageIndices.elementAt(i), toUnload: 0);
                }
                _assignPagePostsContiguous(e, f!);
              } else {
                assign(v.last, pageIndices.last, first: true);
                for (var i = v.length - 1; i > 0; i--) {
                  assign(v[i], pageIndices.elementAt(i), toUnload: 0);
                }
                assign(f, e, toUnload: 0);
              }
              // return wasAnyNonNull;
              return true;
            }

            return r is Future<List<Iterable<E6PostResponse>?>>
                ? r.then(parse) as FutureOr<bool>
                : parse(r);
          } else {
            Future<Iterable<E6PostResponse>?> iSlim(int e) async =>
                (!reload ? getPostsOnPageSync(e) : null) ??
                await _fetchPage(parameters.copyWith(pageIndex: e),
                    assignOnSuccess: false);
            // assignOnSuccess: true);
            final r = pageIndices.fold<FutureOr<Iterable<E6PostResponse>?>>(
                [],
                (prior, e) => (prior is Future<Iterable<E6PostResponse>?>
                    ? prior.then((v) => (v != null
                            ? iSlim(e).then((v1) => assign(v1, e, toUnload: 1))
                            : null) as FutureOr<Iterable<E6PostResponse>?>)
                        as FutureOr<Iterable<E6PostResponse>?>
                    : prior != null
                        ? iSlim(e).then((v1) => assign(v1, e, toUnload: 1))
                        : null as FutureOr<Iterable<E6PostResponse>?>));
            // return r is Future<Iterable<E6PostResponse>?>
            //     ? r.then((v) => v != null) as FutureOr<bool>
            //     : r != null;
            await r;
            assign(f, e, toUnload: 1);
            return true;
          }
        }
      } else {
        pageIndices = details.unloadFromStart
            ? pageIndices
            : (pageIndices as List<int>).reversed;
        logger.info(
            "pageIndices.first: ${pageIndices.first}, pageIndices.last: ${pageIndices.last}");
        Future<bool> i(int e) async =>
            ((!reload ? getPostsOnPageSync(e) : null) ??
                await _fetchPage(parameters.copyWith(pageIndex: e),
                    assignOnSuccess: true)) !=
            null;
        return pageIndices.fold(
            true,
            (prior, e) => (prior is Future<bool>
                ? prior.then((v) => (v ? i(e) : false) as FutureOr<bool>)
                    as FutureOr<bool>
                : prior
                    ? i(e)
                    : false as FutureOr<bool>));
      }
    } else {
      return _tryRetrieveAndAssignPages(_RequestDetails.determineRange(
          pageIndex, startingPageIndex, lastStoredPageIndex));
      // return tryRetrievePage(pageIndex);
    }
  }
  /* Future<Iterable<E6PostResponse>?> _tryRetrieveAndAssignPage(
    final int pageIndex, {
    bool reload = false,
  }) async {
    final details = _RequestDetails.loadPage(
        pageIndexToLoad: pageIndex,
        maxLoadedPages: _maxLoadedPages,
        startingPageIndex: startingPageIndex,
        lastStoredPageIndex: lastStoredPageIndex);
    if (details.unloadAny) {
      final pageIndices = List.generate(
        details.requiredEnd - details.requiredStart,
        details.unloadFromStart
            ? (index) => index + details.requiredStart
            : (index) => details.requiredEnd - index,
      );
      if (!details.isContiguous) {
        Iterable<E6PostResponse>? assign(
          Iterable<E6PostResponse>? p,
          int e, [
          bool first = false,
        ]) {
          if (p != null) {
            if (numStoredPages + 1 > _maxLoadedPages) {
              if (details.unloadFromStart) {
                unloadPagesFromStart(1);
                if (first) _startingPage = e;
              } else {
                unloadPagesFromEnd(1);
              }
            }
            _assignPagePostsContiguous(e, p);
          }
          return p;
        }

        Future<bool> i(int e, [bool first = false]) async =>
            ((!reload ? getPostsOnPageSync(e) : null) ??
                assign(
                    await _fetchPage(parameters.copyWith(pageIndex: e),
                        assignOnSuccess: false),
                    e,
                    first)) !=
            null;
        return pageIndices.fold(
                null,
                (prior, e) => (prior is Future<bool>
                    ? prior.then((v) => (v ? i(e) : false) as FutureOr<bool>)
                        as FutureOr<bool>
                    : prior != null
                        ? prior
                            ? i(e)
                            : false as FutureOr<bool>
                        : i(e, true))) ??
            false;
      }
      Future<bool> i(int e) async =>
          ((!reload ? getPostsOnPageSync(e) : null) ??
              await _fetchPage(parameters.copyWith(pageIndex: e),
                  assignOnSuccess: true)) !=
          null;
      return pageIndices.fold(
          true,
          (prior, e) => (prior is Future<bool>
              ? prior.then((v) => (v ? i(e) : false) as FutureOr<bool>)
                  as FutureOr<bool>
              : prior
                  ? i(e)
                  : false as FutureOr<bool>));
    } else {
      return _tryRetrieveAndAssignPages(_RequestDetails.determineRange(
          pageIndex, startingPageIndex, lastStoredPageIndex));
      // return tryRetrievePage(pageIndex);
    }
  } */

  Future<bool> _tryRetrieveAndAssignPages(
    final (int start, int end) pageIndexRange, {
    bool reload = false,
  }) async {
    final pageIndices = List.generate(
      pageIndexRange.$2 - pageIndexRange.$1,
      (index) => index + pageIndexRange.$1,
    );
    Future<Iterable<E6PostResponse>?>? a(int e) async =>
        (!reload ? getPostsOnPageSync(e) : null) ??
        await _fetchPage(parameters.copyWith(
                pageIndex: e) /* ,
            assignOnSuccess: false */
            );
    return pageIndices.fold(
            true,
            (previousValue, e) => previousValue is Future<bool>
                ? previousValue.then((v) async => await a(e) != null)
                : (() async => await a(e))().then((v) => v != null))
        /* ..then(
        (v) => _assignPagesPostsRange(pageIndexRange,
            v.fold([], (p, e) => e != null ? (p..addAll(e)) : p)),
      ).ignore() */
        ;
  }
  /* Future<List<Iterable<E6PostResponse>?>?> _tryRetrieveAndAssignPages(
    final (int start, int end) pageIndexRange, {
    bool reload = false,
  }) async {
    final details = _RequestDetails(
        pageIndexRangeToLoad: pageIndexRange,
        maxLoadedPages: _maxLoadedPages,
        startingPageIndex: startingPageIndex,
        lastStoredPageIndex: lastStoredPageIndex);
    if (details.unloadAny) {
    } else {
      final pageIndices = List.generate(
        pageIndexRange.$2 - pageIndexRange.$1,
        (index) => index + pageIndexRange.$1,
      );
      return pageIndices.fold<Future<List<Iterable<E6PostResponse>?>>?>(
          null,
          (previousValue, e) => previousValue != null
              ? previousValue.then((v) async => v
                ..add((!reload ? getPostsOnPageSync(e) : null) ??
                    await _fetchPage(parameters.copyWith(pageIndex: e),
                        assignOnSuccess: false)))
              : (() async =>
                      (!reload ? getPostsOnPageSync(e) : null) ??
                      await _fetchPage(parameters.copyWith(pageIndex: e),
                          assignOnSuccess: false))()
                  .then((v) => [v]))
        ?..then(
          (v) => _assignPagesPostsRange(pageIndexRange,
              v.fold([], (p, e) => e != null ? (p..addAll(e)) : p)),
        ).ignore();
    }
  } */

  void unloadPagesFromStart(int count) {
    collection.removeRange(0, postsPerPage * count);
    _startingPage += count;
  }

  void unloadPagesFromEnd(int count) {
    collection.removeRange(
        collection.length - 1 - postsPerPage * count, collection.length);
  }

  // bool _assignPagesPostsRange(final (int start, int end) pageIndexRange,
  //     final List<E6PostResponse> toAdd) {
  //   if (pageIndexRange.$1 < 0) {
  //     throw ArgumentError.value(
  //         pageIndexRange, "pageIndexRange.start", "Must be >= 0");
  //   }
  //   if (pageIndexRange.$1 > pageIndexRange.$2) {
  //     throw ArgumentError.value(
  //         pageIndexRange, "pageIndexRange", "start must be <= end");
  //   }

  //   if (pageIndexRange.$2 - pageIndexRange.$1 > _maxLoadedPages) {
  //     throw ArgumentError.value(pageIndexRange, "pageIndexRange",
  //         "Must contain <= _maxLoadedPages ($_maxLoadedPages)");
  //   }

  //   if (pageIndexRange.$1 >= startingPageIndex &&
  //       pageIndexRange.$1 <= lastStoredPageIndex + 1) {
  //     final desiredPageCount =
  //             math.max(pageIndexRange.$2, lastStoredPageIndex) -
  //                 startingPageIndex,
  //         pagesToRemove = desiredPageCount - _maxLoadedPages;
  //     if (desiredPageCount > _maxLoadedPages) {
  //       unloadPagesFromStart(pagesToRemove);
  //     }
  //     var start = getPageFirstPostIndex(pageIndexRange.$1);
  //     for (var i = toAdd.length;
  //         i > 0 && start < collection.length;
  //         i--, start++) {
  //       collection[start].$ = toAdd.removeAt(0);
  //     }
  //     collection.addAllDirect(toAdd);
  //     assert(numStoredPages <= _maxLoadedPages);
  //     return true;
  //   } else if (pageIndexRange.$2 <= lastStoredPageIndex &&
  //       pageIndexRange.$2 >= startingPageIndex + 1) {
  //     final desiredPageCount = lastStoredPageIndex -
  //             math.min<int>(pageIndexRange.$1, startingPageIndex),
  //         pagesToRemove = desiredPageCount - _maxLoadedPages;
  //     if (desiredPageCount > _maxLoadedPages) {
  //       unloadPagesFromEnd(pagesToRemove);
  //     }
  //     var start = getPageLastPostIndex(pageIndexRange.$2);
  //     for (var i = toAdd.length;
  //         i > 0 && start < collection.length && start >= 0;
  //         i--, start--) {
  //       collection[start].$ = toAdd.removeLast();
  //     }
  //     collection.insertAllDirect(0, toAdd);
  //     assert(numStoredPages <= _maxLoadedPages);
  //     return true;
  //   } else {
  //     collection
  //       ..clear()
  //       ..addAllDirect(toAdd);
  //     _startingPage = pageIndexRange.$1;
  //     return true;
  //   }
  // }

  // /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  // E6Posts _genFromRange({int start = 0, int? end}) => _genFromStartAndCount(
  //       start: start,
  //       count: (end ?? (SearchView.i.postsPerPage + start)) - start,
  //     );

  /// If null, [count] defaults to [SearchView.i.postsPerPage].
  E6Posts _genFromStartAndCount({int start = 0, int? count}) => E6PostsSync(
        posts: _getRawPostFromStartAndCount(
          start: start,
          count: count,
        ).toList(),
      );

  // /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  // Iterable<E6PostResponse> _getRawPostFromRange({int start = 0, int? end}) =>
  //     _getRawPostFromStartAndCount(
  //       start: start,
  //       count: (end ?? (SearchView.i.postsPerPage + start)) - start,
  //     );

  /// If null, [count] defaults to [SearchView.i.postsPerPage].
  Iterable<E6PostResponse> _getRawPostFromStartAndCount(
          {int start = 0, int? count}) =>
      _getFromStartAndCount(
        start: start,
        count: count,
      ).map((e) => e.$);

  // /// If null, [end] defaults to [SearchView.i.postsPerPage] + [start].
  // Iterable<E6PostEntrySync> _getFromRange({int start = 0, int? end}) =>
  //     _getFromStartAndCount(
  //       start: start,
  //       count: (end ?? (SearchView.i.postsPerPage + start)) - start,
  //     );

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

  @override
  Future<bool> getHasNextPageById({
    required String tags,
    int? lastPostId, // = 9223372036854775807,//double.maxFinite.toInt(),
    // required BuildContext context,
    // required String priorSearchText,
    int? pageIndex,
  }) async {
    pageIndex ??= currentPageIndex;
    // if (posts == null) throw StateError("No current posts");
    var posts = this.posts ??= getPostsOnPageAsObjSync(pageIndex);
    posts ??= this.posts ??= await getPostsOnPageAsObjAsync(pageIndex);
    if (posts == null) {
      logger.warning(StateError("No current posts"));
      return false;
    }
    if (lastPostId == null) {
      // if (posts.runtimeType == E6PostsLazy) {
      // Advance to the end, fully load the list
      posts.advanceToEnd();
      // }
      // lastPostId ??= posts!.tryGet(posts!.count - 1)?.id;
      lastPostId ??= posts.lastOrNull?.id;
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
    // if (lastPostOnPageIdCached == lastPostId && hasNextPageCached != null) {
    //   return hasNextPageCached!;
    // }
    if (isPageAfter(pageIndex)) {
      return hasNextPageCached = true;
    }
    return E621
        .sendRequest(
          E621.initSearchForLastPostRequest(
            tags: tags, //priorSearchText,
          ),
        )
        .then((v) => v.stream.bytesToString())
        .then((v) => E6PostsSync.fromJson(
              dc.jsonDecode(v) as JsonOut,
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

  Future<bool> getHasNextPageByPageIndex({
    required String tags,
    // required BuildContext context,
    // required String priorSearchText,
    int? pageIndex,
  }) async {
    pageIndex ??= currentPageIndex;
    // if (posts == null) throw StateError("No current posts");
    var posts = this.posts ??= getPostsOnPageAsObjSync(pageIndex);
    posts ??= this.posts ??= await getPostsOnPageAsObjAsync(pageIndex);
    if (posts == null) {
      logger.warning(StateError("No current posts"));
      return false;
    }
    // if (lastPostOnPageIdCached == lastPostId && hasNextPageCached != null) {
    //   return hasNextPageCached!;
    // }
    if (isPageAfter(pageIndex)) {
      return hasNextPageCached = true;
    }
    return E621
        .sendRequest(
          E621.initSearchForLastPostRequest(
            tags: tags, //priorSearchText,
          ),
        )
        .then((v) => v.stream.bytesToString())
        .then((v) => E6PostsSync.fromJson(
              dc.jsonDecode(v) as JsonOut,
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
      // Advance to the end, fully load the list
      posts!.advanceToEnd();
      final lastPostId = posts.lastOrNull?.id;
      if (lastPostId == null) {
        logger.severe("Couldn't determine current page's last post's id. "
            "To default to the first page, pass in a negative value.");
        throw StateError("Couldn't determine current page's last post's id.");
      }
      // try {
      if (lastPostId < 0) {
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

class FavoritesCollectionLoader extends ManagedPostCollectionSync {
  static lm.FileLogger get logger => ManagedPostCollectionSync.logger;
  @override
  bool get tryValidatingSearches => false;
  @override
  set tryValidatingSearches(bool _) => false;
  @override
  Future<int> _numSearchPostsInit() => E621.findTotalResultNumberInFavs(
        // tags: parameters.tags,
        limit: parameters.validLimit,
      )..then((v) {
          // _numPostsInSearch = v;
          _numPagesInSearch = (v / postsPerPage).ceil();
          notifyListeners();
          logger.info("tags: ${parameters.tags} numPostsInSearch: $v");
          return v;
        }).ignore();

  @override
  PostSearchQueryRecord get parameters => _parameters;

  @override
  set parameters(PostSearchQueryRecord value) {
    logger.finest("set parameters called"
        "\n\told:"
        "\n\t\ttags:${_parameters.tags}"
        "\n\t\tlimit:${_parameters.limit}"
        "\n\t\tpageNumber:${_parameters.pageNumber}"
        "\n\tnew:"
        "\n\t\ttags:${value.tags}"
        "\n\t\tlimit:${value.limit}"
        "\n\t\tpageNumber:${value.pageNumber}"
        "\n\tDisregarding tags");
    value.copyWith(tags: "");
    /* if (!setEquals(_parameters.tagSet, value.tagSet)) {
      logger.info("Tag Parameter changed from ${_parameters.tagSet} "
          "to ${value.tagSet}, clearing collection and notifying listeners");
      _parameters = value;
      lastPostIdCached = firstPostIdCached = /* hasNextPageCached =  */
          lastPostOnPageIdCached = null;
      collection.clear();
      logger.finest("Length after clearing: ${collection.length}");
      _numPagesInSearch = null;
      _totalPostsInSearch = LazyInitializer<int>(_numSearchPostsInit)
        ..getItemAsync().ignore();
      notifyListeners();
    } else { */
    logger.finer("Unchanged tag parameter, not "
        "clearing collection nor notifying listeners");
    _parameters = value;
    // }
  }

  @override
  Future<Iterable<E6PostResponse>?> _fetchPage(
    PostSearchQueryRecord parameters, {
    bool assignOnSuccess = true,
  }) {
    logger.info("Getting page ${parameters.page}");
    final t = (_loading[parameters] ??
        (_loading[parameters] = E621
            .performListUserFavsSafe(
          limit: parameters.validLimit,
          page: parameters,
        )
            .then((v) {
          if (v == null) {
            onPageRetrievalFailure.invoke(
                PostCollectionEvent(parameters: parameters, posts: collection));
          }
          return v;
        }))
      ..then((v) {
        _loading.remove(parameters);
        if (v?.isEmpty ?? true) {
          logger.info(
            "No page from server\n"
            "\tpageNumber: ${parameters.pageNumber}\n"
            "\ttags: ${parameters.tags}"
            "\tvalidLimit: ${parameters.validLimit}\n",
          );
        }
        logger.info(
          "Got page from server\n"
          "\tpageNumber: ${parameters.pageNumber}\n"
          "\ttags: ${parameters.tags}"
          "\tvalidLimit: ${parameters.validLimit}\n"
          "Result length: ${v?.length}",
        );
      }));
    return assignOnSuccess
        ? (t
          ..then((v) {
            if ((v?.isEmpty ?? false) && assignOnSuccess) {
              _assignPagePostsContiguous(parameters.pageIndex!, v!);
            }
          }).ignore())
        : t;
  }

  FavoritesCollectionLoader({
    // int currentPageOffset = 0,
    PostSearchQueryRecord? parameters,
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  }) : super._bare(parameters: parameters) {
    super.tryValidatingSearches = false;
    _totalPostsInSearch = LazyInitializer<int>(_numSearchPostsInit);
    if (parameters != null) {
      _totalPostsInSearch.getItemAsync().onError((e, s) {
        logger.severe(e, e, s);
        return -1;
      }).ignore();
      tryRetrieveFirstPageAsync().ignore;
    }
  }
}

typedef PageRange = ({int start, int end});

class PostCollectionSync with ListMixin<E6PostEntrySync> {
  final LinkedList<E6PostEntrySync> _posts;
  @Event(name: "AddPosts")
  final addPosts = JOwnedEvent<PostCollectionSync, PostCollectionEvent>();
  // #endregion Collection Overrides
  PostCollectionSync()
      : _posts = LinkedList() /* ,
        _pageMappings = {} */
  ;
  PostCollectionSync.withPosts({
    required Iterable<E6PostResponse> posts,
    // required Map<int, PageRange> pageMappings,
  }) : _posts = LinkedList()
          ..addAll(posts.map((e) => E6PostEntrySync(
              value: e))) /* ,
        _pageMappings = pageMappings */
  ;

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

  // final Map<int, PageRange> _pageMappings;

  // bool assignPagePosts(
  //     final int pageIndex, final Iterable<E6PostResponse> toAdd) {
  //   // var start = getPageFirstPostIndex(pageIndex);
  //   final r = _pageMappings[pageIndex];
  //   // if (start < 0) {
  //   if (r == null) {
  //     do {
  //       _startingPage--;
  //       start++;
  //       final t = toAdd.toList();
  //       do {
  //         collection._posts.addFirst(E6PostEntrySync(value: t.removeLast()));
  //       } while (t.isNotEmpty);
  //     } while (start < 0);
  //     return true;
  //   } else if (start >= collection._posts.length) {
  //     collection._posts.addAll(toAdd.map((e) => E6PostEntrySync(value: e)));
  //     return true;
  //   } else {
  //     // TODO: Allow Replacement
  //     return false;
  //   }
  // }

  @override
  E6PostEntrySync elementAt(int index) {
    return _posts.elementAt(index);
  }

  void addAllDirect(Iterable<E6PostResponse> iterable) {
    addAll(iterable.map((e) => E6PostEntrySync(value: e)));
  }

  void insertAllDirect(int index, Iterable<E6PostResponse> iterable) {
    insertAll(index, iterable.map((e) => E6PostEntrySync(value: e)));
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
  final PostCollectionSync posts;
  final PostSearchQueryRecord parameters;

  PostCollectionEvent({
    required this.parameters,
    required this.posts,
  });
}

/// TODO: Add `couldBeContiguous` for when an early termination would be contiguous
class _RequestDetails {
  final int maxLoadedPages;
  late int requestedStart,
      requestedEnd,
      boundedStart,
      boundedEnd,
      requiredStart,
      requiredEnd,
      initialStart,
      initialEnd,
      resultantStart,
      resultantEnd,
      maxPotentialOverlap;
  bool wouldUnloadFromStart;
  late bool isContiguous, couldBeContiguous, hasOverlap, couldHaveOverlap;

  // _RequestDetails({
  //   required this.requestedStart,
  //   required this.requestedEnd,
  //   required this.boundedStart,
  //   required this.boundedEnd,
  //   required this.initialStart,
  //   required this.initialEnd,
  //   required this.resultantStart,
  //   required this.resultantEnd,
  //   required this.unloadFromStart,
  //   required this.maxLoadedPages,
  // });
  _RequestDetails({
    required (int start, int end) pageIndexRangeToLoad,
    required this.maxLoadedPages,
    required final int startingPageIndex,
    required final int lastStoredPageIndex,
    final bool? forceRespectStart,
    final bool expand = true,
  })  : initialStart = startingPageIndex,
        resultantStart = startingPageIndex,
        initialEnd = lastStoredPageIndex,
        resultantEnd = lastStoredPageIndex,
        requestedStart = pageIndexRangeToLoad.$1,
        requestedEnd = pageIndexRangeToLoad.$2,
        requiredStart = pageIndexRangeToLoad.$1,
        requiredEnd = pageIndexRangeToLoad.$2,
        boundedStart = pageIndexRangeToLoad.$1,
        boundedEnd = pageIndexRangeToLoad.$2,
        wouldUnloadFromStart = false {
    if (requestedStart > requestedEnd) {
      throw ArgumentError.value(
          pageIndexRangeToLoad, "pageIndexRangeToLoad", "start must be <= end");
    }
    if (requestedStart < 0) {
      ManagedPostCollectionSync.logger
          .warning("pageIndexRangeToLoad.start < 0, bounding");
      requiredStart = boundedStart = requestedStart = 0;
      // throw ArgumentError.value(
      //     pageIndexRangeToLoad, "pageIndexRangeToLoad.start", "Must be >= 0");
    }

    if (expand) {
      if (boundedStart - initialEnd >= 0) {
        while (
            boundedPageCount < maxLoadedPages && boundedStart > initialStart) {
          requiredStart = --boundedStart;
        }
      } else if (initialStart - boundedEnd >= 0) {
        while (boundedPageCount < maxLoadedPages && boundedEnd < initialEnd) {
          requiredEnd = ++boundedEnd;
        }
      }
    }

    if (boundedPageCount > maxLoadedPages) {
      final toShave = boundedPageCount - maxLoadedPages;
      switch (forceRespectStart) {
        case true:
          requiredEnd = boundedEnd = boundedEnd - toShave;
          break;
        case false:
          requiredStart = boundedStart = boundedStart + toShave;
          break;
        case null:
          final fromStart = (toShave / 2).floor(),
              fromEnd = (toShave / 2).ceil();
          requiredStart = boundedStart = boundedStart + fromStart;
          requiredEnd = boundedEnd = boundedEnd - fromEnd;
          break;
      }
    }
    assert(boundedPageCount <= maxLoadedPages);
    if (boundedStart >= initialStart) {
      isContiguous = boundedStart <= initialEnd + 1;
      hasOverlap = boundedStart <= initialEnd;
      couldHaveOverlap = boundedStart - initialEnd < maxLoadedPages;
      couldBeContiguous = boundedStart - initialEnd < maxLoadedPages + 1;
      maxPotentialOverlap = maxLoadedPages - boundedStart - initialEnd;
      wouldUnloadFromStart = true;
      resultantEnd = math.max(boundedEnd, initialEnd);
      requiredStart =
          unloadAny ? resultantStart += pagesToRemove : resultantStart;
    } else if (boundedEnd <= initialEnd) {
      isContiguous = boundedEnd >= initialStart - 1;
      hasOverlap = boundedEnd >= initialStart;
      couldHaveOverlap = initialStart - boundedEnd < maxLoadedPages;
      couldBeContiguous = initialStart - boundedEnd < maxLoadedPages + 1;
      maxPotentialOverlap = maxLoadedPages - initialStart - boundedEnd;
      wouldUnloadFromStart = false;
      resultantStart = math.min(boundedStart, initialStart);
      requiredEnd = unloadAny ? resultantEnd -= pagesToRemove : resultantEnd;
    } else {
      isContiguous = couldBeContiguous = hasOverlap = couldHaveOverlap = true;
      maxPotentialOverlap = initialPageCount;
      wouldUnloadFromStart = false;
      requiredStart = resultantStart = boundedStart;
      requiredEnd = resultantEnd = boundedEnd;
    }
  }
  _RequestDetails.loadPage({
    required int pageIndexToLoad,
    required final int maxLoadedPages,
    required final int startingPageIndex,
    required final int lastStoredPageIndex,
    final bool? forceRespectStart,
  }) : this(
          pageIndexRangeToLoad: determineRange(
            pageIndexToLoad,
            startingPageIndex,
            lastStoredPageIndex,
          ),
          maxLoadedPages: maxLoadedPages,
          lastStoredPageIndex: lastStoredPageIndex,
          startingPageIndex: startingPageIndex,
          forceRespectStart: forceRespectStart ??
                  determineRange(
                        pageIndexToLoad,
                        startingPageIndex,
                        lastStoredPageIndex,
                      ).$1 ==
                      pageIndexToLoad
              ? true
              : false,
        );
  bool get wouldUnloadFromEnd => !wouldUnloadFromStart;
  bool get unloadAny => pagesToRemove > 0;
  bool get unloadFromEnd => wouldUnloadFromEnd && unloadAny;
  bool get unloadFromStart => wouldUnloadFromStart && unloadAny;
  int get requiredPageCount => requiredEnd - requiredStart + 1;
  int get requestedPageCount => requestedEnd - requestedStart + 1;
  int get resultantPageCount => resultantEnd - resultantStart + 1;
  int get initialPageCount => initialEnd - initialStart + 1;
  int get boundedPageCount => boundedEnd - boundedStart + 1;
  // int get pagesToRemove => resultantPageCount - maxLoadedPages;
  // int get pagesToRemove =>
  //     wouldUnloadFromStart ? pagesToRemoveFromStart : pagesToRemoveFromEnd;
  int get pagesToRemove => wouldUnloadFromStart
      ? pagesToRemoveFromStart >= 0
          ? pagesToRemoveFromStart
          : pagesToRemoveFromEnd
      : pagesToRemoveFromEnd >= 0
          ? pagesToRemoveFromEnd
          : pagesToRemoveFromStart;
  int get pagesToRemoveFromEnd =>
      initialEnd - resultantStart + 1 - maxLoadedPages;
  int get pagesToRemoveFromStart =>
      resultantEnd - initialStart + 1 - maxLoadedPages;
  int get boundedPagesToRemove => wouldUnloadFromStart
      ? boundedPagesToRemoveFromStart >= 0
          ? boundedPagesToRemoveFromStart
          : boundedPagesToRemoveFromEnd
      : boundedPagesToRemoveFromEnd >= 0
          ? boundedPagesToRemoveFromEnd
          : boundedPagesToRemoveFromStart;
  int get boundedPagesToRemoveFromEnd =>
      math.min(pagesToRemoveFromEnd, initialPageCount);
  int get boundedPagesToRemoveFromStart =>
      math.min(pagesToRemoveFromStart, initialPageCount);
  // int get initial
  static (int start, int end) determineRange(
    int pageIndexToLoad,
    int startingPageIndex,
    int lastStoredPageIndex,
  ) {
    return startingPageIndex >= pageIndexToLoad
        ? (pageIndexToLoad, startingPageIndex)
        : pageIndexToLoad >= lastStoredPageIndex
            ? (lastStoredPageIndex, pageIndexToLoad)
            : math.min((startingPageIndex - pageIndexToLoad).abs(),
                        (lastStoredPageIndex - pageIndexToLoad).abs()) ==
                    lastStoredPageIndex
                ? (pageIndexToLoad, lastStoredPageIndex)
                : (startingPageIndex, lastStoredPageIndex);
  }
}
