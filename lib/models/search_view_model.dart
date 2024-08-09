import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';

import '../web/e621/e621.dart';
import 'package:fuzzy/log_management.dart' as lm;

import '../web/e621/e621_access_data.dart';

// #region Logger
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;
// ignore: unnecessary_late
late final lRecord = lm.generateLogger("SearchViewModel");
// #endregion Logger

class SearchViewModel extends ChangeNotifier {
  bool toggleSendAuthHeaders() {
    E621AccessData.useLoginData = !E621AccessData.useLoginData;
    notifyListeners();
    if (E621AccessData.useLoginData && E621AccessData.fallback == null) {
      E621AccessData.devAccessData.getItem().then(
            (v) => logger.fine("Dev e621 Auth Loaded"),
          );
    }
    return E621AccessData.useLoginData;
  }

  SearchViewModel();
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
    if (s1.$.posts.first.id > s2.$.posts.first.id) {
      if (s1.$.posts.last.id <= s2.$.posts.last.id) {
        return true;
      } else {
        return false;
      }
    } else if (s2.$.posts.first.id > s1.$.posts.first.id) {
      if (s2.$.posts.last.id <= s1.$.posts.last.id) {
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
    if (s1.$.posts.first.id > s2.$.posts.first.id) {
      start = s2.$.posts.first.id;
    } else {
      //if (s2.$.posts.first.id >= s1.$.posts.first.id) {
      start = s1.$.posts.first.id;
    }
    if (s1.$.posts.last.id <= s2.$.posts.last.id) {
      end = s2.$.posts.last.id;
    } else {
      end = s1.$.posts.last.id;
    }
    return (startId: start, endId: end);
  }

  ({int startId, int endId})? getIntersectionBounds() {
    if (!search1.isAssigned || !search2.isAssigned) {
      return null;
    }
    int start, end;
    if (search1.$.idRange.largest > search2.$.idRange.largest) {
      start = search2.$.idRange.largest;
    } else {
      //if (search2.$.idRange.largest >= search1.$.idRange.largest) {
      start = search1.$.idRange.largest;
    }
    if (search1.$.idRange.smallest <= search2.$.idRange.smallest) {
      end = search2.$.idRange.smallest;
    } else {
      end = search1.$.idRange.smallest;
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
                (v2) => E6PostsSync.fromJson(jsonDecode(v2)).posts.last.id)),
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
