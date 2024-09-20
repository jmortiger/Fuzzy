import 'dart:async';
import 'dart:convert' as dc;

import 'package:e621/e621.dart' as e621;
import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart' as cf;
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:file_saver/file_saver.dart' as saver;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

// #region Logger
lm.Printer get _print => lRecord.print;
lm.FileLogger get _logger => lRecord.logger;
// ignore: unnecessary_late
late final lRecord = lm.generateLogger("E6Actions");
// #endregion Logger

// #region Favorites
Future<E6PostResponse> addPostToFavoritesWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
}) =>
    _addPostToFavorites(context: context, post: post, updatePost: updatePost)
        .then((v) => v!);
/* }) {
  final out = "Adding ${post.id} to favorites...";
  _logger.finer(out);
  if (context?.mounted ?? false) {
    util.showUserMessage(
      context: context!,
      content: Text(out),
    );
  }
  if (AppSettings.i!.upvoteOnFavorite) {
    voteOnPostWithPost(isUpvote: true, post: post).ignore();
  }
  return E621
      // .sendRequest(
      //   E621.initAddFavoriteRequest(
      //     postId,
      //     username: E621AccessData.fallback?.username,
      //     apiKey: E621AccessData.fallback?.apiKey,
      //   ),
      // )
      // .toResponse()
      .sendAddFavoriteRequest(
    post.id,
    username: E621AccessData.fallback?.username,
    apiKey: E621AccessData.fallback?.apiKey,
  )
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      E6PostResponse postRet = v.statusCodeInfo.isSuccessful
          ? E6PostResponse.fromRawJson(v.body)
          : post;
      if (context?.mounted ?? false) {
        !v.statusCodeInfo.isSuccessful
            ? util.showUserMessage(
                context: context!,
                content: Text("${v.statusCode}: ${v.reasonPhrase}"))
            : util.showUserMessage(
                context: context!,
                content: Text("${post.id} added to favorites"),
                action: (
                    "Undo",
                    () => removePostFromFavoritesWithPost(
                          post: post,
                          updatePost: updatePost,
                          context: context,
                        )
                  ));
      }
      return updatePost && post is E6PostMutable
          ? (post..overwriteFrom(postRet))
          : postRet;
    },
  );
} */

Future<E6PostResponse?> addPostToFavoritesWithId({
  BuildContext? context,
  required int postId,
}) =>
    _addPostToFavorites(context: context, postId: postId);
/* }) {
  final out = "Adding $postId to favorites...";
  _logger.finer(out);
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(out));
  }
  if (AppSettings.i!.upvoteOnFavorite) {
    voteOnPostWithId(isUpvote: true, postId: postId).ignore();
  }
  return E621
      // .sendRequest(
      //   E621.initAddFavoriteRequest(
      //     postId,
      //     username: E621AccessData.fallback?.username,
      //     apiKey: E621AccessData.fallback?.apiKey,
      //   ),
      // )
      // .toResponse()
      .sendAddFavoriteRequest(
    postId,
    username: E621AccessData.fallback?.username,
    apiKey: E621AccessData.fallback?.apiKey,
  )
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      final postRet = v.statusCodeInfo.isSuccessful
          ? E6PostResponse.fromRawJson(v.body)
          : null;
      if (context?.mounted ?? false) {
        !v.statusCodeInfo.isSuccessful
            ? util.showUserMessage(
                context: context!,
                content: Text("${v.statusCode}: ${v.reasonPhrase}"))
            : util.showUserMessage(
                context: context!,
                content: Text("$postId added to favorites"),
                action: (
                    "Undo",
                    () => removePostFromFavoritesWithId(
                          postId: postId,
                          context: context,
                        )
                  ));
      }
      return postRet;
    },
  );
} */

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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(out));
  }
  if (AppSettings.i!.upvoteOnFavorite) {
    (post != null
            ? voteOnPostWithPost(isUpvote: true, post: post)
            : voteOnPostWithId(isUpvote: true, postId: id))
        .ignore();
  }
  return E621
      // .sendRequest(
      //   E621.initAddFavoriteRequest(
      //     id,
      //     username: E621AccessData.fallback?.username,
      //     apiKey: E621AccessData.fallback?.apiKey,
      //   ),
      // )
      // .toResponse()
      .sendAddFavoriteRequest(
    id,
    username: E621AccessData.fallback?.username,
    apiKey: E621AccessData.fallback?.apiKey,
  )
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      var postRet = v.statusCodeInfo.isSuccessful
          ? E6PostMutable.fromRawJson(v.body)
          : post;
      if (context?.mounted ?? false) {
        !v.statusCodeInfo.isSuccessful
            ? util.showUserMessage(
                context: context!,
                content: Text("${v.statusCode}: ${v.reasonPhrase}"))
            : util.showUserMessage(
                context: context!,
                content: Text("$id removed from favorites"),
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(out));
  }
  return E621
      .sendRequest(
        E621.initDeleteFavoriteRequest(
          id,
          username: E621AccessData.fallback?.username,
          apiKey: E621AccessData.fallback?.apiKey,
        ),
      )
      .toResponse()
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      var postRet = v.statusCodeInfo.isSuccessful
          ? E6PostMutable.fromRawJson(v.body)
          : post;
      if (context?.mounted ?? false) {
        !v.statusCodeInfo.isSuccessful
            ? util.showUserMessage(
                context: context!,
                content: Text("${v.statusCode}: ${v.reasonPhrase}"))
            : util.showUserMessage(
                context: context!,
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
    },
  );
}

Future< /* Iterable<E6PostResponse> */ void> addToFavoritesWithPosts({
  BuildContext? context,
  required Iterable<E6PostResponse> posts,
  bool updatePost = true,
}) {
  var str = "Adding ${posts.length} posts to favorites...";
  _logger.finer(str);
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(str));
  }
  if (AppSettings.i!.upvoteOnFavorite) {
    voteOnPostsWithPosts(isUpvote: true, posts: posts).map((e) => e.ignore());
  }
  final pIds = posts.map((e) => e.id);
  return E621.sendAddFavoriteRequestBatch(
    pIds,
    username: E621AccessData.fallback?.username,
    apiKey: E621AccessData.fallback?.apiKey,
    onComplete: (responses) {
      var total = responses.length;
      responses.removeWhere(
        (element) => element.statusCodeInfo.isSuccessful,
      );
      var sbs = "${total - responses.length}/"
          "$total posts added to favorites!";
      responses.where((r) => r.statusCode == 422).forEach((r) async {
        var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
        if ((context?.mounted ?? false) &&
            Provider.of<cf.CachedFavorites>(context!, listen: false)
                .postIds
                .contains(pId)) {
          sbs += " $pId Cached";
        }
      });
      if (context?.mounted ?? false) {
        util.showUserMessage(
          context: context!,
          content: Text(sbs),
          action: (
            "Undo",
            () async {
              E621.sendDeleteFavoriteRequestBatch(
                pIds,
                username: E621AccessData.fallback?.username,
                apiKey: E621AccessData.fallback?.apiKey,
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(str));
  }
  if (AppSettings.i!.upvoteOnFavorite) {
    voteOnPostsWithPostIds(isUpvote: true, postIds: postIds)
        .map((e) => e.ignore());
  }
  return E621.sendAddFavoriteRequestBatch(
    postIds,
    username: E621AccessData.fallback?.username,
    apiKey: E621AccessData.fallback?.apiKey,
    onComplete: (responses) {
      var total = responses.length;
      responses.removeWhere(
        (element) => element.statusCodeInfo.isSuccessful,
      );
      var sbs = "${total - responses.length}/"
          "$total posts added to favorites!";
      responses.where((r) => r.statusCode == 422).forEach((r) async {
        var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
        if ((context?.mounted ?? false) &&
            Provider.of<cf.CachedFavorites>(context!, listen: false)
                .postIds
                .contains(pId)) {
          sbs += " $pId Cached";
        }
      });
      if (context?.mounted ?? false) {
        util.showUserMessage(
          context: context!,
          content: Text(sbs),
          action: (
            "Undo",
            () async {
              E621.sendDeleteFavoriteRequestBatch(
                postIds,
                username: E621AccessData.fallback?.username,
                apiKey: E621AccessData.fallback?.apiKey,
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(str));
  }
  final pIds = posts.map((e) => e.id);
  return E621.sendDeleteFavoriteRequestBatch(
    pIds,
    username: E621AccessData.fallback?.username,
    apiKey: E621AccessData.fallback?.apiKey,
    onComplete: (responses) {
      var total = responses.length;
      responses.removeWhere(
        (element) => element.statusCodeInfo.isSuccessful,
      );
      var sbs = "${total - responses.length}/"
          "$total posts removed from favorites!";
      // responses.where((r) => r.statusCode == 422).forEach((r) async {
      //   var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
      //   if ((context?.mounted ?? false) &&
      //       Provider.of<cf.CachedFavorites>(context!, listen: false)
      //           .postIds
      //           .contains(pId)) {
      //     sbs += " $pId Cached";
      //   }
      // });
      if (context?.mounted ?? false) {
        util.showUserMessage(
          context: context!,
          content: Text(sbs),
          action: (
            "Undo",
            () async {
              E621.sendAddFavoriteRequestBatch(
                pIds,
                username: E621AccessData.fallback?.username,
                apiKey: E621AccessData.fallback?.apiKey,
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

Stream<E6BatchActionEvent> removeFavoritesWithPosts({
  BuildContext? context,
  required Iterable<E6PostResponse> posts,
  bool updatePost = true,
}) async* {
  var str = "Removing ${posts.length} posts from favorites...";
  _logger.finer(str);
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(str));
  }
  final pIds = posts.map((e) => e.id).toList();
  final totalProgressSend = pIds.length;
  var currentProgressSend = 0;
  final totalProgressReceive = pIds.length;
  var currentProgressReceive = 0;
  String m(num _, num __) {
    return "$currentProgressSend/"
        "$totalProgressSend favorite removal requests sent!";
  }

  String m2(num _, num __) {
    return "$currentProgressReceive/"
        "$totalProgressReceive posts removed from favorites!";
  }

  final results = <Future<E6BatchActionEvent<dynamic>>>[];
  for (var i = 0; i < pIds.length; i++) {
    results.add(e621
        .sendRequest(
      e621.initDeleteFavoriteRequest(
        postId: pIds[i],
        credentials: E621AccessData.fallback?.cred,
      ),
      useBurst: true,
    )
        .then(
      (value) {
        ++currentProgressReceive;
        lm.logResponseSmart(value, _logger);
        if (value.statusCodeInfo.isSuccessful) {
          return E6BatchActionEvent.builder(
            currentProgress: currentProgressReceive + currentProgressSend,
            messageBuilder: m2,
            totalProgress: totalProgressReceive + totalProgressSend,
            sideAction: (
              "Undo",
              () => addPostToFavoritesWithPost(post: posts.elementAt(i))
            ),
          );
        } else {
          return E6BatchActionEvent.builder(
            currentProgress: currentProgressReceive + currentProgressSend,
            messageBuilder: m2,
            totalProgress: totalProgressReceive + totalProgressSend,
            sideAction: (
              "Undo",
              () => addPostToFavoritesWithPost(post: posts.elementAt(i))
            ),
            error: value.reasonPhrase,
          );
        }
      },
    ));
    yield E6BatchActionEvent.builder(
      currentProgress: ++currentProgressSend + currentProgressReceive,
      totalProgress: totalProgressSend + totalProgressReceive,
      messageBuilder: m,
    );
  }
  yield* Stream.fromFutures(results);
  // return E621.sendDeleteFavoriteRequestBatch(
  //   pIds,
  //   username: E621AccessData.fallback?.username,
  //   apiKey: E621AccessData.fallback?.apiKey,
  //   onComplete: (responses) {
  //     var total = responses.length;
  //     responses.removeWhere(
  //       (element) => element.statusCodeInfo.isSuccessful,
  //     );
  //     var sbs = "${total - responses.length}/"
  //         "$total posts removed from favorites!";
  //     // responses.where((r) => r.statusCode == 422).forEach((r) async {
  //     //   var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
  //     //   if ((context?.mounted ?? false) &&
  //     //       Provider.of<cf.CachedFavorites>(context!, listen: false)
  //     //           .postIds
  //     //           .contains(pId)) {
  //     //     sbs += " $pId Cached";
  //     //   }
  //     // });
  //     if (context?.mounted ?? false) {
  //       ScaffoldMessenger.of(context!)
  //         ..hideCurrentSnackBar()
  //         ..showSnackBar(
  //           SnackBar(
  //             content: Text(sbs),
  //             action: SnackBarAction(
  //               label: "Undo",
  //               onPressed: () async {
  //                 E621.sendAddFavoriteRequestBatch(
  //                   pIds,
  //                   username: E621AccessData.fallback?.username,
  //                   apiKey: E621AccessData.fallback?.apiKey,
  //                   onComplete: (rs) {
  //                     if (context.mounted) {
  //                       ScaffoldMessenger.of(context)
  //                         ..hideCurrentSnackBar()
  //                         ..showSnackBar(
  //                           SnackBar(
  //                             content: Text(
  //                               "${rs.where((e) => e.statusCodeInfo.isSuccessful).length}"
  //                               "/${rs.length} posts added to favorites!",
  //                             ),
  //                           ),
  //                         );
  //                     }
  //                   },
  //                 );
  //               },
  //             ),
  //           ),
  //         );
  //     }
  //   },
  // );
}

Future< /* Iterable<E6PostResponse> */ void> removeFromFavoritesWithIds({
  BuildContext? context,
  required final Iterable<int> postIds,
}) {
  var str = "Removing ${postIds.length} posts from favorites...";
  _logger.finer(str);
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(str));
  }
  return E621.sendDeleteFavoriteRequestBatch(
    postIds,
    username: E621AccessData.fallback?.username,
    apiKey: E621AccessData.fallback?.apiKey,
    onComplete: (responses) {
      var total = responses.length;
      responses.removeWhere(
        (element) => element.statusCodeInfo.isSuccessful,
      );
      var sbs = "${total - responses.length}/"
          "$total posts removed favorites!";
      responses.where((r) => r.statusCode == 422).forEach((r) async {
        var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
        if ((context?.mounted ?? false) &&
            Provider.of<cf.CachedFavorites>(context!, listen: false)
                .postIds
                .contains(pId)) {
          sbs += " $pId Cached";
        }
      });
      if (context?.mounted ?? false) {
        util.showUserMessage(
          context: context!,
          content: Text(sbs),
          action: (
            "Undo",
            () async {
              E621.sendAddFavoriteRequestBatch(
                postIds,
                username: E621AccessData.fallback?.username,
                apiKey: E621AccessData.fallback?.apiKey,
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
        content: WSearchSet(
          initialLimit: 10,
          initialPage: null,
          initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
              E621AccessData.fallbackForced?.username,
          initialSearchOrder: e621.SetOrder.updatedAt,
          initialSearchName: null,
          initialSearchShortname: null,
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => posts.reduceUntilTrue(
              (accumulator, elem, index, list) => set.postIds.contains(elem.id)
                  ? (true, true)
                  : (accumulator, false),
              false),
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
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.initRemoveFromSetRequest(
          v.id,
          posts.map((e) => e.id).toList(),
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

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
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
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
        content: WSearchSet(
          initialLimit: 10,
          initialPage: null,
          initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
              E621AccessData.fallbackForced?.username,
          initialSearchOrder: e621.SetOrder.updatedAt,
          initialSearchName: null,
          initialSearchShortname: null,
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => posts.reduceUntilTrue(
              (accumulator, elem, index, list) => !set.postIds.contains(elem.id)
                  ? (true, true)
                  : (accumulator, false),
              false),
          showCreateSetButton: true,
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
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.initAddToSetRequest(
          v.id,
          posts.map((e) => e.id).toList(),
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

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
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
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
        content: WSearchSet(
          initialLimit: 10,
          initialPage: null,
          initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
              E621AccessData.fallbackForced?.username,
          initialSearchOrder: e621.SetOrder.updatedAt,
          initialSearchName: null,
          initialSearchShortname: null,
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => postIds.reduceUntilTrue(
              (accumulator, elem, index, list) => set.postIds.contains(elem)
                  ? (true, true)
                  : (accumulator, false),
              false),
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
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.initRemoveFromSetRequest(
          v.id,
          postIds,
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

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
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
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
        content: WSearchSet(
          initialLimit: 10,
          initialPage: null,
          initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
              E621AccessData.fallbackForced?.username,
          initialSearchOrder: e621.SetOrder.updatedAt,
          initialSearchName: null,
          initialSearchShortname: null,
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => postIds.reduceUntilTrue(
              (accumulator, elem, index, list) => !set.postIds.contains(elem)
                  ? (true, true)
                  : (accumulator, false),
              false),
          showCreateSetButton: true,
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
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.initAddToSetRequest(
          v.id,
          postIds,
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

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
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
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
// #endregion SetMulti

// #region SetSingle
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
        content: WSearchSet(
          initialLimit: 10,
          initialPage: null,
          initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
              E621AccessData.fallbackForced?.username,
          initialSearchOrder: e621.SetOrder.updatedAt,
          initialSearchName: null,
          initialSearchShortname: null,
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => set.postIds.contains(post.id),
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
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.initRemoveFromSetRequest(
          v.id,
          [post.id],
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

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
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
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
        content: WSearchSet(
          initialLimit: 10,
          initialPage: null,
          initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
              E621AccessData.fallbackForced?.username,
          initialSearchOrder: e621.SetOrder.updatedAt,
          initialSearchName: null,
          initialSearchShortname: null,
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => !set.postIds.contains(post.id),
          showCreateSetButton: true,
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
    var res = await E621
        .sendRequest(e621.initAddToSetRequest(
          v.id,
          [post.id],
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

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
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
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
        content: WSearchSet(
          initialLimit: 10,
          initialPage: null,
          initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
              E621AccessData.fallbackForced?.username,
          initialSearchOrder: e621.SetOrder.updatedAt,
          initialSearchName: null,
          initialSearchShortname: null,
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => set.postIds.contains(postId),
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
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.initRemoveFromSetRequest(
          v.id,
          [postId],
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

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
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
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
        content: WSearchSet(
          initialLimit: 10,
          initialPage: null,
          initialSearchCreatorName: E621.loggedInUser.$Safe?.name ??
              E621AccessData.fallbackForced?.username,
          initialSearchOrder: e621.SetOrder.updatedAt,
          initialSearchName: null,
          initialSearchShortname: null,
          onSelected: (e621.PostSet set) => Navigator.pop(context, set),
          filterResults: (set) => !set.postIds.contains(postId),
          showCreateSetButton: true,
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
    var res = await E621
        .sendRequest(e621.initAddToSetRequest(
          v.id,
          [postId],
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

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
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: Text("Set ${v!.id}: ${v.shortname}"),
                      ),
                      body: WPostSearchResults.directResultFromSearch(
                        searchString,
                      ),
                    ),
                  ),
                ),
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(message));
  }
  return posts.map((post) {
    lm.logRequest(
        e621.initVotePostRequest(
          postId: post.id,
          score: isUpvote ? 1 : -1,
          noUnvote: noUnvote,
          credentials: E621AccessData.fallback?.cred,
        ),
        _logger,
        lm.LogLevel.INFO);
    return e621
        .sendRequest(
      e621.initVotePostRequest(
        postId: post.id,
        score: isUpvote ? 1 : -1,
        noUnvote: noUnvote,
        credentials: E621AccessData.fallback?.cred,
      ),
    )
        .then(
      (v) {
        _logger.info("${post.id} vote done");
        lm.logResponseSmart(v, _logger, overrideLevel: lm.LogLevel.INFO);
        // TODO: response
        /* if (context?.mounted ?? false) {
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(message));
  }
  return postIds
      .map((postId) => e621
              .sendRequest(
            e621.initVotePostRequest(
              postId: postId,
              score: isUpvote ? 1 : -1,
              noUnvote: noUnvote,
              credentials: E621AccessData.fallback?.cred,
            ),
          )
              .then(
            (v) {
              lm.logResponseSmart(v, _logger);
              // TODO: Response
              // if (context?.mounted ?? false) {
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(message));
  }
  return e621
      .sendRequest(
    e621.initVotePostRequest(
      postId: post.id,
      score: isUpvote ? 1 : -1,
      noUnvote: noUnvote,
      credentials: E621AccessData.fallback?.cred,
    ),
  )
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      if (context?.mounted ?? false) {
        if (!v.statusCodeInfo.isSuccessful) {
          util.showUserMessage(
              context: context!,
              content: Text("${v.statusCode}: ${v.reasonPhrase}"));
          return post;
        } else {
          final update = e621.UpdatedScore.fromJsonRaw(v.body);
          util.showUserMessage(
              context: context!,
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
  if (context?.mounted ?? false) {
    util.showUserMessage(
      context: context!,
      content: Text("${isUpvote ? "Upvoting" : "Downvoting"} $postId..."),
    );
  }
  return e621
      .sendRequest(
    e621.initVotePostRequest(
      postId: postId,
      score: isUpvote ? 1 : -1,
      noUnvote: noUnvote,
      credentials: E621AccessData.fallback?.cred,
    ),
  )
      .then(
    (v) {
      lm.logResponseSmart(v, _logger);
      if (context?.mounted ?? false) {
        if (!v.statusCodeInfo.isSuccessful) {
          util.showUserMessage(
            context: context!,
            content: Text("${v.statusCode}: ${v.reasonPhrase}"),
          );
          return null;
        } else {
          final update = e621.UpdatedScore.fromJsonRaw(v.body);
          util.showUserMessage(
            context: context!,
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
      name: "[${post.id}] ${post.file.url.split(RegExp(r"\\|/"))}",
      link: saver.LinkDetails(
        link: post.file.url,
        headers: (E621AccessData.fallbackForced?.cred ?? e621.activeCredentials)
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(out));
  }
  return downloadPostRoot(post).then((v) {
    final out = "Downloaded $id to ${v ?? "an unknown path"}";
    _logger.info(out);
    if (context?.mounted ?? false) {
      util.showUserMessage(
        context: context!,
        content: Text(out),
      );
    }
    return v ?? "";
  }).onError((e, s) {
    final out = "Failed to download $id";
    _logger.severe(out, e, s);
    if (context?.mounted ?? false) {
      util.showUserMessage(
        context: context!,
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
        .sendRequest(e621.initGetPostRequest(postId))
        .then((r) => downloadPostWithPost(
              context: context,
              post: E6PostResponse.fromRawJson(r.body),
            ))
        .onError((e, s) {
      final out = "Failed to download $postId";
      _logger.severe(out, e, s);
      if (context?.mounted ?? false) {
        util.showUserMessage(
          context: context!,
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(out));
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
    if (context?.mounted ?? false) {
      util.showUserMessage(
        context: context!,
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
            .sendRequest(e621.initGetPostRequest(postId))
            .then((r) => E6PostResponse.fromRawJson(r.body))
            .onError((e, s) {
          final out = "Failed to get $postId";
          _logger.severe(out, e, s);
          // if (context?.mounted ?? false) {
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
      if (context?.mounted ?? false) {
        util.showUserMessage(
          context: context!,
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(out));
  }
  return downloadDescriptionRoot(post).then((v) {
    final out = "Downloaded $id to ${v ?? "an unknown path"}";
    _logger.info(out);
    if (context?.mounted ?? false) {
      util.showUserMessage(
        context: context!,
        content: Text(out),
      );
    }
    return v ?? "";
  }).onError((e, s) {
    final out = "Failed to download $id";
    _logger.severe(out, e, s);
    if (context?.mounted ?? false) {
      util.showUserMessage(
        context: context!,
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
        .sendRequest(e621.initGetPostRequest(postId))
        .then((r) => downloadDescriptionWithPost(
              context: context,
              post: E6PostResponse.fromRawJson(r.body),
            ))
        .onError((e, s) {
      final out = "Failed to download $postId";
      _logger.severe(out, e, s);
      if (context?.mounted ?? false) {
        util.showUserMessage(
          context: context!,
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
  if (context?.mounted ?? false) {
    util.showUserMessage(context: context!, content: Text(out));
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
    if (context?.mounted ?? false) {
      util.showUserMessage(
        context: context!,
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
            .sendRequest(e621.initGetPostRequest(postId))
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
      if (context?.mounted ?? false) {
        util.showUserMessage(
          context: context!,
          content: Text(out),
        );
      }
      return v;
    });

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

// typedef E6BatchActionEvent = ({int currentProgress, int totalProgress, String })
class WE6BatchAction extends StatefulWidget {
  final StreamSubscription<E6BatchActionEvent> stream;
  const WE6BatchAction({
    super.key,
    required this.stream,
  });

  @override
  State<WE6BatchAction> createState() => _WE6BatchActionState();
}

class _WE6BatchActionState extends State<WE6BatchAction> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

// TODO: IMPLEMENT AND TEST BATCH ACTIONS
class E6Actions extends ChangeNotifier {
  static final batchActions =
      ListNotifier<Stream<E6BatchActionEvent>>.empty(true);
}

class E6BatchActionEvent<T> {
  final num currentProgress;
  final String? message;
  final String Function(num currentProgress, num totalProgress)? messageBuilder;
  final num totalProgress;
  final Object? error;
  final StackTrace? stackTrace;
  final String? errorMessage;
  final T? result;
  final VoidCallback? cancel;
  final (String label, VoidCallback)? sideAction;
  bool get hasError => error != null;

  const E6BatchActionEvent({
    required this.currentProgress,
    required this.message,
    this.totalProgress = 1,
    this.error,
    this.stackTrace,
    this.errorMessage,
    this.result,
    this.cancel,
    this.sideAction,
  }) : messageBuilder = null;
  const E6BatchActionEvent.builder({
    required this.currentProgress,
    required this.messageBuilder,
    this.totalProgress = 1,
    this.error,
    this.stackTrace,
    this.errorMessage,
    this.result,
    this.cancel,
    this.sideAction,
  }) : message = null;
  const E6BatchActionEvent.req({
    required this.messageBuilder,
    required this.currentProgress,
    required this.message,
    required this.totalProgress,
    required this.error,
    required this.stackTrace,
    required this.errorMessage,
    required this.result,
    required this.cancel,
    required this.sideAction,
  });
}
