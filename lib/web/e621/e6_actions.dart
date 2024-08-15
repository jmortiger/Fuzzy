import 'package:flutter/material.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:provider/provider.dart';

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
VoidCallback makeUpvotePostWithPost({
  BuildContext? context,
  required E6PostResponse post,
  bool updatePost = true,
}) =>
    () {
      print("Upvoting ${post.id}...");
      if (context?.mounted ?? false) {
        ScaffoldMessenger.of(context!).showSnackBar(
          SnackBar(content: Text("Upvoting ${post.id}...")),
        );
      }
      e621.Api.sendRequest(
        e621.Api.initVotePostRequest(
          postId: post.id,
          score: 1,
          credentials: E621AccessData.fallback?.cred,
        ),
      ).then(
        (v) {
          print(v.body);
          if (context?.mounted ?? false) {
            ScaffoldMessenger.of(context!).showSnackBar(
              SnackBar(
                content: Text("${v.statusCode}: ${v.reasonPhrase}"),
              ),
            );
          }
        },
      );
    };
VoidCallback makeUpvotePostWithId({
  BuildContext? context,
  required int postId,
}) =>
    () {
      print("Upvoting $postId...");
      if (context?.mounted ?? false) {
        ScaffoldMessenger.of(context!).showSnackBar(
          SnackBar(content: Text("Upvoting $postId...")),
        );
      }
      e621.Api.sendRequest(
        e621.Api.initVotePostRequest(
          postId: postId,
          score: 1,
          credentials: E621AccessData.fallback?.cred,
        ),
      ).then(
        (v) {
          print(v.body);
          if (context?.mounted ?? false) {
            ScaffoldMessenger.of(context!).showSnackBar(
              SnackBar(
                content: Text("${v.statusCode}: ${v.reasonPhrase}"),
              ),
            );
          }
        },
      );
    };
// #endregion Post Actions