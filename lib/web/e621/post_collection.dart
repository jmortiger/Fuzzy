import 'dart:async';
import 'dart:collection';
import 'dart:convert' as dc;

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
  bool tryValidatingSearches = false;
  final PostCollectionSync collection;
  final onPageRetrievalFailure = JEvent<PostCollectionEvent>();
  PostSearchQueryRecord _parameters;
  int _startingPage = 0;
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
    PostSearchQueryRecord? parameters,
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = parameters ?? const PostSearchQueryRecord(),
        _currentPageOffset = 0,
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
    PostSearchQueryRecord? parameters,
    super.firstPostIdCached,
    super.lastPostIdCached,
    super.lastPostOnPageIdCached,
    super.hasNextPageCached,
  })  : _parameters = parameters ?? const PostSearchQueryRecord(),
        _currentPageOffset = 0,
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
  int get currentPageFirstPostIndex =>
      (_startingPage + _currentPageOffset) * SearchView.i.postsPerPage;

  /// The last page of results currently in [collection].
  ///
  /// Defined by [SearchView.postsPerPage].
  int get lastStoredPageIndex => numStoredPages + _startingPage - 1;

  /// The last page of results currently in [collection].
  ///
  /// Defined by [SearchView.postsPerPage].
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
      (collection._posts.length / SearchView.i.postsPerPage).ceil();

  /// How many results are currently in [collection]?
  int get numStoredPosts => collection._posts.length;

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
    if (/* !setEquals(_parameters.tagSet, value.tagSet) */ true) {
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
          ? _genFromStartAndCount(
              start: getPageFirstPostIndex(index),
            )
          : null);
    }
    return await tryRetrievePage(index)
        ? _genFromStartAndCount(
            start: getPageFirstPostIndex(index),
          )
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
      return s.then((v) => v != null
          ? _getRawPostFromStartAndCount(
              start: getPageFirstPostIndex(index),
            )
          : null);
    }
    return await tryRetrievePage(index)
        ? _getRawPostFromStartAndCount(
            start: getPageFirstPostIndex(index),
          )
        : null;
  }

  bool assignPagePosts(
      final int pageIndex, final Iterable<E6PostResponse> toAdd) {
    var start = getPageFirstPostIndex(pageIndex);
    if (start < 0) {
      do {
        _startingPage--;
        start++;
        final t = toAdd.toList();
        do {
          collection._posts.addFirst(E6PostEntrySync(value: t.removeLast()));
        } while (t.isNotEmpty);
      } while (start < 0);
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
    // bool allowJumping = true,
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
    // if (allowJumping &&
    //     (pageIndex < startingPageIndex - 1 ||
    //         pageIndex > lastStoredPageIndex + 1)) {
    //   return _tryRetrieveAndAssignPageBool(pageIndex);
    // }
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
  /// TODO: make handle unloaded pages
  bool isPageAfter(int pageIndex) => (isPageLoaded(pageIndex) &&
      collection.elementAt(getPageLastPostIndex(pageIndex)).$.id !=
          lastPostIdCached);
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
          logger.info(
            "No next page from server\n"
            "\tvalidLimit: ${p.validLimit}\n"
            "\tpageNumber: ${p.pageNumber}\n"
            // "\tpageNumber: ${_currentPageOffset + 1 + _startingPage + 1}\n"
            "\ttags: ${p.tags}",
          );
          return false;
        }
        logger.info(
          "Got next page from server\n"
          "\tvalidLimit: ${p.validLimit}\n"
          "\tpageNumber: ${p.pageNumber}\n"
          // "\tpageNumber: ${_currentPageOffset + 1 + _startingPage + 1}\n"
          "\ttags: ${p.tags}"
          "Result length: ${v?.length}",
        );
        // collection._posts.addAll(v!.map((e) => E6PostEntrySync(value: e)));
        assignPagePosts(p.pageIndex!, v!);

        return true;
      });
    }

    // if (lastStoredPage > currentPage) {
    if (isPageLoaded(currentPageIndex + 1)) {
      logger.info("Next page already loaded");
      return true;
      // } else if (hasNextPageCached ?? false) {
    } else if (!tryValidatingSearches || isPageAfter(currentPageIndex)) {
      return doIt();
    } else {
      return getHasNextPageById(tags: parameters.tags)
          .then((np) => np ? doIt() : false);
      // final t = getHasNextPageById(tags: parameters.tags);
      // return t is Future<bool>
      //     ? t.then((np) => np ? doIt() : false)
      //     : t
      //         ? doIt()
      //         : false;
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
          logger.info(
            "No prior page from server\n"
            "\tvalidLimit: ${p.validLimit}\n"
            "\tpageNumber: ${p.pageNumber}\n"
            "\ttags: ${p.tags}",
          );
          return false;
        }
        logger.info(
          "Got prior page from server\n"
          "\tvalidLimit: ${p.validLimit}\n"
          "\tpageNumber: ${p.pageNumber}\n"
          "\ttags: ${p.tags}"
          "Result length: ${v?.length}",
        );
        assignPagePosts(p.pageIndex!, v!);
        return true;
      });
    }

    // if (currentPage > startingPage) {
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
            logger.info(
              "No prior page from server\n"
              "\tvalidLimit: ${param.validLimit}\n"
              "\tpageNumber: ${param.pageNumber}\n"
              "\ttags: ${param.tags}",
            );
            return false;
          }
          logger.info(
            "Got prior page from server\n"
            "\tvalidLimit: ${param.validLimit}\n"
            "\tpageNumber: ${param.pageNumber}\n"
            "\ttags: ${param.tags}"
            "Result length: ${v?.length}",
          );
          assignPagePosts(p, v!);
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
            logger.info(
              "No page index $p from server\n"
              "\tvalidLimit: ${param.validLimit}\n"
              "\tpageNumber: ${param.pageNumber}\n"
              "\ttags: ${param.tags}",
            );
            return false;
          }
          logger.info(
            "Got page index $p from server\n"
            "\tvalidLimit: ${param.validLimit}\n"
            "\tpageNumber: ${param.pageNumber}\n"
            "\ttags: ${param.tags}"
            "Result length: ${v?.length}",
          );
          assignPagePosts(p, v!);
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
      // } else if (hasNextPageCached ?? false) {
    } else if (!tryValidatingSearches || isPageAfter(pageIndex)) {
      return doIt();
    } else {
      return getHasNextPageById(tags: parameters.tags)
          .then((np) => np ? doIt() : false);
      // final t = getHasNextPageById(tags: parameters.tags);
      // return t is Future<bool>
      //     ? t.then((np) => np ? doIt() : false)
      //     : t
      //         ? doIt()
      //         : false;
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
        logger.info(
          "No page index ${param.pageIndex} from server\n"
          "\tvalidLimit: ${param.validLimit}\n"
          "\tpageNumber: ${param.pageNumber}\n"
          "\ttags: ${param.tags}",
        );
        return false;
      }
      logger.info(
        "Got page ${param.pageIndex} from server\n"
        "\tvalidLimit: ${param.validLimit}\n"
        "\tpageNumber: ${param.pageNumber}\n"
        "\ttags: ${param.tags}"
        "Result length: ${v?.length}",
      );
      assignPagePosts(param.pageIndex!, v!);
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
        logger.info(
          "No page index ${param.pageIndex} from server\n"
          "\tvalidLimit: ${param.validLimit}\n"
          "\tpageNumber: ${param.pageNumber}\n"
          "\ttags: ${param.tags}",
        );
        return false;
      }
      logger.info(
        "Got page ${param.pageIndex} from server\n"
        "\tvalidLimit: ${param.validLimit}\n"
        "\tpageNumber: ${param.pageNumber}\n"
        "\ttags: ${param.tags}"
        "Result length: ${v?.length}",
      );
      assignPagePosts(param.pageIndex!, v!);
      return true;
    });
  }

  FutureOr<bool> tryRetrievePage(
    int pageIndex, {
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

  bool isNewSearch(String newSearchText) =>
      !setEquals(newSearchText.split(RegExp(r"\s")).toSet(), parameters.tagSet);

  /* void _launchSearch({
    BuildContext? context,
    srn.SearchResultsNotifier? searchViewNotifier,
    String tags = "",
    int? limit,
    String? pageModifier,
    int? postId,
    int? pageNumber,
  }) {
    // var sc = Provider.of<ManagedPostCollectionSync>(context, listen: false);
    limit ??= SearchView.i.postsPerPage;
    bool isNewRequest = false;
    var out = "pageModifier = $pageModifier, "
        "postId = $postId, "
        "pageNumber = $pageNumber,"
        // "projectedTrueTags = ${E621.fillTagTemplate(tags)})"
        ")";
    // if (isNewRequest = (sc.priorSearchText != tags)) {
    if (isNewRequest = isNewSearch(tags)) {
      // out = "Request For New Terms: ${sc.priorSearchText} -> $tags ($out";
      out = "Request For New Terms: ${_parameters.tags} -> $tags ($out";
      lastPostIdCached = null;
      firstPostIdCached = null;
      try {
        // sc.searchText = tags;
        parameters = PostSearchQueryRecord(
          tags: tags,
          limit: limit,
          page: encodeValidPageParameterFromOptions(
                  pageModifier: pageModifier,
                  id: postId,
                  pageNumber: pageNumber) ??
              "1",
        );
      } catch (e, s) {
        logger.severe(
            // "Failed to set sc.priorSearchText ${sc.priorSearchText} to $tags",
            "Failed to set sc.parameters.tags ${parameters.tags} to $tags",
            e,
            s);
      }
    } else {
      // out = "Request For Same Terms: ${sc.priorSearchText} ($out";
      out = "Request For Same Terms: ${parameters.tags} = $tags ($out";

      parameters = PostSearchQueryRecord(
        tags: tags,
        limit: limit,
        page: encodeValidPageParameterFromOptions(
                pageModifier: pageModifier,
                id: postId,
                pageNumber: pageNumber) ??
            "1",
      );
    }
    logger.info(out);
    // Provider.of<SearchResultsNotifier?>(context, listen: false)
    // (searchViewNotifier ?? context?.read<srn.SearchResultsNotifier?>())
    (searchViewNotifier ??
            // mounted check?
            ((context != null)
                ? Provider.of<srn.SearchResultsNotifier?>(context,
                    listen: false)
                : null))
        ?.clearSelections();
    // hasNextPageCached = null;
    lastPostOnPageIdCached = null;
    if (true /* isNewRequest */) {
      var username = E621AccessData.fallback?.username,
          apiKey = E621AccessData.fallback?.apiKey;
      pr = E621.performUserPostSearch(
        // tags: AppSettings.i!.forceSafe ? "$tags rating:safe" : tags,
        tags: tags,
        limit: parameters.validLimit,
        pageModifier: parameters.pageModifier,
        pageNumber: parameters.pageNumber,
        postId: parameters.id,
        apiKey: apiKey,
        username: username,
      );
      pr!.then((v) {
        // setState(() {
        print("pr reset");
        pr = null;
        var json = dc.jsonDecode(v.responseBody);
        if (json["success"] == false) {
          print("Response failed: $json");
          if (json["reason"].contains("Access Denied")) {
            if (context != null) {
              showUserMessage(content: Text("Access Denied. Did you mean to login?"));
            }
          }
          posts = E6PostsSync(posts: []);
        } else {
          posts = SearchView.i.lazyLoad
              ? E6PostsLazy.fromJson(json as Map<String, dynamic>)
              : E6PostsSync.fromJson(json as Map<String, dynamic>);
        }
        if (posts?.posts.firstOrNull != null) {
          // if (posts.runtimeType == E6PostsLazy) {
          //   (posts as E6PostsLazy)
          //       .onFullyIterated
          //       .subscribe((a) => getHasNextPage(
          //             tags: priorSearchText,
          //             lastPostId: a.posts.last.id,
          //           ));
          // } else {
          getHasNextPageById(
              tags: searchText,
              lastPostId: (posts as E6PostsSync).posts.last.id);
          // }
        }
        if (isNewRequest) firstPostIdCached = firstPostOnPageId;
        // if (parameters.pageNumber == 1) firstPostIdCached = firstPostOnPageId;
        // });
      }).catchError((err, st) {
        print(err);
        print(st);
      });
    } else {
      // this.isPageLoaded(pageIndex)
      // TODO: This
    }
  } */

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
      [PostSearchQueryRecord? parameters]) {
    parameters ??= _parameters;
    logger.info("Getting page ${parameters.page}");
    return _loading[parameters] ??
        (_loading[parameters] = E621
            .performUserPostSearch(
          limit: parameters.validLimit,
          pageNumber: (parameters.pageNumber ?? 1),
          tags: parameters.tags,
        )
            .then((v) {
          if (v.results == null) {
            onPageRetrievalFailure.invoke(PostCollectionEvent(
                parameters: parameters!, posts: collection));
          }
          return v.results?.posts;
        }))
      ..then((v) => _loading.remove(parameters!));
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
      [PostSearchQueryRecord? parameters]) {
    parameters ??= _parameters;
    logger.info("Getting page ${parameters.page}");
    return _loading[parameters] ??
        (_loading[parameters] = E621
            .performListUserFavsSafe(
          limit: parameters.validLimit,
          page: parameters,
        )
            .then((v) {
          if (v == null) {
            onPageRetrievalFailure.invoke(PostCollectionEvent(
                parameters: parameters!, posts: collection));
          }
          return v;
        }))
      ..then((v) => _loading.remove(parameters!)).ignore();
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

class PostCollectionSync with ListMixin<E6PostEntrySync> {
  final LinkedList<E6PostEntrySync> _posts;
  @Event(name: "addPosts")
  final addPosts = JOwnedEvent<PostCollectionSync, PostCollectionEvent>();
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
  final PostCollectionSync posts;
  final PostSearchQueryRecord parameters;

  PostCollectionEvent({
    required this.parameters,
    required this.posts,
  });
}
