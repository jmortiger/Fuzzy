import 'dart:async';
import 'dart:collection';
import 'dart:convert' as dc;

import 'package:e621/e621_api.dart' show maxPageNumber;
import 'package:flutter/foundation.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_cache.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/util.dart';
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
  // #region Filter Blacklist
  bool _filterBlacklist;

  bool get filterBlacklist => _filterBlacklist;

  set filterBlacklist(bool value) {
    _filterBlacklist = value;
    notifyListeners();
  }
  // #endregion Filter Blacklist

  PostSearchQueryRecord? lastPage;

  bool tryValidatingSearches = false;
  final PostCollectionSync collection;
  final onPageRetrievalFailure = JEvent<PostCollectionEvent>();
  PostSearchQueryRecord get _parameters => PostSearchQueryRecord.withNumber(
        tags: _tags,
        limit: _limit,
        pageNumber: currentPageNumber,
      );
  set _parameters(PostSearchQueryRecord v) {
    _tags = v.tags;
    _limit = v.validLimit;
    _currentPageIndex = v.pageIndex ?? 0;
  }

  String _tags;
  int _limit;
  int _startingPage = 0;
  E6Posts? _e6posts;
  int _currentPostIndex;
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
        : n <= maxPageNumber
            ? n
            : maxPageNumber;
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
    bool filterBlacklist = true,
  })  : _filterBlacklist = filterBlacklist,
        _startingPage =
            (parameters ?? const PostSearchQueryRecord()).pageIndex ?? 0,
        // _currentPageOffset = 0,
        // _parameters = parameters ?? const PostSearchQueryRecord(),
        _limit = (parameters ?? const PostSearchQueryRecord()).validLimit,
        _tags = (parameters ?? const PostSearchQueryRecord()).tags,
        _currentPostIndex =
            ((parameters ?? const PostSearchQueryRecord()).pageIndex ?? 0) *
                (parameters ?? const PostSearchQueryRecord()).validLimit,
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
    bool filterBlacklist = true,
  })  : _filterBlacklist = filterBlacklist,
        _startingPage =
            (parameters ?? const PostSearchQueryRecord()).pageIndex ?? 0,
        // _currentPageOffset = 0,
        // _parameters = parameters ?? const PostSearchQueryRecord(),
        _limit = (parameters ?? const PostSearchQueryRecord()).validLimit,
        _tags = (parameters ?? const PostSearchQueryRecord()).tags,
        _currentPostIndex =
            ((parameters ?? const PostSearchQueryRecord()).pageIndex ?? 0) *
                (parameters ?? const PostSearchQueryRecord()).validLimit,
        collection = PostCollectionSync();
  // #endregion Ctor

  // #region Properties
  int get _currentPageOffset => getPageIndexOfGivenPost();

  /// Performs background async operation to update [currentPostIndex] to the 1st post on the page; use [updateCurrentPostIndex] to await its resolution.
  set _currentPageOffset(int v) {
    if (_currentPageOffset != v - startingPageIndex) {
      updateCurrentPostIndex(getPageFirstPostIndex(v));
    }
  }

  int get currentPageIndex => _startingPage + _currentPageOffset;
  int get _currentPageIndex => currentPageIndex;
  set _currentPageIndex(int v) {
    if (_currentPageIndex != v) _currentPageOffset = v - currentPageIndex;
  }

  int get currentPageNumber => currentPageIndex + 1;

  /// The currently view post index in [collection].
  int get currentPostIndex => _currentPostIndex;

  /// The currently view post index relative to [pageIndex].
  int currentPostIndexOnPage([int? pageIndex]) =>
      getPostIndexOnPage(_currentPostIndex, pageIndex);

  /// Performs background async operation to update [currentPageIndex] accordingly; use [updateCurrentPostIndex] to await its resolution.
  set currentPostIndex(int value) => updateCurrentPostIndex(value);

  /// The index in [collection] of the 1st post of the [currentPageIndex].
  int get currentPageFirstPostIndex => currentPageIndex * postsPerPage;

  /// The last page of results currently in [collection].
  ///
  /// Defined by [postsPerPage].
  int get lastStoredPageIndex => numStoredPages + _startingPage - 1;

  /// The last page of results currently in [collection].
  ///
  /// Defined by [postsPerPage].
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
  /// Defined by [postsPerPage].
  int get numStoredPages => (collection._posts.length / postsPerPage).ceil();

  /// How many results are currently in [collection]?
  int get numStoredPosts => collection._posts.length;

  //// Currently [SearchView.i.postsPerPage]
  int get postsPerPage => SearchView.i.postsPerPage;

  PostSearchQueryRecord get parameters => _parameters;
  void launchOrReloadSearch(PostSearchQueryRecord value) {
    logger.info("Forcibly relaunching search"
        "\n\told:"
        "\n\t\ttags:${parameters.tags}"
        "\n\t\tlimit:${parameters.limit}"
        "\n\t\tpageNumber:${parameters.pageNumber}"
        "\n\tnew:"
        "\n\t\ttags:${value.tags}"
        "\n\t\tlimit:${value.limit}"
        "\n\t\tpageNumber:${value.pageNumber}");
    _parameters = value;
    _reload();
  }

  void _reload() {
    lastPostIdCached = firstPostIdCached = /* hasNextPageCached =  */
        lastPostOnPageIdCached = null;
    collection.clear();
    logger.finest("Length after clearing: ${collection.length}");
    _numPagesInSearch = null;
    _totalPostsInSearch = LazyInitializer<int>(_numSearchPostsInit)
      ..getItemAsync().ignore();
    lastPage = null;
    notifyListeners();
  }

  set parameters(PostSearchQueryRecord value) {
    logger.finest("set parameters called"
        "\n\told:"
        "\n\t\ttags:${parameters.tags}"
        "\n\t\tlimit:${parameters.limit}"
        "\n\t\tpageNumber:${parameters.pageNumber}"
        "\n\tnew:"
        "\n\t\ttags:${value.tags}"
        "\n\t\tlimit:${value.limit}"
        "\n\t\tpageNumber:${value.pageNumber}");
    if (!setEquals(parameters.tagSet, value.tagSet)) {
      logger.info("Tag Parameter changed from ${parameters.tagSet} "
          "to ${value.tagSet}, clearing collection and notifying listeners");
      _parameters = value;
      _reload();
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
          : _e6posts = _genFromRange(
              start: currentPageFirstPostIndex,
            );
  // : _e6posts = _genFromStartAndCount(
  //     start: currentPageFirstPostIndex,
  //     count: postsPerPage,
  //   );

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
      count: postsPerPage,
      ensureCount: false,
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
        count: postsPerPage,
        ensureCount: false,
      ).elementAt(element).unlink();
    }
  }

  String get searchText => parameters.tags;
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
  FutureOr<E6Posts?> getPostsOnPageAsObj(
    final int pageIndex, [
    bool? filterBlacklist,
  ]) =>
      (getPostsOnPageAsObjSync(pageIndex, filterBlacklist) ??
              getPostsOnPageAsObjAsync(pageIndex, filterBlacklist))
          as FutureOr<E6Posts?>;

  /// {@template notLoadWarn}
  /// If [pageIndex] is not loaded in [collection], it will *NOT* attempt
  ///  to load it, it will return null.
  /// {@endtemplate}
  E6Posts? getPostsOnPageAsObjSync(
    final int index, [
    bool? filterBlacklist,
  ]) =>
      (isPageLoaded(index))
          // ? _genFromStartAndCount(
          ? _genFromRange(
              start: getPageFirstPostIndex(index),
              filterBlacklist: filterBlacklist,
            )
          : null;

  /// {@macro loadWarn}
  Future<E6Posts?> getPostsOnPageAsObjAsync(
    final int index, [
    bool? filterBlacklist,
  ]) async {
    final s = checkLoading(parameters.copyWith(pageIndex: index + 1));
    if (s != null) {
      return s.then((v) => v != null
          // ? _genFromStartAndCount(
          ? _genFromRange(
              start: getPageFirstPostIndex(index),
              filterBlacklist: filterBlacklist,
            )
          : null);
    }
    return await tryRetrievePage(index)
        // ? _genFromStartAndCount(
        ? _genFromRange(
            start: getPageFirstPostIndex(index),
            filterBlacklist: filterBlacklist,
          )
        : null;
  }

  /// {@macro loadWarn}
  FutureOr<Iterable<E6PostResponse>?> getPostsOnPage(
    final int index, [
    bool? filterBlacklist,
  ]) =>
      (getPostsOnPageSync(index, filterBlacklist) ??
              getPostsOnPageAsync(index, filterBlacklist))
          as FutureOr<Iterable<E6PostResponse>?>;

  /// {@macro notLoadWarn}
  Iterable<E6PostResponse>? getPostsOnPageSync(
    final int index, [
    bool? filterBlacklist,
  ]) =>
      (isPageLoaded(index))
          ? _getRawPostFromRange(
              start: getPageFirstPostIndex(index),
              filterBlacklist: filterBlacklist,
            )
          : null;

  /// {@macro loadWarn}
  Future<Iterable<E6PostResponse>?> getPostsOnPageAsync(
    final int index, [
    bool? filterBlacklist,
  ]) async {
    final s = checkLoading(parameters.copyWith(pageIndex: index + 1));
    if (s != null) {
      return s.then((v) => v != null
          ? _getRawPostFromRange(
              start: getPageFirstPostIndex(index),
              filterBlacklist: filterBlacklist,
            )
          : null);
    }
    return await tryRetrievePage(index)
        ? _getRawPostFromRange(
            start: getPageFirstPostIndex(index),
            filterBlacklist: filterBlacklist,
          )
        : null;
  }

  /* /// {@macro loadWarn}
  FutureOr<E6PostResponse?> getPostByIndexOverall(
    final int index, [
    bool? filterBlacklist,
  ]) =>
      (getPostByIndexOverallSync(index, filterBlacklist) ??
              getPostByIndexOverallAsync(index, filterBlacklist))
          as FutureOr<E6PostResponse?>;

  /// {@macro notLoadWarn}
  E6PostResponse? getPostByIndexOverallSync(
    final int index, [
    bool? filterBlacklist,
  ]) =>
      (isPostIndexLoaded(index))
          ? _getRawPostFromRange(
              start: getPageFirstPostIndex(index),
              filterBlacklist: filterBlacklist,
            )
          : null;

  /// {@macro loadWarn}
  Future<Iterable<E6PostResponse>?> getPostByIndexOverallAsync(
    final int index, [
    bool? filterBlacklist,
  ]) async {
    final s = checkLoading(parameters.copyWith(pageIndex: index + 1));
    if (s != null) {
      return s.then((v) => v != null
          ? _getRawPostFromRange(
              start: getPageFirstPostIndex(index),
              filterBlacklist: filterBlacklist,
            )
          : null);
    }
    return await tryRetrievePage(index)
        ? _getRawPostFromRange(
            start: getPageFirstPostIndex(index),
            filterBlacklist: filterBlacklist,
          )
        : null;
  } */

  /// TODO: Check if posts are already in collection before?
  bool assignPagePosts(
      final int pageIndex, final Iterable<E6PostResponse> toAdd) {
    switch (getPageFirstPostIndex(pageIndex)) {
      case < 0:
        final t = toAdd.toList();
        if (t.isEmpty) return true;
        do {
          if (_startingPage == 0) {
            logger.severe("_startingPage was about to go to 0");
            return false;
          }
          _startingPage--;
          for (int i = 0; t.isNotEmpty && postsPerPage > i; i++) {
            collection._posts.addFirst(E6PostEntrySync(value: t.removeLast()));
          }
        } while (t.isNotEmpty && getPageFirstPostIndex(pageIndex) < 0);
        notifyListeners();
        return true;

      case int start when start >= collection._posts.length:
        if (toAdd.firstOrNull == null) return true;
        collection._posts.addAll(toAdd.map((e) => E6PostEntrySync(value: e)));
        notifyListeners();
        return true;

      default:
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
      (pageIndex - _startingPage) * postsPerPage;

  /// The index in [collection] of the 1st post of the [pageIndex]th overall
  /// page that isn't blacklisted.
  ///
  /// If `getPageFirstPostIndex(pageIndex)`
  /// is negative, the page is not loaded, and this will throw an error if
  /// [forceApplyBlacklist] is true or it's null and [filterBlacklist] is true.
  ///
  /// TODO: Add support for checking deleted/restricted posts
  int getPageFirstVisiblePostIndex(
    int pageIndex, {
    bool? forceApplyBlacklist,
  }) {
    final start = getPageFirstPostIndex(pageIndex);
    if (start < 0 || pageIndex > lastStoredPageIndex) return -1;
    if (!(forceApplyBlacklist ?? _filterBlacklist)) {
      return start;
    } else {
      final value = collection
          .getRange(start, getPageLastPostIndex(pageIndex, validate: true))
          .indexed
          .firstWhere(
            (e) =>
                !SearchView.i.blacklistFavs && e.$2.$.isFavorited ||
                !hasBlacklistedTags(e.$2.$.tagSet),
            orElse: () => (-1, E6PostEntrySync(value: E6PostResponse.error)),
          )
          .$1;
      return value < 0 ? value : value + start;
    }
  }

  /// The index in [collection] of the last post of the [pageIndex]th overall page.
  ///
  /// If the value
  /// {@macro negativePageIndexWarn}
  ///
  /// If [validate] is true, will return the index bounded by the loaded posts.
  /// If [pageIndex] exceeds the bounds in either direction, will return `-1`.
  int getPageLastPostIndex(int pageIndex, {bool validate = false}) {
    if (!validate) return getPageFirstPostIndex(pageIndex + 1) - 1;
    final start = getPageFirstPostIndex(pageIndex);
    if (start < 0 || pageIndex > lastStoredPageIndex) return -1;
    var end = getPageFirstPostIndex(pageIndex + 1) - 1;
    if (end < 0) {
      try {
        throw StateError("Something's wrong; pageIndex <= lastStoredPageIndex, "
            "but getPageFirstPostIndex(pageIndex + 1) - 1 = $end:"
            "\n\tpageIndex: $pageIndex"
            "\n\tgetPageFirstPostIndex(pageIndex): $start"
            "\n\tlastStoredPageIndex: $lastStoredPageIndex"
            "\n\tgetPageFirstPostIndex(pageIndex + 1) - 1 = $end");
      } catch (e, s) {
        logger.severe(e, e, s);
        rethrow;
      }
    }
    assert(
        lastStoredPageIndex == pageIndex || end < collection.length,
        "end is out of bounds despite pageIndex not being "
        "on or past the last loaded page"
        "\n\tpageIndex: $pageIndex"
        "\n\tlastStoredPageIndex: $lastStoredPageIndex"
        "\n\tgetPageFirstPostIndex(pageIndex): $start"
        "\n\tend = getPageFirstPostIndex(pageIndex + 1) - 1 = $end");
    return lastStoredPageIndex == pageIndex ? collection.length - 1 : end;
  }

  /// The index in [collection] of the last post of the [pageIndex]th overall
  /// page that isn't blacklisted.
  ///
  /// If `getPageLastPostIndex(pageIndex, validate: true)` is negative, the page is
  /// not loaded, and this will throw an error if either
  /// [forceApplyBlacklist] is true or it's null and [filterBlacklist] is true.
  ///
  /// TODO: Add support for checking deleted/restricted posts
  int getPageLastVisiblePostIndex(
    int pageIndex, {
    bool? forceApplyBlacklist,
  }) {
    final end = getPageLastPostIndex(pageIndex, validate: true);
    if (!(forceApplyBlacklist ?? _filterBlacklist)) {
      return end;
    } else {
      final value = collection.reversed.indexed
          .take(end - getPageFirstPostIndex(pageIndex) + 1)
          .firstWhere((e) => !isBlacklisted(e.$2.$))
          .$1;
      return value < 0 ? value : collection.length - 1 - value;
    }
  }

  /// Takes the given [postIndexOverall] in [collection] and returns the page index
  /// it's on.
  ///
  /// If the return value
  /// {@macro negativePageIndexWarn}
  ///
  /// If null, [postIndexOverall] defaults to [currentPostIndex].
  int getPageIndexOfGivenPost([int? postIndexOverall]) =>
      // ((postIndexOverall ?? currentPostIndex) - (_startingPage * postsPerPage)) ~/
      //     postsPerPage;
      (postIndexOverall ?? currentPostIndex) ~/ postsPerPage - _startingPage;

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
      ((pageIndexOverall ?? currentPageIndex) - _startingPage) * postsPerPage;

  FutureOr<bool> goToNextPage({
    String? username,
    String? apiKey,
  }) async {
    if (await tryLoadNextPage(username: username, apiKey: apiKey)) {
      _currentPageIndex++; //_currentPageOffset++;
      // parameters = parameters.copyWith(pageIndex: currentPageIndex);
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
      _currentPageIndex--; //_currentPageOffset--;
      // parameters = parameters.copyWith(pageIndex: currentPageIndex);
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
      // pageIndex - currentPageIndex = delta
      // (desiredPageOffset + startingPageIndex) - (_currentPageOffset + startingPageIndex) = delta
      // dpo + spi - cpo - spi = delta
      // dpo - cpo = delta
      // dpo = cpo + delta
      // dpo - delta = cpo
      // dpo + spi - cpo - spi = delta
      // dpo + spi = delta + cpo + spi
      // dpo + spi - delta = cpo + spi
      // _currentPageOffset = currentPageIndex - pageIndex;
      _currentPageIndex = pageIndex;
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
  bool isPostIndexLoaded(int postIndex) =>
      postIndex >= getPageFirstPostIndex(startingPageIndex) &&
      postIndex <= getPageLastPostIndex(lastStoredPageIndex);

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
      final p = parameters.copyWith(pageIndex: currentPageIndex + 1);
      /* 
      final p = _parameters.copyWith(
          pageIndex: _currentPageOffset + 1 + _startingPage);
       */
      return _fetchPage(p).then((v) {
        if (v?.isEmpty ?? true) {
          logger.info(
            "No next page from server\n"
            "\tvalidLimit: ${p.validLimit}\n"
            "\tpageNumber: ${p.pageNumber}\n"
            "\ttags: ${p.tags}",
          );
          return false;
        }
        logger.info(
          "Got next page from server\n"
          "\tvalidLimit: ${p.validLimit}\n"
          "\tpageNumber: ${p.pageNumber}\n"
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
      final p = parameters.copyWith(pageIndex: currentPageIndex - 1);
      /* 
      final p = _parameters.copyWith(
          pageIndex: _currentPageOffset - 1 + _startingPage);
       */
      return _fetchPage(p).then((v) {
        if (v?.isEmpty ?? true) {
          logger.info(
            "No page index $p from server\n"
            "\tFunction: tryLoadPriorPage\n"
            "\tvalidLimit: ${p.validLimit}\n"
            "\tpageNumber: ${p.pageNumber}\n"
            "\ttags: ${p.tags}",
          );
          return false;
        }
        logger.info(
          "Got prior page from server\n"
          "\tFunction: tryLoadPriorPage\n"
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
        "\tpageNumber: ${currentPageNumber - 1}\n"
        //"\tpageNumber: ${_currentPageOffset - 1 + _startingPage + 1}\n"
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
        final param = parameters.copyWith(pageIndex: p);
        return _fetchPage(param).then((v) {
          if (v?.isEmpty ?? true) {
            logger.info(
              "No page index $p from server\n"
              "\tFunction: tryRetrieveFormerPage\n"
              "\tvalidLimit: ${param.validLimit}\n"
              "\tpageNumber: ${param.pageNumber}\n"
              "\ttags: ${param.tags}",
            );
            return false;
          }
          logger.info(
            "Got page index $p from server\n"
            "\tFunction: tryRetrieveFormerPage\n"
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
              "\tpageNumber: ${currentPageNumber - 1}\n"
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
        final param = parameters.copyWith(pageIndex: p);
        return _fetchPage(param).then((v) {
          if (v?.isEmpty ?? true) {
            logger.info(
              "No page index $p from server\n"
              "\tFunction: tryRetrieveFuturePage\n"
              "\tvalidLimit: ${param.validLimit}\n"
              "\tpageNumber: ${param.pageNumber}\n"
              "\ttags: ${param.tags}",
            );
            return false;
          }
          logger.info(
            "Got page index $p from server\n"
            "\tFunction: tryRetrieveFuturePage\n"
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
    return tryRetrieveFirstPageAsync(
      username: username,
      apiKey: apiKey,
    );
  }

  Future<bool> tryRetrieveFirstPageAsync({
    String? username,
    String? apiKey,
  }) {
    final param = parameters.copyWith(pageIndex: 0);
    return _fetchPage(param).then((v) {
      if (v?.isEmpty ?? true) {
        logger.info(
          "No page index ${param.pageIndex} from server\n"
          "\tFunction: tryRetrieveFirstPageAsync\n"
          "\tvalidLimit: ${param.validLimit}\n"
          "\tpageNumber: ${param.pageNumber}\n"
          "\ttags: ${param.tags}",
        );
        return false;
      }
      logger.info(
        "Got page ${param.pageIndex} from server\n"
        "\tFunction: tryRetrieveFirstPageAsync\n"
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
  (int index, Future<void> f)? _postUpdate;
  Future<void> updateCurrentPostIndex(int newIndex) async {
    if (_postUpdate != null && _postUpdate!.$1 == newIndex) {
      return _postUpdate!.$2;
    }
    if (_postUpdate != null && _postUpdate!.$1 != newIndex) {
      logger.warning("Discarding attempted post index change to $newIndex");
      return _postUpdate!.$2;
    }
    return (_postUpdate = (
      newIndex,
      _updateCurrentPostIndex(newIndex)..then((_) => _postUpdate = null)
    ))
        .$2;
  }

  Future<void> _updateCurrentPostIndex(int newIndex) async {
    if (currentPostIndex == newIndex) return;
    final pageIndex = getPageIndexOfGivenPost(newIndex);
    if (isPageLoaded(pageIndex)) {
      _currentPostIndex = newIndex;
      notifyListeners();
      return;
    }
    if (await tryRetrievePage(pageIndex)) {
      _currentPostIndex = newIndex;
      notifyListeners();
    } else {
      logger.warning(
        "Failed to update post index to page:"
        "\n\tdesiredPostIndex: $newIndex"
        "\n\tdesiredPageIndex: $pageIndex",
      );
    }
  }

  Future<Iterable<E6PostResponse>?> _fetchPage(
      [PostSearchQueryRecord? parameters]) {
    parameters ??= this.parameters;
    logger.info("Getting page ${parameters.page}");
    return _loading[parameters] ??
        (!(lastPage?.hasLesserPageNumber(parameters, orEqual: true) ?? false)
            ? ((_loading[parameters] = E621
                .performUserPostSearch(
                limit: parameters.validLimit,
                pageNumber: (parameters.pageNumber ?? 1),
                tags: parameters.tags,
              )
                .then((v) {
                if (v.results == null) {
                  if (lastPage == null ||
                      (lastPage?.tags == parameters!.tags &&
                          lastPage!.limit == parameters.limit &&
                          lastPage!.pageNumber! > parameters.pageNumber!)) {
                    lastPage = parameters;
                  }
                  onPageRetrievalFailure.invoke(PostCollectionEvent(
                      parameters: parameters!, posts: collection));
                }
                return v.results?.posts;
              }))
              ..then((v) => _loading.remove(parameters!)))
            : Future.sync(() => null));
  }

  /// Doesn't add posts if blacklist is filtered.
  ///
  /// If null, [end] defaults to [postsPerPage] + [start].
  E6Posts _genFromRange({
    int start = 0,
    int? end,
    bool? filterBlacklist,
  }) =>
      E6PostsSync(
        posts: _getRawPostFromRange(
          start: start,
          end: end,
          filterBlacklist: filterBlacklist,
        ).toList(),
      );

  /// If [ensureCount] is true, adds posts if blacklist is filtered.
  ///
  /// If null, [count] defaults to [postsPerPage].
  E6Posts _genFromStartAndCount({
    int start = 0,
    int? count,
    bool? filterBlacklist,
    bool ensureCount = true,
  }) =>
      E6PostsSync(
        posts: _getRawPostFromStartAndCount(
          start: start,
          count: count,
          filterBlacklist: filterBlacklist,
          ensureCount: ensureCount,
        ).toList(),
      );

  /// Doesn't add posts if blacklist is filtered.
  ///
  /// If null, [end] defaults to [postsPerPage] + [start].
  Iterable<E6PostResponse> _getRawPostFromRange({
    int start = 0,
    int? end,
    bool? filterBlacklist,
  }) =>
      // _getFromRange(
      _getFromRangeConfigurable(
        start: start,
        end: end,
        filterBlacklist: filterBlacklist,
        mapper: (e) => e.$,
      );
  // ).map((e) => e.$);

  /// If [ensureCount] is true, adds posts if blacklist is filtered.
  ///
  /// If null, [count] defaults to [postsPerPage].
  Iterable<E6PostResponse> _getRawPostFromStartAndCount({
    int start = 0,
    int? count,
    bool? filterBlacklist,
    bool ensureCount = true,
  }) =>
      // _getFromStartAndCount(
      _getFromStartAndCountConfigurable(
        start: start,
        count: count,
        filterBlacklist: filterBlacklist,
        ensureCount: ensureCount,
        mapper: (e) => e.$,
      );
  // ).map((e) => e.$);

  /// Doesn't add posts if blacklist is filtered.
  ///
  /// If null, [end] defaults to [postsPerPage] + [start].
  Iterable<E6PostEntrySync> _getFromRange({
    int start = 0,
    int? end,
    bool? filterBlacklist,
  }) {
    final count = (end ?? (postsPerPage + start)) - start;
    return (filterBlacklist ?? _filterBlacklist)
        ? collection._posts.skip(start).foldTo<List<E6PostEntrySync>>(
            [],
            (acc, e, _, __) =>
                (!SearchView.i.blacklistFavs && e.$.isFavorited) ||
                        !hasBlacklistedTags(e.$.tagSet)
                    ? (acc..add(e))
                    : acc,
            breakIfTrue: (_, __, i, ___) => i + start >= count + start,
          )
        : collection._posts.skip(start).take(count);
  }

  /// Doesn't add posts if blacklist is filtered.
  ///
  /// If null, [end] defaults to [postsPerPage] + [start].
  Iterable<T> _getFromRangeConfigurable<T>({
    int start = 0,
    int? end,
    bool? filterBlacklist,
    required T Function(E6PostEntrySync e) mapper,
  }) {
    final count = (end ?? (postsPerPage + start)) - start;
    return (filterBlacklist ?? _filterBlacklist)
        ? collection._posts.skip(start).foldTo<List<T>>(
            [],
            (acc, e, _, __) =>
                (!SearchView.i.blacklistFavs && e.$.isFavorited) ||
                        !hasBlacklistedTags(e.$.tagSet)
                    ? (acc..add(mapper(e)))
                    : acc,
            breakIfTrue: (_, __, i, ___) => i + start >= count + start,
          )
        : collection._posts.skip(start).take(count).map(mapper);
  }

  /// If [ensureCount] is true, adds posts if blacklist is filtered.
  ///
  /// If null, [count] defaults to [postsPerPage].
  Iterable<E6PostEntrySync> _getFromStartAndCount({
    int start = 0,
    int? count,
    bool? filterBlacklist,
    bool ensureCount = true,
  }) {
    return (filterBlacklist ?? _filterBlacklist)
        ? ensureCount
            ? collection._posts.skip(start).foldTo<List<E6PostEntrySync>>(
                [],
                (acc, e, _, __) =>
                    !SearchView.i.blacklistFavs && e.$.isFavorited ||
                            !hasBlacklistedTags(e.$.tagSet)
                        ? (acc..add(e))
                        : acc,
                breakIfTrue: (acc, _, __, ___) =>
                    acc.length >= (count ?? postsPerPage),
              )
            : collection._posts.skip(start).take(count ?? postsPerPage).where(
                (e) =>
                    !SearchView.i.blacklistFavs && e.$.isFavorited ||
                    !hasBlacklistedTags(e.$.tagSet))
        : collection._posts.skip(start).take(count ?? postsPerPage);
  }

  /// If [ensureCount] is true, adds posts if blacklist is filtered.
  ///
  /// If null, [count] defaults to [postsPerPage].
  Iterable<T> _getFromStartAndCountConfigurable<T>({
    int start = 0,
    int? count,
    bool? filterBlacklist,
    bool ensureCount = true,
    required T Function(E6PostEntrySync e) mapper,
  }) {
    return (filterBlacklist ?? _filterBlacklist)
        ? ensureCount
            ? collection._posts.skip(start).foldTo<List<T>>(
                [],
                (acc, e, _, __) =>
                    !SearchView.i.blacklistFavs && e.$.isFavorited ||
                            !hasBlacklistedTags(e.$.tagSet)
                        ? (acc..add(mapper(e)))
                        : acc,
                breakIfTrue: (acc, _, __, ___) =>
                    acc.length >= (count ?? postsPerPage),
              )
            : collection._posts
                .skip(start)
                .take(count ?? postsPerPage)
                .fold<List<T>>(
                    [],
                    (acc, e) =>
                        !SearchView.i.blacklistFavs && e.$.isFavorited ||
                                !hasBlacklistedTags(e.$.tagSet)
                            ? (acc..add(mapper(e)))
                            : acc)
        : collection._posts.skip(start).take(count ?? postsPerPage).map(mapper);
  }

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
  set parameters(PostSearchQueryRecord value) {
    logger.finest("set parameters called"
        "\n\told:"
        "\n\t\ttags:${parameters.tags}"
        "\n\t\tlimit:${parameters.limit}"
        "\n\t\tpageNumber:${parameters.pageNumber}"
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
    parameters ??= this.parameters;
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
