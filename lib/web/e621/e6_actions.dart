import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

lm.Printer get _print => lRecord.print;
lm.FileLogger get _logger => lRecord.logger;
// ignore: unnecessary_late
late final lRecord = lm.generateLogger("E6Actions");
// #endregion Logger

// #region Post Actions
VoidCallback makeClearSelectionsWithContext(
  BuildContext context, {
  bool listen = false,
}) =>
    Provider.of<SearchResultsNotifier>(
      context,
      listen: listen,
    ).clearSelections;
VoidCallback makeClearSelections({
  BuildContext? context,
  VoidCallback? clearSelection,
  bool listen = false,
}) =>
    clearSelection ??
    Provider.of<SearchResultsNotifier>(
      context ??
          (throw ArgumentError.value(
              "Either context or clearSelection must be non-null.")),
      listen: listen,
    ).clearSelections;
// #region Votes
VoidCallback makeUpvotePostWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
  bool noUnvote = true,
}) =>
    () => voteOnPostWithPost(
          post: post,
          context: context,
          isUpvote: true,
          noUnvote: noUnvote,
          updatePost: updatePost,
        );
VoidCallback makeUpvotePostWithId({
  BuildContext? context,
  required int postId,
  bool noUnvote = true,
}) =>
    () => voteOnPostWithId(
          context: context,
          noUnvote: noUnvote,
          // oldScore: oldScore,
          isUpvote: true,
          postId: postId,
        );
VoidCallback makeVoteOnPostWithPost({
  BuildContext? context,
  required E6PostResponse post,
  required bool isUpvote,
  bool updatePost = true,
  bool noUnvote = true,
}) =>
    () => voteOnPostWithPost(
          post: post,
          context: context,
          isUpvote: isUpvote,
          noUnvote: noUnvote,
          updatePost: updatePost,
        );
VoidCallback makeVoteOnPostWithId({
  BuildContext? context,
  required int postId,
  bool noUnvote = true,
  required bool isUpvote,
}) =>
    () => voteOnPostWithId(
          context: context,
          noUnvote: noUnvote,
          // oldScore: oldScore,
          isUpvote: isUpvote,
          postId: postId,
        );
// #endregion Votes
VoidCallback makeAddPostToFavoritesWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
}) =>
    () => addPostToFavoritesWithPost(
          post: post,
          context: context,
          updatePost: updatePost,
        );
VoidCallback makeRemovePostFromFavoritesWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
}) =>
    () => removePostFromFavoritesWithPost(
          post: post,
          context: context,
          updatePost: updatePost,
        );
VoidCallback makeAddPostToFavoritesWithId({
  BuildContext? context,
  required int postId,
}) =>
    () => addPostToFavoritesWithId(
          postId: postId,
          context: context,
        );
VoidCallback makeRemovePostFromFavoritesWithId({
  BuildContext? context,
  required int postId,
}) =>
    () => removePostFromFavoritesWithId(
          postId: postId,
          context: context,
        );
// #endregion Post Actions
// #region Functions

// #region Favorites
Future<E6PostResponse> addPostToFavoritesWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
}) {
  _logger.finer("Adding ${post.id} to favorites...");
  if (context?.mounted ?? false) {
    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(content: Text("Adding ${post.id} to favorites...")),
    );
  }
  return E621
      .sendRequest(
        E621.initAddFavoriteRequest(
          post.id,
          username: E621AccessData.fallback?.username,
          apiKey: E621AccessData.fallback?.apiKey,
        ),
      )
      .toResponse()
      .then(
    (v) {
      util.logResponse(
          v,
          _logger,
          v.statusCodeInfo.isSuccessful
              ? lm.LogLevel.FINEST
              : lm.LogLevel.SEVERE);
      E6PostResponse postRet = v.statusCodeInfo.isSuccessful
          ? E6PostResponse.fromRawJson(v.body)
          : post;
      if (context?.mounted ?? false) {
        ScaffoldMessenger.of(context!)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            !v.statusCodeInfo.isSuccessful
                ? SnackBar(
                    content: Text("${v.statusCode}: ${v.reasonPhrase}"),
                  )
                : SnackBar(
                    content: Text("${post.id} added to favorites"),
                    action: SnackBarAction(
                      label: "Undo",
                      onPressed: () => removePostFromFavoritesWithPost(
                        post: post,
                        updatePost: updatePost,
                        context: context,
                      ),
                    ),
                  ),
          );
      }
      return updatePost && post is E6PostMutable
          ? (post..overwriteFrom(postRet))
          : postRet;
    },
  );
}

Future<E6PostResponse> removePostFromFavoritesWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
}) {
  _logger.finer("Removing ${post.id} from favorites...");
  if (context?.mounted ?? false) {
    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(content: Text("Removing ${post.id} from favorites...")),
    );
  }
  return E621
      .sendRequest(
        E621.initDeleteFavoriteRequest(
          post.id,
          username: E621AccessData.fallback?.username,
          apiKey: E621AccessData.fallback?.apiKey,
        ),
      )
      .toResponse()
      .then(
    (v) {
      util.logResponse(
          v,
          _logger,
          v.statusCodeInfo.isSuccessful
              ? lm.LogLevel.FINEST
              : lm.LogLevel.SEVERE);
      E6PostResponse postRet = v.statusCodeInfo.isSuccessful
          ? E6PostResponse.fromRawJson(v.body)
          : post;
      if (context?.mounted ?? false) {
        ScaffoldMessenger.of(context!)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            !v.statusCodeInfo.isSuccessful
                ? SnackBar(
                    content: Text("${v.statusCode}: ${v.reasonPhrase}"),
                  )
                : SnackBar(
                    content: Text("${post.id} removed from favorites"),
                    action: SnackBarAction(
                      label: "Undo",
                      onPressed: () => addPostToFavoritesWithPost(
                        post: post,
                        updatePost: updatePost,
                        context: context,
                      ),
                    ),
                  ),
          );
      }
      return updatePost && post is E6PostMutable
          ? (post..overwriteFrom(postRet))
          : postRet;
    },
  );
}

Future<E6PostResponse?> addPostToFavoritesWithId({
  BuildContext? context,
  required int postId,
}) {
  _logger.finer("Adding $postId to favorites...");
  if (context?.mounted ?? false) {
    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(content: Text("Adding $postId to favorites...")),
    );
  }
  return E621
      .sendRequest(
        E621.initAddFavoriteRequest(
          postId,
          username: E621AccessData.fallback?.username,
          apiKey: E621AccessData.fallback?.apiKey,
        ),
      )
      .toResponse()
      .then(
    (v) {
      util.logResponse(
          v,
          _logger,
          v.statusCodeInfo.isSuccessful
              ? lm.LogLevel.FINEST
              : lm.LogLevel.SEVERE);
      final postRet = v.statusCodeInfo.isSuccessful
          ? E6PostResponse.fromRawJson(v.body)
          : null;
      if (context?.mounted ?? false) {
        ScaffoldMessenger.of(context!)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            !v.statusCodeInfo.isSuccessful
                ? SnackBar(content: Text("${v.statusCode}: ${v.reasonPhrase}"))
                : SnackBar(
                    content: Text("$postId added to favorites"),
                    action: SnackBarAction(
                      label: "Undo",
                      onPressed: () => removePostFromFavoritesWithId(
                        postId: postId,
                        context: context,
                      ),
                    ),
                  ),
          );
      }
      return postRet;
    },
  );
}

Future<E6PostResponse?> removePostFromFavoritesWithId({
  BuildContext? context,
  required int postId,
  bool updatePost = true,
}) {
  _logger.finer("Removing $postId from favorites...");
  if (context?.mounted ?? false) {
    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(content: Text("Removing $postId from favorites...")),
    );
  }
  return E621
      .sendRequest(
        E621.initDeleteFavoriteRequest(
          postId,
          username: E621AccessData.fallback?.username,
          apiKey: E621AccessData.fallback?.apiKey,
        ),
      )
      .toResponse()
      .then(
    (v) {
      util.logResponse(
          v,
          _logger,
          v.statusCodeInfo.isSuccessful
              ? lm.LogLevel.FINEST
              : lm.LogLevel.SEVERE);
      final postRet = v.statusCodeInfo.isSuccessful
          ? E6PostResponse.fromRawJson(v.body)
          : null;
      if (context?.mounted ?? false) {
        ScaffoldMessenger.of(context!)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            !v.statusCodeInfo.isSuccessful
                ? SnackBar(
                    content: Text("${v.statusCode}: ${v.reasonPhrase}"),
                  )
                : SnackBar(
                    content: Text("$postId removed from favorites"),
                    action: SnackBarAction(
                      label: "Undo",
                      onPressed: () => addPostToFavoritesWithId(
                        postId: postId,
                        context: context,
                      ),
                    ),
                  ),
          );
      }
      return postRet;
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text("Removing ${posts.length}"
              " posts from a set, selecting set"),
        ),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text("Removing ${posts.length}"
                " posts from set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})"),
          ),
        );
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.Api.initRemoveFromSetRequest(
          v.id,
          posts.map((e) => e.id).toList(),
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

    util.logResponse(res, _logger, lm.LogLevel.INFO);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${formerLength - v.postCount}/${posts.length} posts successfully removed from set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
      }
    } else {
      final out =
          "${res.statusCode}: Failed to remove posts from set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(out)),
        );
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text("Adding ${posts.length}"
              " posts to a set, selecting set"),
        ),
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
        " posts to set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})");
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text("Adding ${posts.length}"
                " posts to set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})"),
          ),
        );
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.Api.initAddToSetRequest(
          v.id,
          posts.map((e) => e.id).toList(),
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

    util.logResponse(res, _logger, lm.LogLevel.INFO);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${v.postCount - formerLength} ${posts.length} posts successfully added to set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to add posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(out)),
        );
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text("Removing ${postIds.length}"
              " posts from a set, selecting set"),
        ),
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
        " posts from set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})");
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text("Removing ${postIds.length}"
                " posts from set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})"),
          ),
        );
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.Api.initRemoveFromSetRequest(
          v.id,
          postIds,
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

    util.logResponse(res, _logger, lm.LogLevel.INFO);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${formerLength - v.postCount}/${postIds.length} posts successfully removed from set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to remove posts from set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(out)),
        );
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text("Adding ${postIds.length}"
              " posts to a set, selecting set"),
        ),
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
        " posts to set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})");
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text("Adding ${postIds.length}"
                " posts to set ${v.id} (${v.shortname}, length ${v.postCount}, length ${v.postCount})"),
          ),
        );
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.Api.initAddToSetRequest(
          v.id,
          postIds,
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

    util.logResponse(res, _logger, lm.LogLevel.INFO);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${v.postCount - formerLength} ${postIds.length} posts successfully added to set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to add posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(out)),
        );
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(logString)));
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(logString)));
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.Api.initRemoveFromSetRequest(
          v.id,
          [post.id],
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

    util.logResponse(res, _logger, lm.LogLevel.INFO);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out = "${post.id} successfully removed from set ${v.id} "
          "(${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
      }
    } else {
      final out =
          "${res.statusCode}: Failed to remove post ${post.id} from set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(out)),
        );
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(logString)));
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(logString)));
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.Api.initAddToSetRequest(
          v.id,
          [post.id],
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

    util.logResponse(res, _logger, lm.LogLevel.INFO);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out =
          "${post.id} successfully added to set ${v.id} (${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to add posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(out)),
        );
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(logString)));
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(logString)));
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.Api.initRemoveFromSetRequest(
          v.id,
          [postId],
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

    util.logResponse(res, _logger, lm.LogLevel.INFO);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out = "$postId successfully removed from set ${v.id} "
          "(${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to remove posts from set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(out)),
        );
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(logString)));
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(logString)));
    }
    final searchString =
        "set:${SearchView.i.preferSetShortname ? v.shortname : v.id}";
    var res = await E621
        .sendRequest(e621.Api.initAddToSetRequest(
          v.id,
          [postId],
          credentials: E621AccessData.fallback?.cred,
        ))
        .toResponse();

    util.logResponse(res, _logger, lm.LogLevel.INFO);
    // if (res.statusCode == 201) {
    if (res.statusCodeInfo.isSuccessful) {
      final formerLength = v.postCount;
      v = e621.PostSet.fromRawJson(res.body);
      // assert(posts.length == formerLength - v.postCount);
      final out = "$postId successfully added to set ${v.id} "
          "(${v.shortname}, length $formerLength => ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
      }
      return v;
    } else {
      final out =
          "${res.statusCode}: Failed to add posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
      _logger.finer(out);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(out),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
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
            ),
          );
        return null;
      }
    }
  } else {
    const out = "No Set Selected, canceling.";
    _logger.finer(out);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(out)),
        );
    }
  }
  return v;
}

// #endregion SetSingle
Future<E6PostResponse> voteOnPostWithPost({
  BuildContext? context,
  required bool isUpvote,
  bool noUnvote = true,
  required E6PostResponse post,
  bool updatePost = true,
}) {
  _logger.finer("${isUpvote ? "Upvoting" : "Downvoting"} ${post.id}...");
  if (context?.mounted ?? false) {
    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(
        content: Text("${isUpvote ? "Upvoting" : "Downvoting"} ${post.id}..."),
      ),
    );
  }
  return e621.Api.sendRequest(
    e621.Api.initVotePostRequest(
      postId: post.id,
      score: isUpvote ? 1 : -1,
      noUnvote: noUnvote,
      credentials: E621AccessData.fallback?.cred,
    ),
  ).then(
    (v) {
      util.logResponse(
          v,
          _logger,
          v.statusCodeInfo.isSuccessful
              ? lm.LogLevel.FINEST
              : lm.LogLevel.SEVERE);
      if (context?.mounted ?? false) {
        if (!v.statusCodeInfo.isSuccessful) {
          ScaffoldMessenger.of(context!)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text("${v.statusCode}: ${v.reasonPhrase}"),
              ),
            );
          return post;
        } else {
          final update = e621.UpdatedScore.fromJsonRaw(v.body);
          ScaffoldMessenger.of(context!)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(createPostVoteString(
                  postId: post.id,
                  score: update,
                  oldScore: post.score,
                )),
              ),
            );
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
    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(
          content: Text("${isUpvote ? "Upvoting" : "Downvoting"} $postId...")),
    );
  }
  return e621.Api.sendRequest(
    e621.Api.initVotePostRequest(
      postId: postId,
      score: isUpvote ? 1 : -1,
      noUnvote: noUnvote,
      credentials: E621AccessData.fallback?.cred,
    ),
  ).then(
    (v) {
      util.logResponse(
          v,
          _logger,
          v.statusCodeInfo.isSuccessful
              ? lm.LogLevel.FINEST
              : lm.LogLevel.SEVERE);
      if (context?.mounted ?? false) {
        if (!v.statusCodeInfo.isSuccessful) {
          ScaffoldMessenger.of(context!)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text("${v.statusCode}: ${v.reasonPhrase}"),
              ),
            );
          return null;
        } else {
          final update = e621.UpdatedScore.fromJsonRaw(v.body);
          ScaffoldMessenger.of(context!)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(createPostVoteString(
                  postId: postId,
                  score: update,
                  oldScore: oldScore,
                )),
              ),
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

String createPostVoteString({
  required int postId,
  required e621.UpdatedScore score,
  e621.Score? oldScore,
}) {
  if (score.ourScore == 0) {
    return "Removed ${score.total == (oldScore?.total ?? score.total) + 1 ? "up" : score.total == (oldScore?.total ?? score.total) - 1 ? "down" : ""}vote on $postId";
  }
  final out = switch (score.ourScore) {
    > 0 => "upvote",
    < 0 => "downvote",
    _ => throw UnimplementedError(),
  };
  return oldScore != null && score.total == oldScore.total
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
// #endregion Functions
