import 'dart:convert';
import 'dart:math' show min;

import 'package:collection/collection.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';
import 'package:e621/e621.dart' as e621;
import 'package:fuzzy/log_management.dart' as lm;

// ignore: unnecessary_late
late final _logger = lm.generateLogger("E6Util").logger;

bool hasTags(Iterable<String> tagList, Iterable<String> otherTags) {
  return otherTags.isEmpty || tagList.isEmpty
      ? false
      : switch ((tagList, otherTags)) {
          (Set<String> t, Set<String> o) => o.intersection(t).isNotEmpty,
          (Iterable<String> lhs, Set<String> set) ||
          (Set<String> set, Iterable<String> lhs) =>
            lhs.foldUntilTrue(
                false,
                (acc, e, _, __) =>
                    set.contains(e) ? (true, true) : (false, false)),
          (Iterable<String> lhs, List<String> list) ||
          (List<String> list, Iterable<String> lhs) =>
            lhs.foldUntilTrue(
                false,
                (acc, e, _, __) =>
                    list.contains(e) ? (true, true) : (false, false)),
          (Iterable<String> rhs, Iterable<String> lhs) => lhs.foldUntilTrue(
              false,
              (acc, e, _, __) =>
                  rhs.contains(e) ? (true, true) : (false, false)),
        };
}

/* Iterable<String> getTags(Iterable<String> tagList) {
  final bList = AppSettings.i!.TagsAll;
  return bList.isEmpty
      ? {}
      : tagList is Set<String>
          ? tagList.intersection(bList)
          : tagList.where((e) => bList.contains(e));
} */

bool hasBlacklistedTags(Iterable<String> tagList) {
  final bList = AppSettings.i!.blacklistedTagsAll;
  return bList.isEmpty
      ? false
      : tagList is Set<String>
          ? tagList.intersection(bList).isNotEmpty
          : tagList.foldUntilTrue(
              false,
              (_, e, __, ___) =>
                  bList.contains(e) ? (true, true) : (false, false));
}

Iterable<String> getBlacklistedTags(Iterable<String> tagList) {
  final bList = AppSettings.i!.blacklistedTagsAll;
  return bList.isEmpty
      ? {}
      : tagList is Set<String>
          ? tagList.intersection(bList)
          : tagList.where((e) => bList.contains(e));
}

/// Accounts for [SearchView.i.blacklistFavs]
bool isBlacklisted(E6PostResponse post) =>
    (SearchView.i.blacklistFavs || !post.isFavorited) &&
    hasBlacklistedTags(post.tagSet);

/// Accounts for [SearchView.i.blacklistFavs]
Iterable<String> findBlacklistedTags(E6PostResponse post) =>
    (SearchView.i.blacklistFavs || !post.isFavorited)
        ? getBlacklistedTags(post.tagSet)
        : {};
bool isDeleted(E6PostResponse post) => post.flags.deleted;

class PostIdsAnalysis {
  final List<int> postIds;
  late final Set<int> set;
  bool get isOrdered => isOrderedHighToLow || isOrderedLowToHigh;
  late final bool isOrderedHighToLow;
  late final bool isOrderedLowToHigh;
  late final Map<int, int> duplicateCounts;
  bool get hasDuplicates => duplicateCounts.isNotEmpty;
  int get duplicateCount => duplicateCounts.values.fold(0, (a, b) => a + b);
  final String? _searchString;
  PostIdsAnalysis(Iterable<int> postIds, [this._searchString])
      : postIds = postIds.toList(growable: false) {
    var highToLow = true, lowToHigh = true;
    duplicateCounts = {};
    set = {};
    int? prior;
    for (final id in postIds) {
      if (prior != null) {
        highToLow = highToLow && prior >= id;
        lowToHigh = lowToHigh && prior <= id;
      }
      if (set.add(prior = id)) {
        duplicateCounts[id] = (duplicateCounts[id] ?? 0) + 1;
      }
    }
    isOrderedHighToLow = highToLow;
    isOrderedLowToHigh = lowToHigh;
  }

  /// TODO: finish
  /* Future<Iterable<e621.Post>> getPosts<E6PostType extends e621.Post>({
    String? searchString,
    int? postsPerPage,
    int page = 1,
  }) {
    searchString ??= _searchString;
    postsPerPage ??= SearchView.i.postsPerPage;
    maxPageCount() => postIds.length ~/ postsPerPage!;
    boundedPage([int? max]) => page <= 0
        ? 1
        : page > (max ?? maxPageCount())
            ? (max ?? maxPageCount())
            : page;
    sliceStart(int page) => postsPerPage! * (page - 1);
    sliceEnd(int start) => min(postIds.length, postsPerPage! + start);
    if (postIds.length > e621.maxPostSearchLimit) {
      _logger.info("Too many posts in collection for a single search request");
    }
    if (postIds.length > postsPerPage) {
      _logger.info("Too many posts in collection for 1 page");
    }
    if (searchString == null &&
        postsPerPage > E621.currentTagQueryLimit - 1 &&
        postIds.length > E621.currentTagQueryLimit - 1) {
      postsPerPage = E621.currentTagQueryLimit - 1;
      // OPTIMIZE: The added ids could be duplicates; maximize by looping this
      int delta;
      do {
        final startTemp = sliceStart(boundedPage()),
            slice = postIds.getRange(startTemp, sliceEnd(startTemp)).toList();
        delta = slice.length - slice.toSet().length;
        if (delta > 0) postsPerPage = postsPerPage! + delta;
      } while (delta > 0);
      _logger.warning(
          "Too many posts in collection for 1 search (use the searchString)");
    } else {
      
    }
    final maxPages = postIds.length ~/ postsPerPage!;
    page = boundedPage(maxPages);
    final start = sliceStart(page), end = sliceEnd(start);
    searchString ??= "${(postIds.getRange(start, end).fold(
          "",
          (previousValue,
                  element) => /* duplicates[element] == null || previousValue.contains(RegExp("$element"))  */
              "$previousValue~id:$element ",
        ))} ${(isOrderedHighToLow ? e621.Order.idDesc : e621.Order.id).searchString}";
  } */
  Future<Iterable<e621.Post>> getPostsLegacy<E6PostType extends e621.Post>({
    String? searchString,
    int? postsPerPage,
    int page = 1,
  }) async {
    searchString ??= _searchString;
    postsPerPage ??= SearchView.i.postsPerPage;
    if (postIds.length > e621.maxPostSearchLimit) {
      _logger.info("Too many posts in collection for a single search request");
    }
    if (postIds.length > postsPerPage) {
      _logger.info("Too many posts in collection for 1 page");
    }
    if (searchString == null &&
        postsPerPage > E621.currentTagQueryLimit - 1 &&
        postIds.length > E621.currentTagQueryLimit - 1) {
      postsPerPage = E621.currentTagQueryLimit - 1;
      _logger.warning(
          "Too many posts in collection for 1 search (use the searchString)");
    }
    final maxPages = postIds.length ~/ postsPerPage;
    page = page <= 0
        ? 1
        : page > maxPages
            ? maxPages
            : page;
    final start = postsPerPage * (page - 1),
        end = min(postIds.length, postsPerPage + start);
    bool resultsOrdered = false;
    try {
      if (searchString != null) {
        final tokens = RegExp(e621.tagTokenizer)
            .allMatches(searchString)
            .map((e) => e.group(0)!)
            .toList();
        if (tokens.length > E621.currentTagQueryLimit) {
          if ((tokens..removeWhere((e) => !e.startsWith(e621.Order.prefix)))
                  .length >
              E621.currentTagQueryLimit) {
            throw ArgumentError.value(searchString, "searchString",
                "Can't have more than E621.currentTagQueryLimit (${E621.currentTagQueryLimit}) tokens in a search.");
          } else {
            _logger.warning("Can't have more than E621.currentTagQueryLimit "
                "(${E621.currentTagQueryLimit}) tokens in a search.\n\tSearch string:$searchString");
          }
        }
        resultsOrdered = isOrdered;
      }
      searchString ??= "${(postIds.getRange(
            start,
            end,
          ).fold(
            "",
            (previousValue, element) => "$previousValue~id:$element ",
          ))} ${(isOrderedHighToLow ? e621.Order.idDesc : e621.Order.id).searchString}";
      final response = await e621.sendRequest(e621.initPostSearch(
          tags: searchString, limit: postsPerPage, page: page.toString()))
        ..log(_logger);
      _logger.finer("first: ${postIds.first}");
      if (resultsOrdered) {
        final r = switch (E6PostType) {
          const (E6PostResponse) => E6PostResponse.fromRawJsonResults,
          const (E6PostMutable) => E6PostMutable.fromRawJsonResults,
          const (PostNotifier) => PostNotifier.fromRawJsonResults,
          _ => E6PostMutable.fromRawJsonResults,
        }(response.body);
        try {
          assert(
              const DeepCollectionEquality()
                  .equals(r.map((e) => e.id).toList(), postIds),
              "Not actually ordered");
          return r;
        } catch (_) {
          _logger.warning(
              "Came back w/ different than expected results, proceeding with manual ordering");
        }
      }
      final t1 = (jsonDecode(response.body)["posts"] as List);
      _logger.finer("# posts in response: ${t1.length}");
      int postOffset = (page - 1) * postsPerPage;
      _logger.finer(
          "postOffset = $postOffset; postIds[$postOffset] = ${postIds[postOffset]}");
      final ctor = switch (E6PostType) {
        const (E6PostResponse) => E6PostResponse.fromJson,
        const (E6PostMutable) => E6PostMutable.fromJson,
        const (PostNotifier) => PostNotifier.fromJson,
        _ => E6PostMutable.fromJson,
      };
      // Sort them by order in collection
      final t2 = postIds.getRange(postOffset, postIds.length).foldUntilTrue(
        <e621.Post>[],
        (acc, e, _, l) {
          var match =
              t1.firstWhere((t) => e == (t["id"] as int), orElse: () => null);
          return match != null
              ? ((acc..add(ctor(match))), false)
              // Force it to stay alive until it's at least close.
              : (acc, acc.length > l.length);
        },
      );
      _logger.finer("# posts after sorting: ${t2.length}");
      if (t1.length != t2.length) {
        _logger.warning(
            "# posts before ${t1.length} & after ${t2.length} sorting mismatched. There is likely 1 or more posts whose id is out of order with its order in the pool. This will likely cause problems.");
      }
      return t2;
    } catch (e, s) {
      _logger.severe(
          "Failed to getOrderedPosts(searchString: $searchString, postsPerPage: $postsPerPage, page: $page), defaulting to empty array. PostIds: $postIds",
          e,
          s);
      return [];
    }
  }

  // #region Statics
  static bool orderedHighToLow(
    Iterable<int> postIds, {
    bool allowDuplicates = true,
  }) {
    var highToLow = true;
    int? prior;
    final set = !allowDuplicates ? <int>{} : null;
    for (final id in postIds) {
      if (prior != null) {
        highToLow = highToLow && prior >= id;
      }
      if (set?.add(prior = id) ?? false) return false;
    }
    return highToLow;
  }

  static bool orderedLowToHigh(
    Iterable<int> postIds, {
    bool allowDuplicates = true,
  }) {
    var lowToHigh = true;
    int? prior;
    final set = !allowDuplicates ? <int>{} : null;
    for (final id in postIds) {
      if (prior != null) {
        lowToHigh = lowToHigh && prior <= id;
      }
      if (set?.add(prior = id) ?? false) return false;
    }
    return lowToHigh;
  }

  static bool doesHaveDuplicates(Iterable<int> postIds) =>
      postIds is! Set<int> && postIds.length != postIds.toSet().length;
  // #endregion Statics
}

class PostIdListsAnalysis {
  final PostIdsAnalysis ids1;
  final PostIdsAnalysis ids2;
  late final Set<int> intersection;
  late final bool areIdentical;
  late final bool isFirstContainedBySecond;
  late final bool isSecondContainedByFirst;
  bool get haveSameMembers =>
      isFirstContainedBySecond && isSecondContainedByFirst;
  bool get areBothOrdered => ids1.isOrdered && ids2.isOrdered;
  bool get areBothOrderedHighToLow =>
      ids1.isOrderedHighToLow && ids2.isOrderedHighToLow;
  bool get areBothOrderedLowToHigh =>
      ids1.isOrderedLowToHigh && ids2.isOrderedLowToHigh;
  PostIdListsAnalysis(Iterable<int> postIds1, Iterable<int> postIds2)
      : ids1 = PostIdsAnalysis(postIds1),
        ids2 = PostIdsAnalysis(postIds2) {
    intersection = ids1.set.intersection(ids2.set);
    isFirstContainedBySecond = intersection.length >= ids1.set.length;
    isSecondContainedByFirst = intersection.length >= ids2.set.length;
    areIdentical = isFirstContainedBySecond &&
        isSecondContainedByFirst &&
        ids1.postIds.length == ids2.postIds.length &&
        ids1.postIds.foldUntilTrue(
            true,
            (p, e, i, _) =>
                p && (e == ids1.postIds[i]) ? (true, false) : (false, true));
  }
}
