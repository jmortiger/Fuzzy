import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';

import '../web/e621/e621.dart';

class SearchViewModel extends ChangeNotifier {
  bool _lazyLoad = false;
  bool get lazyLoad => _lazyLoad;
  bool toggleLazyLoad() {
    _lazyLoad = !_lazyLoad;
    notifyListeners();
    return _lazyLoad;
  }

  bool _lazyBuilding = false;
  bool get lazyBuilding => _lazyBuilding;
  bool toggleLazyBuilding() {
    _lazyBuilding = !_lazyBuilding;
    notifyListeners();
    return _lazyBuilding;
  }

  bool _forceSafe = true;
  bool get forceSafe => _forceSafe;
  bool toggleForceSafe() {
    _forceSafe = !_forceSafe;
    notifyListeners();
    return _forceSafe;
  }

  bool _sendAuthHeaders = false;
  bool get sendAuthHeaders => _sendAuthHeaders;
  bool toggleSendAuthHeaders() {
    _sendAuthHeaders = !_sendAuthHeaders;
    notifyListeners();
    if (_sendAuthHeaders && !E621AccessData.devData.isAssigned) {
      E621AccessData.devData
          .getItem(); /* .then(
            (v) => util.snackbarMessageQueue.add(const SnackBar(
              content: Text("Dev e621 Auth Loaded"),
            )),
          ) */
    }
    return _sendAuthHeaders;
  }

  String _searchText = "";
  String get searchText => _searchText;
  set searchText(String value) {
    _searchText = value;
    notifyListeners();
  }

  Future<SearchResultArgs>? _pr;
  Future<SearchResultArgs>? get pr => _pr;
  set pr(Future<SearchResultArgs>? value) {
    _pr = value;
    notifyListeners();
  }

  String _priorSearchText = "";
  String get priorSearchText => _priorSearchText;
  set priorSearchText(String value) {
    _priorSearchText = value;
    notifyListeners();
  }

  bool _fillTextBarWithSearchString = false;
  bool get fillTextBarWithSearchString => _fillTextBarWithSearchString;
  set fillTextBarWithSearchString(bool value) {
    _fillTextBarWithSearchString = value;
    notifyListeners();
  }
}

class SearchCache extends ChangeNotifier {
  // bool get onFirstPage => (firstPostIdCached ?? true) == (firstPostOnPageId ?? false);
  E6Posts? _posts;
  E6Posts? get posts => _posts;
  set posts(E6Posts? v) => (this.._posts = v)..notifyListeners();
  int? _firstPostIdCached;
  int? get firstPostIdCached => _firstPostIdCached;
  set firstPostIdCached(int? v) =>
      (this.._firstPostIdCached = v)..notifyListeners();
  int? get firstPostOnPageId => posts?.tryGet(0)?.id;
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
  bool? get hasPriorPage =>
      firstPostIdCached != null &&
      firstPostIdCached! > (firstPostOnPageId ?? firstPostIdCached!);
  SearchCache({
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
}

class MultiSearch {
  var s1 = LateInstance<E6PostsSync>();
  var s2 = LateInstance<E6PostsSync>();
  LazyInitializer<SearchData> search1;
  LazyInitializer<SearchData> search2;
  int currentPageOffset = 0;

  MultiSearch(
    String term1,
    String term2, [
    int desiredPerPage = 50,
  ])  : search1 = LazyInitializer.immediate(() => SearchData.fire(
              tags: term1,
              limit: desiredPerPage,
            )),
        search2 = LazyInitializer.immediate(() => SearchData.fire(
              tags: term2,
              limit: desiredPerPage,
            ));

  bool isContained() {
    if (!s1.isAssigned || !s2.isAssigned) {
      return false;
    }
    if (s1.item.posts.first.id > s2.item.posts.first.id) {
      if (s1.item.posts.last.id <= s2.item.posts.last.id) {
        return true;
      } else {
        return false;
      }
    } else if (s2.item.posts.first.id > s1.item.posts.first.id) {
      if (s2.item.posts.last.id <= s1.item.posts.last.id) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  }

  ({int startId, int endId})? getIntersectionBoundsFromLoadedPosts() {
    if (!s1.isAssigned || !s2.isAssigned) {
      return null;
    }
    int start, end;
    if (s1.item.posts.first.id > s2.item.posts.first.id) {
      start = s2.item.posts.first.id;
    } else {
      //if (s2.item.posts.first.id >= s1.item.posts.first.id) {
      start = s1.item.posts.first.id;
    }
    if (s1.item.posts.last.id <= s2.item.posts.last.id) {
      end = s2.item.posts.last.id;
    } else {
      end = s1.item.posts.last.id;
    }
    return (startId: start, endId: end);
  }

  ({int startId, int endId})? getIntersectionBounds() {
    if (!search1.isAssigned || !search2.isAssigned) {
      return null;
    }
    int start, end;
    if (search1.item.idRange.largest > search2.item.idRange.largest) {
      start = search2.item.idRange.largest;
    } else {
      //if (search2.item.idRange.largest >= search1.item.idRange.largest) {
      start = search1.item.idRange.largest;
    }
    if (search1.item.idRange.smallest <= search2.item.idRange.smallest) {
      end = search2.item.idRange.smallest;
    } else {
      end = search1.item.idRange.smallest;
    }
    if (start < end) return (startId: -1, endId: -1);
    return (startId: start, endId: end);
  }

  // Future<E6PostsSync> launchSearch(
  //   // String? pageModifier, //pageModifier.contains(RegExp(r'a|b'))
  //   // int? postId,
  //   int? pageNumber,
  //   String? username,
  //   String? apiKey,
  // ) async {
  //   await search1.getItem();
  //   await search2.getItem();
  //   pageNumber ??= currentPageOffset;
  //   var limit = search1.item.desiredPerPage * 2;
  //   search1.item.
  // }
}

@immutable
class SearchData {
  // final String createdAt;
  // DateTime get createdAtDT => DateTime.parse(createdAt);
  final String term;
  final ({int largest, int smallest}) idRange;
  final int desiredPerPage;

  const SearchData /* .constant */ ({
    required this.term,
    required this.idRange,
    this.desiredPerPage = 50,
    //required this.createdAt,
  });

  // SearchData({
  //   required this.term,
  //   required this.idRange,
  //   this.desiredPerPage = 50,
  // }) : createdAt = DateTime.timestamp().toISO8601DateString();

  static Future<SearchData> fire({
    required String tags, //"jun_kobayashi",
    int limit = 50,
    // String? pageModifier, //pageModifier.contains(RegExp(r'a|b'))
    // int? postId,
    // int? pageNumber,
    String? username,
    String? apiKey,
  }) async {
    /* int lastId = E6PostsSync.fromJson(jsonDecode(
            await (await E621.sendRequest(E621.initSearchForLastPostRequest(
      tags: tags,
      apiKey: apiKey,
      username: username,
    )))
                .stream
                .bytesToString()))
        .posts
        .first
        .id;
    int firstId = E6PostsSync.fromJson(
            jsonDecode(await (await E621.sendRequest(E621.initSearchRequest(
      limit: 1,
      tags: tags,
      apiKey: apiKey,
      username: username,
    )))
                .stream
                .bytesToString()))
        .posts
        .first
        .id; */
    var lastF = E621
            .sendRequest(E621.initSearchForLastPostRequest(
              tags: tags,
              apiKey: apiKey,
              username: username,
            ))
            .then((v1) => v1.stream.bytesToString().then(
                (v2) => E6PostsSync.fromJson(jsonDecode(v2)).posts.first.id)),
        firstF = E621
            .sendRequest(E621.initSearchRequest(
              limit: 1,
              tags: tags,
              apiKey: apiKey,
              username: username,
            ))
            .then((v1) => v1.stream.bytesToString().then(
                (v2) => E6PostsSync.fromJson(jsonDecode(v2)).posts.first.id));
    return SearchData(
        idRange: (largest: await firstF, smallest: await lastF),
        term: tags,
        desiredPerPage: limit);
  }
}

class SearchManager extends ChangeNotifier {
  SearchData currentData;
  DateTime currentDataTimestamp;
  LazyList<E6PostResponse>? posts;

  SearchManager({
    required this.currentData,
    DateTime? currentDataTimestamp,
    // required this.currentPosts,
  }) : currentDataTimestamp = currentDataTimestamp ?? DateTime.timestamp();
}
