import 'dart:async';
import 'dart:convert' as dc;

import 'package:e621/e621.dart' as e621;
import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/main.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart' as cf;
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/tag_subscription.dart';
import 'package:fuzzy/pages/pool_view_page.dart';
import 'package:fuzzy/pages/wiki_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:file_saver/file_saver.dart' as saver;
import 'package:http/http.dart';
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

// #region Logger
lm.Printer get _print => lRecord.print;
lm.FileLogger get _logger => lRecord.logger;
// ignore: unnecessary_late
late final lRecord = lm.generateLogger("E6Actions");
// #endregion Logger

// #region Favorites
Iterable<E6PostResponse> _filterOnFav(
  Iterable<E6PostResponse> posts,
  bool removeFav,
  bool canEditPosts,
) {
  switch (posts) {
    case List<E6PostResponse> _:
      if (!canEditPosts) continue cannotEdit;
      try {
        return posts..removeWhere((e) => e.isFavorited == removeFav);
      } catch (_) {
        continue cannotEdit;
      }
    cannotEdit:
    default:
      return posts = posts.where((e) => e.isFavorited != removeFav);
  }
}

Future<E6PostResponse> addPostToFavoritesWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
}) =>
    _addPostToFavorites(context: context, post: post, updatePost: updatePost)
        .then((v) => v!);

Future<E6PostResponse?> addPostToFavoritesWithId({
  BuildContext? context,
  required int postId,
}) =>
    _addPostToFavorites(context: context, postId: postId);

Future<E6PostResponse?> _addPostToFavorites({
  BuildContext? context,
  int? postId,
  E6PostResponse? post,
  bool updatePost = true,
}) {
  assert((postId ?? post) != null, "Either postId or post must be non-null");
  final id = postId ??= post!.id;
  final out = "Adding $id to favorites...";
  _logger.finer(out);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(out));
  }
  if (AppSettings.i!.upvoteOnFavorite) {
    (post != null
            ? voteOnPostWithPost(isUpvote: true, post: post)
            : voteOnPostWithId(isUpvote: true, postId: id))
        .ignore();
  }
  return E621
      .sendAddFavoriteRequest(
    id,
    username: E621AccessData.allowedUserDataSafe?.username,
    apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
  )
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      var postRet = v.statusCodeInfo.isSuccessful
          ? E6PostMutable.fromRawJson(v.body)
          : post;
      if (context != null && context.mounted) {
        !v.statusCodeInfo.isSuccessful
            ? util.showUserMessage(
                context: context,
                content: Text("${v.statusCode}: ${v.reasonPhrase}"))
            : util.showUserMessage(
                context: context,
                content: Text("$id added from favorites"),
                action: (
                    "Undo",
                    () => _removePostFromFavorites(
                          context: context,
                          post: post,
                          postId: postId,
                          updatePost: updatePost,
                        )
                  ));
      }
      return updatePost && post is E6PostMutable
          ? (post..overwriteFrom(postRet!))
          : postRet;
    },
  );
}

Future<E6PostResponse> removePostFromFavoritesWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
}) =>
    _removePostFromFavorites(
            context: context, post: post, updatePost: updatePost)
        .then((v) => v!);

Future<E6PostResponse?> removePostFromFavoritesWithId({
  BuildContext? context,
  required int postId,
}) =>
    _removePostFromFavorites(context: context, postId: postId);

Future<E6PostResponse?> _removePostFromFavorites({
  BuildContext? context,
  int? postId,
  E6PostResponse? post,
  bool updatePost = true,
}) {
  assert((postId ?? post) != null, "Either postId or post must be non-null");
  final id = postId ?? post!.id;
  final out = "Removing $id from favorites...";
  _logger.finer(out);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(out));
  }
  return E621
      .sendDeleteFavoriteRequest(
    id,
    username: E621AccessData.allowedUserDataSafe?.username,
    apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
  )
      .then((v) {
    lm.logResponseSmart(v, _logger);
    var postRet = v.statusCodeInfo.isSuccessful
        ? E6PostMutable.fromRawJson(v.body)
        : post;
    if (context != null && context.mounted) {
      !v.statusCodeInfo.isSuccessful
          ? util.showUserMessage(
              context: context,
              content: Text("${v.statusCode}: ${v.reasonPhrase}"))
          : util.showUserMessage(
              context: context,
              content: Text("$id removed from favorites"),
              action: (
                  "Undo",
                  post != null
                      ? () => addPostToFavoritesWithPost(
                            post: post,
                            updatePost: updatePost,
                            context: context,
                          )
                      : () => addPostToFavoritesWithId(
                            postId: id,
                            context: context,
                          )
                ));
    }
    return updatePost && post is E6PostMutable
        ? (post..overwriteFrom(postRet!))
        : postRet;
  });
}

/// If [canEditPosts] is true, the [posts] collection may be altered. If this is a [List], this may cause problems.
Future< /* Iterable<E6PostResponse> */ void> addToFavoritesWithPosts({
  BuildContext? context,
  required Iterable<E6PostResponse> posts,
  bool updatePost = true,
  bool filterFavoritedPosts = true,
  bool canEditPosts = false,
}) {
  if (filterFavoritedPosts) posts = _filterOnFav(posts, true, canEditPosts);
  var str = "Adding ${posts.length} posts to favorites...";
  _logger.finer(str);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(str));
  }
  if (AppSettings.i!.upvoteOnFavorite) {
    voteOnPostsWithPosts(isUpvote: true, posts: posts).map((e) => e.ignore());
  }
  final pIds = posts.map((e) => e.id);
  return E621.sendAddFavoriteRequestBatch(
    pIds,
    username: E621AccessData.allowedUserDataSafe?.username,
    apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
    onComplete: (responses) {
      var total = responses.length;
      responses.removeWhere(
        (element) => element.statusCodeInfo.isSuccessful,
      );
      var sbs = "${total - responses.length}/"
          "$total posts added to favorites!";
      responses.where((r) => r.statusCode == 422).forEach((r) async {
        var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
        if ((context != null && context.mounted) &&
            Provider.of<cf.CachedFavorites>(context, listen: false)
                .postIds
                .contains(pId)) {
          sbs += " $pId Cached";
        }
      });
      if (context != null && context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(sbs),
          action: (
            "Undo",
            () async {
              E621.sendDeleteFavoriteRequestBatch(
                pIds,
                username: E621AccessData.allowedUserDataSafe?.username,
                apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
                onComplete: (rs) {
                  if (context.mounted) {
                    util.showUserMessage(
                      context: context,
                      content: Text(
                        "${rs.where((e) => e.statusCodeInfo.isSuccessful).length}"
                        "/${rs.length} posts removed from favorites!",
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      }
    },
  );
}

Future< /* Iterable<E6PostResponse> */ void> addToFavoritesWithIds({
  BuildContext? context,
  required final Iterable<int> postIds,
}) {
  var str = "Adding ${postIds.length} posts to favorites...";
  _logger.finer(str);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(str));
  }
  if (AppSettings.i!.upvoteOnFavorite) {
    voteOnPostsWithPostIds(isUpvote: true, postIds: postIds)
        .map((e) => e.ignore());
  }
  return E621.sendAddFavoriteRequestBatch(
    postIds,
    username: E621AccessData.allowedUserDataSafe?.username,
    apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
    onComplete: (responses) {
      var total = responses.length;
      responses.removeWhere(
        (element) => element.statusCodeInfo.isSuccessful,
      );
      var sbs = "${total - responses.length}/"
          "$total posts added to favorites!";
      responses.where((r) => r.statusCode == 422).forEach((r) async {
        var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
        if ((context != null && context.mounted) &&
            Provider.of<cf.CachedFavorites>(context, listen: false)
                .postIds
                .contains(pId)) {
          sbs += " $pId Cached";
        }
      });
      if (context != null && context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(sbs),
          action: (
            "Undo",
            () async {
              E621.sendDeleteFavoriteRequestBatch(
                postIds,
                username: E621AccessData.allowedUserDataSafe?.username,
                apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
                onComplete: (rs) {
                  if (context.mounted) {
                    util.showUserMessage(
                      context: context,
                      content: Text(
                        "${rs.where((e) => e.statusCodeInfo.isSuccessful).length}"
                        "/${rs.length} posts removed from favorites!",
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      }
    },
  );
}

Future< /* Iterable<E6PostResponse> */ void> removeFromFavoritesWithPosts({
  BuildContext? context,
  required Iterable<E6PostResponse> posts,
  bool updatePost = true,
}) {
  var str = "Removing ${posts.length} posts from favorites...";
  _logger.finer(str);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(str));
  }
  final pIds = posts.map((e) => e.id);
  return E621.sendDeleteFavoriteRequestBatch(
    pIds,
    username: E621AccessData.allowedUserDataSafe?.username,
    apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
    onComplete: (responses) {
      var total = responses.length;
      responses.removeWhere(
        (element) => element.statusCodeInfo.isSuccessful,
      );
      var sbs = "${total - responses.length}/"
          "$total posts removed from favorites!";
      // responses.where((r) => r.statusCode == 422).forEach((r) async {
      //   var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
      //   if ((context != null && context.mounted) &&
      //       Provider.of<cf.CachedFavorites>(context!, listen: false)
      //           .postIds
      //           .contains(pId)) {
      //     sbs += " $pId Cached";
      //   }
      // });
      if (context != null && context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(sbs),
          action: (
            "Undo",
            () async {
              E621.sendAddFavoriteRequestBatch(
                pIds,
                username: E621AccessData.allowedUserDataSafe?.username,
                apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
                onComplete: (rs) {
                  if (context.mounted) {
                    util.showUserMessage(
                      context: context,
                      content: Text(
                        "${rs.where((e) => e.statusCodeInfo.isSuccessful).length}"
                        "/${rs.length} posts added to favorites!",
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      }
    },
  );
}

Future< /* Iterable<E6PostResponse> */ void> removeFromFavoritesWithIds({
  BuildContext? context,
  required final Iterable<int> postIds,
}) {
  var str = "Removing ${postIds.length} posts from favorites...";
  _logger.finer(str);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(str));
  }
  return E621.sendDeleteFavoriteRequestBatch(
    postIds,
    username: E621AccessData.allowedUserDataSafe?.username,
    apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
    onComplete: (responses) {
      var total = responses.length;
      responses.removeWhere(
        (element) => element.statusCodeInfo.isSuccessful,
      );
      var sbs = "${total - responses.length}/"
          "$total posts removed favorites!";
      responses.where((r) => r.statusCode == 422).forEach((r) async {
        var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
        if ((context != null && context.mounted) &&
            Provider.of<cf.CachedFavorites>(context, listen: false)
                .postIds
                .contains(pId)) {
          sbs += " $pId Cached";
        }
      });
      if (context != null && context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(sbs),
          action: (
            "Undo",
            () async {
              E621.sendAddFavoriteRequestBatch(
                postIds,
                username: E621AccessData.allowedUserDataSafe?.username,
                apiKey: E621AccessData.allowedUserDataSafe?.apiKey,
                onComplete: (rs) {
                  if (context.mounted) {
                    util.showUserMessage(
                      context: context,
                      content: Text(
                        "${rs.where((e) => e.statusCodeInfo.isSuccessful).length}"
                        "/${rs.length} posts added to favorites!",
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      }
    },
  );
}
// #endregion Favorites

// #region SetMulti
/// TODO: Multiselect
Future<e621.PostSet?> removeFromSetWithPosts({
  required BuildContext context,
  required List<E6PostResponse> posts,
}) async {
  _logger.finer("Removing ${posts.length}"
      " posts from a set, selecting set");
  if (context.mounted) {
    util.showUserMessage(
      context: context,
      content: Text("Removing ${posts.length}"
          " posts from a set, selecting set"),
    );
  }
  var v = await showDialog<e621.PostSet>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: WSearchSet.showEditableSets(
          // initialLimit: 10,
          // initialPage: null,
          // initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
          //     E621AccessData.fallbackForced?.username,
          // initialSearchOrder: e621.SetOrder.updatedAt,
          // initialSearchName: null,
          // initialSearchShortname: null,
          filterResults: (set) => posts.foldUntilTrue(
              false,
              (accumulator, elem, index, list) => set.postIds.contains(elem.id)
                  ? (true, true)
                  : (accumulator, false)),
          // onSelected: (e621.PostSet set) => "",
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          // onMultiselectCompleted: (_) => "",
        ),
        // scrollable: true,
      );
    },
  );
  if (v != null) {
    _logger.finer("Removing ${posts.length}"
        " posts from set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})");
    if (context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text(
          "Removing ${posts.length}"
          " posts from set ${v.id} (${v.shortname}, "
          "length ${v.postCount}, length ${v.postCount})",
        ),
      );
    }
    // final searchString =
    //     "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await e621.sendRequest(e621.initSetRemovePosts(
      v.id,
      posts.map((e) => e.id).toList(),
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ));

    lm.logResponseSmart(res, _logger);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${formerLength - v.postCount}/${posts.length} posts successfully removed from set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(
            //             title: Text("Set ${v!.id}: ${v.shortname}"),
            //           ),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
      }
    } else {
      final out =
          "${res.statusCode}: Failed to remove posts from set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      util.showUserMessage(context: context, content: const Text(out));
    }
  }
  return v;
}

/// TODO: Multiselect
Future<e621.PostSet?> addToSetWithPosts({
  required BuildContext context,
  required List<E6PostResponse> posts,
}) async {
  _logger.finer("Adding ${posts.length}"
      " posts to a set, selecting set");
  if (context.mounted) {
    util.showUserMessage(
      context: context,
      content: Text("Adding ${posts.length}"
          " posts to a set, selecting set"),
    );
  }
  var v = await showDialog<e621.PostSet>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: WSearchSet.showEditableSets(
          // initialLimit: 10,
          // initialPage: null,
          // initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
          //     E621AccessData.fallbackForced?.username,
          // initialSearchOrder: e621.SetOrder.updatedAt,
          // initialSearchName: null,
          // initialSearchShortname: null,
          filterResults: (set) => posts.foldUntilTrue(
              false,
              (accumulator, elem, index, list) => !set.postIds.contains(elem.id)
                  ? (true, true)
                  : (accumulator, false)),
          showCreateSetButton: true,
          // onSelected: (e621.PostSet set) => "",
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          // onMultiselectCompleted: (_) => "",
        ),
        // scrollable: true,
      );
    },
  );
  if (v != null) {
    _logger.finer("Adding ${posts.length}"
        " posts to set ${v.id} (${v.shortname}, length ${v.postCount})");
    if (context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text("Adding ${posts.length}"
            " posts to set ${v.id} (${v.shortname}, "
            "length ${v.postCount})"),
      );
    }
    // final searchString =
    //     "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await e621.sendRequest(e621.initSetAddPosts(
      v.id,
      posts.map((e) => e.id).toList(),
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ));

    lm.logResponseSmart(res, _logger);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${v.postCount - formerLength} ${posts.length} posts successfully added to set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(
            //             title: Text("Set ${v!.id}: ${v.shortname}"),
            //           ),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //    ),
          ),
        );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to add posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      util.showUserMessage(context: context, content: const Text(out));
    }
  }
  return v;
}

/// TODO: Multiselect
Future<e621.PostSet?> removeFromSetWithIds({
  required BuildContext context,
  required List<int> postIds,
}) async {
  _logger.finer("Removing ${postIds.length}"
      " posts from a set, selecting set");
  if (context.mounted) {
    util.showUserMessage(
      context: context,
      content: Text("Removing ${postIds.length}"
          " posts from a set, selecting set"),
    );
  }
  var v = await showDialog<e621.PostSet>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: WSearchSet.showEditableSets(
          // initialLimit: 10,
          // initialPage: null,
          // initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
          //     E621AccessData.fallbackForced?.username,
          // initialSearchOrder: e621.SetOrder.updatedAt,
          // initialSearchName: null,
          // initialSearchShortname: null,
          filterResults: (set) => postIds.foldUntilTrue(
              false,
              (accumulator, elem, index, list) => set.postIds.contains(elem)
                  ? (true, true)
                  : (accumulator, false)),
          // onSelected: (e621.PostSet set) => "",
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          // onMultiselectCompleted: (_) => "",
        ),
        // scrollable: true,
      );
    },
  );
  if (v != null) {
    _logger.finer("Removing ${postIds.length}"
        " posts from set ${v.id} (${v.shortname}, length ${v.postCount})");
    if (context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text("Removing ${postIds.length}"
            " posts from set ${v.id} (${v.shortname}, "
            "length ${v.postCount})"),
      );
    }
    // final searchString =
    //     "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await e621.sendRequest(e621.initSetRemovePosts(
      v.id,
      postIds,
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ));

    lm.logResponseSmart(res, _logger);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${formerLength - v.postCount}/${postIds.length} posts successfully removed from set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(
            //             title: Text("Set ${v!.id}: ${v.shortname}"),
            //           ),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to remove posts from set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      util.showUserMessage(context: context, content: const Text(out));
    }
  }
  return v;
}

/// TODO: Multiselect
Future<e621.PostSet?> addToSetWithIds({
  required BuildContext context,
  required List<int> postIds,
}) async {
  _logger.finer("Adding ${postIds.length}"
      " posts to a set, selecting set");
  if (context.mounted) {
    util.showUserMessage(
      context: context,
      content: Text("Adding ${postIds.length}"
          " posts to a set, selecting set"),
    );
  }
  var v = await showDialog<e621.PostSet>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: WSearchSet.showEditableSets(
          // initialLimit: 10,
          // initialPage: null,
          // initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
          //     E621AccessData.fallbackForced?.username,
          // initialSearchOrder: e621.SetOrder.updatedAt,
          // initialSearchName: null,
          // initialSearchShortname: null,
          filterResults: (set) => postIds.foldUntilTrue(
              false,
              (accumulator, elem, index, list) => !set.postIds.contains(elem)
                  ? (true, true)
                  : (accumulator, false)),
          showCreateSetButton: true,
          // onSelected: (e621.PostSet set) => "",
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          // onMultiselectCompleted: (_) => "",
        ),
        // scrollable: true,
      );
    },
  );
  if (v != null) {
    _logger.finer("Adding ${postIds.length}"
        " posts to set ${v.id} (${v.shortname}, "
        "length ${v.postCount})");
    if (context.mounted) {
      util.showUserMessage(
          context: context,
          content: Text("Adding ${postIds.length}"
              " posts to set ${v.id} (${v.shortname}, "
              "length ${v.postCount})"));
    }
    // final searchString =
    //     "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await e621.sendRequest(e621.initSetAddPosts(
      v.id,
      postIds,
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ));

    lm.logResponseSmart(res, _logger);
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${v.postCount - formerLength} ${postIds.length} posts successfully added to set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(
            //             title: Text("Set ${v!.id}: ${v.shortname}"),
            //           ),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to add posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      util.showUserMessage(context: context, content: const Text(out));
    }
  }
  return v;
}
// #endregion SetMulti

// #region SetSingle
/// TODO: Multiselect
Future<e621.PostSet?> removeFromSetWithPost({
  required BuildContext context,
  required E6PostResponse post,
}) async {
  var logString = "Removing ${post.id}"
      " from a set, selecting set";
  _logger.finer(logString);
  if (context.mounted) {
    util.showUserMessage(context: context, content: Text(logString));
  }
  var v = await showDialog<e621.PostSet>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: WSearchSet.showEditableSets(
          // initialLimit: 10,
          // initialPage: null,
          // initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
          //     E621AccessData.fallbackForced?.username,
          // initialSearchOrder: e621.SetOrder.updatedAt,
          // initialSearchName: null,
          // initialSearchShortname: null,
          filterResults: (set) => set.postIds.contains(post.id),
          // onSelected: (e621.PostSet set) => "",
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          // onMultiselectCompleted: (_) => "",
        ),
        // scrollable: true,
      );
    },
  );
  if (v != null) {
    logString = "Removing ${post.id}"
        " from set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})";
    _logger.finer(logString);
    if (context.mounted) {
      util.showUserMessage(context: context, content: Text(logString));
    }
    // final searchString =
    //     "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await e621.sendRequest(e621.initSetRemovePosts(
      v.id,
      [post.id],
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ));

    lm.logResponseSmart(res, _logger);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out = "${post.id} successfully removed from set ${v.id} "
          "(${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(
            //             title: Text("Set ${v!.id}: ${v.shortname}"),
            //           ),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
      }
    } else {
      final out =
          "${res.statusCode}: Failed to remove post ${post.id} from set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            /* () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ), */
          ),
        );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      util.showUserMessage(context: context, content: const Text(out));
    }
  }
  return v;
}

/// TODO: Multiselect
Future<e621.PostSet?> addToSetWithPost({
  required BuildContext context,
  required E6PostResponse post,
}) async {
  var logString = "Adding ${post.id}"
      " posts to a set, selecting set";
  _logger.finer(logString);
  if (context.mounted) {
    util.showUserMessage(context: context, content: Text(logString));
  }
  var v = await showDialog<e621.PostSet>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: WSearchSet.showEditableSets(
          // initialLimit: 10,
          // initialPage: null,
          // initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
          //     E621AccessData.fallbackForced?.username,
          // initialSearchOrder: e621.SetOrder.updatedAt,
          // initialSearchName: null,
          // initialSearchShortname: null,
          filterResults: (set) => !set.postIds.contains(post.id),
          showCreateSetButton: true,
          // onSelected: (e621.PostSet set) => "",
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          // onMultiselectCompleted: (_) => "",
        ),
        // scrollable: true,
      );
    },
  );
  if (v != null) {
    logString = "Adding ${post.id}"
        " posts to set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})";
    _logger.finer(logString);
    if (context.mounted) {
      util.showUserMessage(context: context, content: Text(logString));
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await e621.sendRequest(e621.initSetAddPosts(
      v.id,
      [post.id],
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ));

    lm.logResponseSmart(res, _logger);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${post.id} successfully added to set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(
            //             title: Text("Set ${v!.id}: ${v.shortname}"),
            //           ),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to add posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
          ),
        );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      util.showUserMessage(context: context, content: const Text(out));
    }
  }
  return v;
}

/// TODO: Multiselect
Future<e621.PostSet?> removeFromSetWithId({
  required BuildContext context,
  required int postId,
}) async {
  var logString = "Removing $postId"
      " from a set, selecting set";
  _logger.finer(logString);
  if (context.mounted) {
    util.showUserMessage(context: context, content: Text(logString));
  }
  var v = await showDialog<e621.PostSet>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: WSearchSet.showEditableSets(
          // initialLimit: 10,
          // initialPage: null,
          // initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
          //     E621AccessData.fallbackForced?.username,
          // initialSearchOrder: e621.SetOrder.updatedAt,
          // initialSearchName: null,
          // initialSearchShortname: null,
          filterResults: (set) => set.postIds.contains(postId),
          // onSelected: (e621.PostSet set) => "",
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          // onMultiselectCompleted: (_) => "",
        ),
        // scrollable: true,
      );
    },
  );
  if (v != null) {
    logString = "Removing $postId"
        " from set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})";
    _logger.finer(logString);
    if (context.mounted) {
      util.showUserMessage(context: context, content: Text(logString));
    }
    // final searchString =
    //     "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await e621.sendRequest(e621.initSetRemovePosts(
      v.id,
      [postId],
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ));

    lm.logResponseSmart(res, _logger);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out = "$postId successfully removed from set ${v.id} "
          "(${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (_) => Scaffold(
            //           appBar: AppBar(
            //             title: Text("Set ${v!.id}: ${v.shortname}"),
            //           ),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to remove posts from set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      util.showUserMessage(context: context, content: const Text(out));
    }
  }
  return v;
}

/// TODO: Multiselect
Future<e621.PostSet?> addToSetWithId({
  required BuildContext context,
  required int postId,
}) async {
  var logString = "Adding $postId"
      " posts to a set, selecting set";
  _logger.finer(logString);
  if (context.mounted) {
    util.showUserMessage(context: context, content: Text(logString));
  }
  var v = await showDialog<e621.PostSet>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: WSearchSet.showEditableSets(
          // initialLimit: 10,
          // initialPage: null,
          // initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
          //     E621AccessData.fallbackForced?.username,
          // initialSearchOrder: e621.SetOrder.updatedAt,
          // initialSearchName: null,
          // initialSearchShortname: null,
          onSelected: (e621.PostSet set) => "",
          // onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => !set.postIds.contains(postId),
          showCreateSetButton: true,
          onMultiselectCompleted: (_) => "",
        ),
        // scrollable: true,
      );
    },
  );
  if (v != null) {
    logString = "Adding $postId to set ${v.id} "
        "(${v.shortname}, length ${v.postCount}, length ${v.postCount})";
    _logger.finer(logString);
    if (context.mounted) {
      util.showUserMessage(context: context, content: Text(logString));
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await e621.sendRequest(e621.initSetAddPosts(
      v.id,
      [postId],
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ));

    lm.logResponseSmart(res, _logger);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out = "$postId successfully added to set ${v.id} "
          "(${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            _makeOnSeeSet(context, v)
            // () => Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => Scaffold(
            //           appBar: AppBar(
            //             title: Text("Set ${v!.id}: ${v.shortname}"),
            //           ),
            //           body: WPostSearchResults.directResultFromSearch(
            //             searchString,
            //           ),
            //         ),
            //       ),
            //     ),
          ),
        );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to add posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
          action: (
            "See Set",
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
          ),
        );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      util.showUserMessage(context: context, content: const Text(out));
    }
  }
  return v;
}

VoidFunction _makeOnSeeSet(BuildContext context, e621.PostSet v) =>
    () => Navigator.pushNamed(
          context,
          "/${SetViewPage.routeSegmentsConst.first}/${v!.id}",
          arguments: RouteParameterResolver(id: v.id, set: v),
          /* MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ), */
        );
// () => Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => Scaffold(
//           appBar: AppBar(
//             title: Text("Set ${v!.id}: ${v.shortname}"),
//           ),
//           body: WPostSearchResults.directResultFromSearch(
//             searchString,
//           ),
//         ),
//       ),
//     );
// #endregion SetSingle

// #region Vote
List<Future<E6PostResponse>> voteOnPostsWithPosts({
  BuildContext? context,
  required bool isUpvote,
  bool noUnvote = true,
  required Iterable<E6PostResponse> posts,
  bool updatePosts = true,
}) {
  final message =
      "${isUpvote ? "Upvoting" : "Downvoting"} ${posts.length} posts...";
  _logger.finer(message);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(message));
  }
  return posts.map((post) {
    lm.logRequest(
        e621.initVotePostRequest(
          postId: post.id,
          score: isUpvote ? 1 : -1,
          noUnvote: noUnvote,
          credentials: E621AccessData.allowedUserDataSafe?.cred,
        ),
        _logger,
        lm.LogLevel.INFO);
    return e621
        .sendRequest(
      e621.initVotePostRequest(
        postId: post.id,
        score: isUpvote ? 1 : -1,
        noUnvote: noUnvote,
        credentials: E621AccessData.allowedUserDataSafe?.cred,
      ),
    )
        .then(
      (v) {
        _logger.info("${post.id} vote done");
        lm.logResponseSmart(v, _logger, overrideLevel: lm.LogLevel.INFO);
        // TODO: response
        /* if (context != null && context.mounted) {
            if (!v.statusCodeInfo.isSuccessful) {
              util.showUserMessage(
                  context: context!,
                  content: Text("${v.statusCode}: ${v.reasonPhrase}"));
              return post;
            } else {
              final update = e621.UpdatedScore.fromJsonRaw(v.body);
              util.showUserMessage(
                  context: context!,
                  content: Text(createPostVoteString(
                    postId: post.id,
                    score: update,
                    oldScore: post.score,
                  )));
              return updatePosts ? updatePostWithScore(post, update) : post;
            }
          } */
        final update = e621.UpdatedScore.fromJsonRaw(v.body);
        return v.statusCodeInfo.isSuccessful && updatePosts
            ? updatePostWithScore(post, update)
            : post;
      },
    );
  }).toList();
}

List<Future<e621.UpdatedScore?>> voteOnPostsWithPostIds({
  BuildContext? context,
  required bool isUpvote,
  bool noUnvote = true,
  required Iterable<int> postIds,
  // bool updatePosts = true,
  e621.Score? oldScore,
}) {
  final message =
      "${isUpvote ? "Upvoting" : "Downvoting"} ${postIds.length} posts...";
  _logger.finer(message);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(message));
  }
  return postIds
      .map((postId) => e621
              .sendRequest(
            e621.initVotePostRequest(
              postId: postId,
              score: isUpvote ? 1 : -1,
              noUnvote: noUnvote,
              credentials: E621AccessData.allowedUserDataSafe?.cred,
            ),
          )
              .then(
            (v) {
              lm.logResponseSmart(v, _logger);
              // TODO: Response
              // if (context != null && context.mounted) {
              //   if (!v.statusCodeInfo.isSuccessful) {
              //     ScaffoldMessenger.of(context!)
              //       ..hideCurrentSnackBar()
              //       ..showSnackBar(
              //         SnackBar(
              //           content: Text("${v.statusCode}: ${v.reasonPhrase}"),
              //         ),
              //       );
              //     return null;
              //   } else {
              //     final update = e621.UpdatedScore.fromJsonRaw(v.body);
              //     ScaffoldMessenger.of(context!)
              //       ..hideCurrentSnackBar()
              //       ..showSnackBar(
              //         SnackBar(
              //           content: Text(createPostVoteString(
              //             postId: postId,
              //             score: update,
              //             oldScore: oldScore,
              //           )),
              //         ),
              //       );
              //     return update;
              //   }
              // }
              return v.statusCodeInfo.isSuccessful
                  ? e621.UpdatedScore.fromJsonRaw(v.body)
                  : null;
            },
          ))
      .toList();
}

Future<E6PostResponse> voteOnPostWithPost({
  BuildContext? context,
  required bool isUpvote,
  bool noUnvote = true,
  required E6PostResponse post,
  bool updatePost = true,
}) {
  final message = "${isUpvote ? "Upvoting" : "Downvoting"} ${post.id}...";
  _logger.finer(message);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(message));
  }
  return e621
      .sendRequest(
    e621.initVotePostRequest(
      postId: post.id,
      score: isUpvote ? 1 : -1,
      noUnvote: noUnvote,
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ),
  )
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      if (context != null && context.mounted) {
        if (!v.statusCodeInfo.isSuccessful) {
          util.showUserMessage(
              context: context,
              content: Text("${v.statusCode}: ${v.reasonPhrase}"));
          return post;
        } else {
          final update = e621.UpdatedScore.fromJsonRaw(v.body);
          util.showUserMessage(
              context: context,
              content: Text(createPostVoteStringStrict(
                postId: post.id,
                score: update,
                oldScore: post.score,
                noUnvote: noUnvote,
                castVote: isUpvote ? 1 : -1,
              )));
          return updatePost ? updatePostWithScore(post, update) : post;
        }
      }
      final update = e621.UpdatedScore.fromJsonRaw(v.body);
      return v.statusCodeInfo.isSuccessful && updatePost
          ? updatePostWithScore(post, update)
          : post;
    },
  );
}

Future<e621.UpdatedScore?> voteOnPostWithId({
  BuildContext? context,
  bool noUnvote = true,
  required bool isUpvote,
  e621.Score? oldScore,
  required int postId,
}) {
  _print("${isUpvote ? "Upvoting" : "Downvoting"} $postId...");
  if (context != null && context.mounted) {
    util.showUserMessage(
      context: context,
      content: Text("${isUpvote ? "Upvoting" : "Downvoting"} $postId..."),
    );
  }
  return e621
      .sendRequest(
    e621.initVotePostRequest(
      postId: postId,
      score: isUpvote ? 1 : -1,
      noUnvote: noUnvote,
      credentials: E621AccessData.allowedUserDataSafe?.cred,
    ),
  )
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      if (context != null && context.mounted) {
        if (!v.statusCodeInfo.isSuccessful) {
          util.showUserMessage(
            context: context,
            content: Text("${v.statusCode}: ${v.reasonPhrase}"),
          );
          return null;
        } else {
          final update = e621.UpdatedScore.fromJsonRaw(v.body);
          util.showUserMessage(
            context: context,
            content: Text(createPostVoteStringStrict(
              postId: postId,
              score: update,
              oldScore: oldScore,
              noUnvote: noUnvote,
              castVote: isUpvote ? 1 : -1,
            )),
          );
          return update;
        }
      }
      return v.statusCodeInfo.isSuccessful
          ? e621.UpdatedScore.fromJsonRaw(v.body)
          : null;
    },
  );
}

// #endregion Vote
// #region Downloads
Future<String?> downloadPostRoot(E6PostResponse post) =>
    /* e621.client
      .get(
        post.file.address,
        headers: (E621AccessData.fallbackForced?.cred ?? e621.activeCredentials)
            ?.addToTyped({"Access-Control-Allow-Origin":"*"}),
      )
      .then((r) =>  */
    (Platform.isWeb
        ? saver.FileSaver.instance.saveFile
        : saver.FileSaver.instance.saveAs)(
      name: "[${post.id}] ${post.file.url.split(RegExp(r"\\|/")).last}",
      link: saver.LinkDetails(
        link: post.file.url,
        headers:
            (E621AccessData.forcedUserDataSafe?.cred ?? e621.activeCredentials)
                ?.addToTyped({}),
      ),
      // bytes: r.bodyBytes,
      ext: "",
      mimeType: switch (
          post.file.url.substring(post.file.url.lastIndexOf("."))) {
        // String s when saver.MimeType.values.any((e) => (e as Enum).name.startsWith(s)) => saver.MimeType.values.firstWhere((e) => (e as Enum).name.startsWith(s)),
        "png" => saver.MimeType.png,
        "mp4" => saver.MimeType.mp4Video,
        "gif" => saver.MimeType.gif,
        "jpeg" || "jpg" => saver.MimeType.jpeg,
        "apng" => saver.MimeType.apng,
        _ => saver.MimeType.other,
      },
    ) //)
    ;
const valueOnError = "FAILED";
Future<String> downloadPostWithPost({
  final BuildContext? context,
  required E6PostResponse post,
}) {
  final id = post.id;
  final out = "Downloading post $id...";
  _logger.finer(out);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(out));
  }
  return downloadPostRoot(post).then((v) {
    final out = "Downloaded $id to ${v ?? "an unknown path"}";
    _logger.info(out);
    if (context != null && context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text(out),
      );
    }
    return v ?? "";
  }).onError((e, s) {
    final out = "Failed to download $id";
    _logger.severe(out, e, s);
    if (context != null && context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text("$out ($e)"),
        duration: const Duration(seconds: 10),
      );
    }
    return valueOnError;
  });
}

Future<String> downloadPostWithId({
  final BuildContext? context,
  required final int postId,
}) =>
    e621
        .sendRequest(e621.initPostGet(postId))
        .then((r) => downloadPostWithPost(
              // ignore: use_build_context_synchronously
              context: context,
              post: E6PostResponse.fromRawJson(r.body),
            ))
        .onError((e, s) {
      final out = "Failed to download $postId";
      _logger.severe(out, e, s);
      if (context != null && context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text("$out (${e.runtimeType})"),
          duration: const Duration(seconds: 10),
        );
      }
      return valueOnError;
    });
Future<List<String>> downloadPostsWithPosts({
  final BuildContext? context,
  required Iterable<E6PostResponse> posts,
}) {
  final out = "Downloading ${posts.length} posts...";
  _logger.finer(out);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(out));
  }
  return Future.wait(posts.map((e) => downloadPostRoot(e).then((v) {
        final out = "Downloaded ${e.id} to ${v ?? "an unknown path"}";
        _logger.finer(out);
        return v ?? "";
      }).onError((er, s) {
        final out = "Failed to download ${e.id}";
        _logger.severe(out, er, s);
        return valueOnError;
      }))).then((v) {
    final out =
        "${v.where((e) => e != valueOnError).length}/${v.length} posts downloaded";
    _logger.info(out);
    if (context != null && context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text(out),
      );
    }
    return v;
  });
}

Future<List<String>> downloadPostsWithIds({
  final BuildContext? context,
  required final Iterable<int> postIds,
}) =>
    Future.wait(postIds.map((postId) => e621
            .sendRequest(e621.initPostGet(postId))
            .then((r) => E6PostResponse.fromRawJson(r.body))
            .onError((e, s) {
          final out = "Failed to get $postId";
          _logger.severe(out, e, s);
          // if (context != null && context.mounted) {
          //   util.showUserMessage(
          //     context: context!,
          //     content: Text("$out (${e.runtimeType})"),
          //     duration: const Duration(seconds: 10),
          //   );
          // }
          // return valueOnError;
          return E6PostResponse.error;
        }).then((e) => downloadPostRoot(e).then((v) {
                  final out = "Downloaded ${e.id} to ${v ?? "an unknown path"}";
                  _logger.finer(out);
                  return v ?? "";
                }).onError((er, s) {
                  final out = "Failed to download ${e.id}";
                  _logger.severe(out, er, s);
                  return valueOnError;
                })))).then((v) {
      final out =
          "${v.where((e) => e != valueOnError).length}/${v.length} posts downloaded";
      _logger.info(out);
      if (context != null && context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
        );
      }
      return v;
    });

Future<String?> downloadDescriptionRoot(E6PostResponse post) {
  return (Platform.isWeb
      ? saver.FileSaver.instance.saveFile
      : saver.FileSaver.instance.saveAs)(
    name: "${post.id}",
    bytes: dc.utf8.encode(post.description),
    ext: ".txt",
    mimeType: saver.MimeType.text,
  );
}

Future<String> downloadDescriptionWithPost({
  final BuildContext? context,
  required E6PostResponse post,
}) {
  final id = post.id;
  final out = "Downloading post $id description...";
  _logger.finer(out);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(out));
  }
  return downloadDescriptionRoot(post).then((v) {
    final out = "Downloaded $id to ${v ?? "an unknown path"}";
    _logger.info(out);
    if (context != null && context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text(out),
      );
    }
    return v ?? "";
  }).onError((e, s) {
    final out = "Failed to download $id";
    _logger.severe(out, e, s);
    if (context != null && context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text("$out ($e)"),
        duration: const Duration(seconds: 10),
      );
    }
    return valueOnError;
  });
}

Future<String> downloadDescriptionWithId({
  final BuildContext? context,
  required final int postId,
}) =>
    e621
        .sendRequest(e621.initPostGet(postId))
        .then((r) => downloadDescriptionWithPost(
              // ignore: use_build_context_synchronously
              context: context,
              post: E6PostResponse.fromRawJson(r.body),
            ))
        .onError((e, s) {
      final out = "Failed to download $postId";
      _logger.severe(out, e, s);
      if (context != null && context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text("$out (${e.runtimeType})"),
          duration: const Duration(seconds: 10),
        );
      }
      return valueOnError;
    });
Future<List<String>> downloadDescriptionsWithPosts({
  final BuildContext? context,
  required Iterable<E6PostResponse> posts,
}) {
  final out = "Downloading ${posts.length} posts...";
  _logger.finer(out);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(out));
  }
  return Future.wait(posts.map((e) => downloadDescriptionRoot(e).then((v) {
        final out = "Downloaded ${e.id} to ${v ?? "an unknown path"}";
        _logger.finer(out);
        return v ?? "";
      }).onError((er, s) {
        final out = "Failed to download ${e.id}";
        _logger.severe(out, er, s);
        return valueOnError;
      }))).then((v) {
    final out =
        "${v.where((e) => e != valueOnError).length}/${v.length} descriptions downloaded";
    _logger.info(out);
    if (context != null && context.mounted) {
      util.showUserMessage(
        context: context,
        content: Text(out),
      );
    }
    return v;
  });
}

Future<List<String>> downloadDescriptionsWithIds({
  final BuildContext? context,
  required final Iterable<int> postIds,
}) =>
    Future.wait(postIds.map((postId) => e621
            .sendRequest(e621.initPostGet(postId))
            .then((r) => E6PostResponse.fromRawJson(r.body))
            .onError((e, s) {
          final out = "Failed to get $postId";
          _logger.severe(out, e, s);
          return E6PostResponse.error;
        }).then(
          (e) => downloadDescriptionRoot(e).then((v) {
            final out = "Downloaded ${e.id} to ${v ?? "an unknown path"}";
            _logger.finer(out);
            return v ?? "";
          }).onError((er, s) {
            final out = "Failed to download ${e.id}";
            _logger.severe(out, er, s);
            return valueOnError;
          }),
        ))).then((v) {
      final out =
          "${v.where((e) => e != valueOnError).length}/${v.length} posts downloaded";
      _logger.info(out);
      if (context != null && context.mounted) {
        util.showUserMessage(
          context: context,
          content: Text(out),
        );
      }
      return v;
    });
// #endregion Downloads
// #region Comments

// #endregion Comments
// #region Helpers
/// TODO: FIX
String createPostVoteString({
  required int postId,
  required e621.UpdatedScore score,
  e621.Score? oldScore,
  required bool noUnvote,
  required int castVote,
}) {
  if (!noUnvote && score.ourScore == 0) {
    return "Removed ${score.total == (oldScore?.total ?? score.total) + 1 ? "up" : score.total == (oldScore?.total ?? score.total) - 1 ? "down" : ""}vote on $postId";
  }
  final out = switch (score.ourScore) {
    > 0 => "upvote",
    < 0 => "downvote",
    0 => switch (castVote) {
        > 0 => "upvote",
        < 0 => "downvote",
        _ => throw UnsupportedError("type not supported"),
      },
    _ => throw UnimplementedError(),
  };
  return oldScore != null && score.total == oldScore.total ||
          noUnvote && score.ourScore == 0
      ? "Already ${out}d $postId, kept $out"
      : "$postId ${out}d";
}

String createPostVoteStringStrict({
  required int postId,
  required e621.UpdatedScore score,
  e621.Score? oldScore,
  required bool noUnvote,
  required int castVote,
}) {
  final ourScore = e621.UpdatedScore.determineOurTrueScore(
      castVote, score.ourScore, noUnvote);
  if (!noUnvote && ourScore == 0) {
    return "Removed ${score.total == (oldScore?.total ?? score.total) + 1 ? "up" : score.total == (oldScore?.total ?? score.total) - 1 ? "down" : ""}vote on $postId";
  }
  final out = switch (castVote) {
    > 0 => "upvote",
    < 0 => "downvote",
    _ => throw UnimplementedError(),
  };
  return score.ourScore == 0 //oldScore != null && score.total == oldScore.total
      ? "Already ${out}d $postId, kept $out"
      : "$postId ${out}d";
}

E6PostResponse updatePostWithScore(
    E6PostResponse post, e621.UpdatedScore update) {
  if (post is E6PostMutable) {
    post.score = update;
    return post;
  } else {
    return post.copyWith(score: update);
  }
}
// #endregion Helpers

class WBatchFavRemoval extends StatefulWidget {
  final Stream<RemoveFavEvent> stream;
  final int numPosts;
  const WBatchFavRemoval(
      {super.key, required this.stream, required this.numPosts});

  @override
  State<WBatchFavRemoval> createState() => _WBatchFavRemovalState();
}

class _WBatchFavRemovalState extends State<WBatchFavRemoval> {
  late final StreamSubscription<RemoveFavEvent> sub;
  RemoveFavEvent? curr;

  @override
  void initState() {
    super.initState();
    sub = widget.stream.listen(onData);
  }

  @override
  void dispose() {
    sub.onData(null);
    sub.cancel().ignore();
    super.dispose();
  }

  void onData(RemoveFavEvent e) => setState(() => curr = e);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (curr != null)
          Text(
              "${(curr!.progress * 100).round()}%: ${curr!.currentSent}/${curr!.totalPosts} sent, ")
        else
          Text("Removing ${widget.numPosts} posts from favorites"),
        LinearProgressIndicator(value: curr?.progress),
      ],
    );
  }
}

class RemoveFavEvent {
  final List<E6PostResponse>? posts;
  final List<E6PostResponse>? successfulPosts;
  final List<int>? postIds;
  final List<int>? successfulPostIds;
  final int totalPosts;
  final int currentSent;
  final int currentReceived;
  final int currentEventPostId;
  final E6PostResponse? currentEventPost;
  final bool wasRequest;
  final FutureOr<Response> result;

  RemoveFavEvent({
    required this.totalPosts,
    required this.currentSent,
    required this.currentReceived,
    required this.currentEventPostId,
    required this.wasRequest,
    required this.currentEventPost,
    required this.result,
    required this.posts,
    required this.successfulPosts,
    required this.postIds,
    required this.successfulPostIds,
  });
  RemoveFavEvent.withPost({
    required this.totalPosts,
    required this.currentSent,
    required this.currentReceived,
    required this.wasRequest,
    required E6PostResponse this.currentEventPost,
    required List<E6PostResponse> this.posts,
    required List<E6PostResponse> this.successfulPosts,
    required this.result,
  })  : currentEventPostId = currentEventPost.id,
        postIds = null,
        successfulPostIds = null;
  RemoveFavEvent.withId({
    required this.totalPosts,
    required this.currentSent,
    required this.currentReceived,
    required this.wasRequest,
    this.currentEventPost,
    required this.currentEventPostId,
    required this.result,
    required List<int> this.postIds,
    required List<int> this.successfulPostIds,
    this.successfulPosts,
  }) : posts = null;
  double get progress => (currentSent + currentReceived * 3) / totalPosts * 4;
  double get sentProgress => currentSent / totalPosts;
  double get receivedProgress => currentReceived / totalPosts;
  // bool get isComplete => wasRequest &&
  // bool get wasFailure => wasRequest &&
}

Stream<RemoveFavEvent> testRemoveFavoritesWithPosts({
  BuildContext? context,
  required List<E6PostResponse> posts,
  bool updatePost = true,
}) {
  var str = "Removing ${posts.length} posts from favorites...";
  _logger.finer(str);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(str));
  }
  var currentSent = 0;
  var currentReceived = 0;
  final successes = <E6PostResponse>[];

  final ctr = StreamController<RemoveFavEvent>.broadcast();
  dispatch() async* {
    for (final post in posts) {
      yield RemoveFavEvent.withPost(
        successfulPosts: successes,
        posts: posts,
        currentEventPost: post,
        currentReceived: currentReceived,
        currentSent: currentSent,
        totalPosts: posts.length,
        wasRequest: true,
        result: e621.sendRequest(
          e621.initFavoriteDelete(
            postId: post.id,
            credentials: E621AccessData.allowedUserDataSafe?.cred,
          ),
          useBurst: true,
        )..then(
            (value) {
              ++currentReceived;
              lm.logResponseSmart(value, _logger);
              if (value.statusCodeInfo.isSuccessful) {
                final v = E6PostResponse.fromRawJson(value.body);
                if (updatePost && post is E6PostMutable) {
                  post.overwriteFrom(v);
                }
                successes.add(v);
              }
              ctr.add(RemoveFavEvent.withPost(
                posts: posts,
                successfulPosts: successes,
                currentReceived: currentReceived,
                currentSent: currentSent,
                totalPosts: posts.length,
                currentEventPost: post,
                wasRequest: false,
                result: value,
              ));
              if (currentReceived == posts.length) {
                ctr
                    .close()
                    .then((_) => _logger.info("Remove fav controller closed"))
                    .ignore();
              }
            },
          ).ignore(),
      );
    }
  }

  ctr.addStream(dispatch());
  if (context != null && context.mounted) {
    util.showUserMessageBanner(
        duration: null,
        context: context,
        content: WBatchFavRemoval(stream: ctr.stream, numPosts: posts.length));
  }
  return ctr.stream;
}

Stream<RemoveFavEvent> testRemoveFavoritesWithIds({
  BuildContext? context,
  required List<int> ids,
}) {
  var str = "Removing ${ids.length} posts from favorites...";
  _logger.finer(str);
  if (context != null && context.mounted) {
    util.showUserMessage(context: context, content: Text(str));
  }
  var currentSent = 0;
  var currentReceived = 0;
  final successes = <int>[], successfulPosts = <E6PostResponse>[];

  final ctr = StreamController<RemoveFavEvent>.broadcast();
  dispatch() async* {
    for (final post in ids) {
      yield RemoveFavEvent.withId(
        currentEventPostId: post,
        successfulPostIds: successes,
        postIds: ids,
        // successfulPosts: successes,
        // posts: ids,
        successfulPosts: successfulPosts,
        // currentEventPost: post,
        currentReceived: currentReceived,
        currentSent: currentSent,
        totalPosts: ids.length,
        wasRequest: true,
        result: e621.sendRequest(
          e621.initFavoriteDelete(
            postId: post,
            credentials: E621AccessData.allowedUserDataSafe?.cred,
          ),
          useBurst: true,
        )..then(
            (value) {
              ++currentReceived;
              lm.logResponseSmart(value, _logger);
              final E6PostResponse? v;
              if (value.statusCodeInfo.isSuccessful) {
                v = E6PostResponse.fromRawJson(value.body);
                successes.add(post);
                successfulPosts.add(v);
              } else {
                v = null;
              }
              ctr.add(RemoveFavEvent.withId(
                postIds: ids,
                successfulPostIds: successes,
                successfulPosts: successfulPosts,
                currentReceived: currentReceived,
                currentSent: currentSent,
                totalPosts: ids.length,
                currentEventPost: v,
                wasRequest: false,
                result: value,
                currentEventPostId: post,
              ));
              if (currentReceived == ids.length) {
                ctr
                    .close()
                    .then((_) => _logger.info("Remove fav controller closed"))
                    .ignore();
              }
            },
          ).ignore(),
      );
    }
  }

  ctr.addStream(dispatch());
  if (context != null && context.mounted) {
    util.showUserMessageBanner(
        duration: null,
        context: context,
        content: WBatchFavRemoval(stream: ctr.stream, numPosts: ids.length));
  }
  return ctr.stream;
}

// #region Tag Based
void makeNewSearch(
        {required String searchText, required BuildContext context}) =>
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => buildHomePageWithProviders(
            searchText: searchText,
          ),
        ));
// void addToCurrentSearch{
//                     widget.onAddToSearch?.call(tag);
//                     // widget.tagsToAdd?.add(tag);
//                     Navigator.pop(context);
//                   }
// #region Blacklist
bool isInLocalBlacklist(String tag, {bool defaultIfNull = true}) =>
    AppSettings.i?.blacklistedTags.contains(tag) ?? defaultIfNull;
bool? isInLocalBlacklistSafe(String tag) =>
    AppSettings.i?.blacklistedTags.contains(tag);
bool addToLocalBlacklist({
  required String tag,
  required BuildContext context,
  bool pop = true,
}) {
  if (pop) Navigator.pop(context);
  if (AppSettings.i?.blacklistedTags.add(tag) ?? false) {
    AppSettings.i?.writeToFile();
    return true;
  } else {
    return false;
  }
}

bool removeFromLocalBlacklist({
  required String tag,
  required BuildContext context,
  bool pop = true,
}) {
  if (pop) Navigator.pop(context);
  if (AppSettings.i?.blacklistedTags.remove(tag) ?? false) {
    AppSettings.i?.writeToFile();
    return true;
  } else {
    return false;
  }
}
// #endregion Blacklist

// #region Favorite Tags
bool isInLocalFavorites(String tag, {bool defaultIfNull = true}) =>
    AppSettings.i?.favoriteTags.contains(tag) ?? defaultIfNull;
bool? isInLocalFavoritesSafe(String tag) =>
    AppSettings.i?.favoriteTags.contains(tag);
bool addToLocalFavorites({
  required String tag,
  required BuildContext context,
  bool pop = true,
}) {
  if (pop) Navigator.pop(context);
  if (AppSettings.i?.favoriteTags.add(tag) ?? false) {
    AppSettings.i?.writeToFile();
    return true;
  } else {
    return false;
  }
}

bool removeFromLocalFavorites({
  required String tag,
  required BuildContext context,
  bool pop = true,
}) {
  if (pop) Navigator.pop(context);
  if (AppSettings.i?.favoriteTags.remove(tag) ?? false) {
    AppSettings.i?.writeToFile();
    return true;
  } else {
    return false;
  }
}
// #endregion Favorite Tags

// #region Saved Searches
String _defaultFormatter(String search) => search.trim();
bool isInSavedSearches(
  String search, [
  String Function(String) formatter = _defaultFormatter,
]) =>
    SavedDataE6.all.any((e) => formatter(e.searchString) == search);
Future<SavedSearchData?> addToSavedSearches({
  required String text,
  required BuildContext context,
  String? parent,
  String? title,
  bool pop = false,
}) {
  if (pop) Navigator.pop(context);
  return showSavedElementEditDialogue(
    context,
    initialData: text,
    initialParent: parent,
    initialTitle: title ?? text,
    initialUniqueId: text,
  ).then((value) => value != null
      ? SavedDataE6.doOnInit(() {
          final t = SavedSearchData.fromTagsString(
            searchString: value.mainData,
            title: value.title,
            uniqueId: value.uniqueId ?? "",
            parent: value.parent ?? "",
          );
          SavedDataE6.$addAndSaveSearch(t);
          return t;
        })
      : null);
}

Future<SavedSearchData?> addToASavedSearch({
  required String text,
  required BuildContext context,
  bool pop = false,
  // String? parent,
  // String? title,
}) {
  if (pop) Navigator.pop(context);
  return showDialog<SavedSearchData>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Select a search"),
        content: SizedBox(
          width: double.maxFinite,
          child: SavedDataE6.buildParentedView(
            context: context,
            generateOnTap: (e) => () => Navigator.pop(context, e),
          ),
        ),
      );
    },
  ).then((e) => e == null
      ? null
      : showSavedElementEditDialogue(
          // ignore: use_build_context_synchronously
          context,
          initialData: "${e.searchString} $text",
          initialParent: e.parent,
          initialTitle: e.title,
          initialUniqueId: e.uniqueId,
          initialEntry: e,
        ).then((v) {
          if (v == null) return null;
          final r = SavedSearchData.fromTagsString(
            searchString: v.mainData,
            title: v.title,
            uniqueId: v.uniqueId ?? "",
            parent: v.parent ?? "",
          );
          SavedDataE6.$editAndSave(original: e, edited: r);
          return r;
        }));
}
// #endregion Saved Searches

void searchForTagWikiInBrowser(
  String tag, [
  BuildContext? context,
  bool pop = true,
]) {
  final url = Uri.parse("https://e621.net/wiki_pages/show_or_new?title=$tag");
  util.defaultTryLaunchUrl(url);
  if (pop) util.contextCheck(context, (c) => Navigator.pop(c));
}

void popUpTagWikiPage({
  required String tag,
  required BuildContext context,
  bool pop = true,
}) {
  if (pop) Navigator.pop(context);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: AppBar(title: Text(tag)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: WikiPageLoader.fromTitle(
            title: tag,
            isFullPage: false,
          ),
        ),
      ),
    ),
  );
  /* showDialog(
    context: context,
    builder: (context) {
      e621.WikiPage? result;
      Future<e621.WikiPage>? f;
      f = e621
          .sendRequest(E621.initWikiTagSearchRequest(tag: tag))
          .then((value) => e621.WikiPage.fromRawJson(value.body));
      return AlertDialog(
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setState) {
              f
                  ?.then((v) => setState(() {
                        result = v;
                        f?.ignore();
                        f = null;
                      }))
                  .ignore();
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f != null)
                      // util.spinnerExpanded
                      const CircularProgressIndicator()
                    else
                      result != null
                          ? Text.rich(dt.parse(result!.body))
                          : const Text("Failed to load"),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  ); */
}

bool isSubscribed(String tag) =>
    SubscriptionManager.subscriptions.any((e) => e.tag == tag);
Future<bool> addSubscription(
  String tag,
  int lastId, [
  BuildContext? context,
  bool pop = true,
]) {
  if (pop) util.contextCheck(context, (context) => Navigator.pop(context));
  return SubscriptionManager.subscriptions
          .add(TagSubscription(tag: tag, lastId: lastId))
      ? SubscriptionManager.writeToStorage()
      : Future.value(false);
}

Future<bool> removeSubscription(
  String tag,
  int lastId, [
  BuildContext? context,
  bool pop = true,
]) {
  if (pop) util.contextCheck(context, (context) => Navigator.pop(context));
  return SubscriptionManager.subscriptions.remove(
          SubscriptionManager.subscriptions.firstWhere((e) => e.tag == tag))
      ? SubscriptionManager.writeToStorage()
      : Future.value(false);
}
// #endregion Tag Based
