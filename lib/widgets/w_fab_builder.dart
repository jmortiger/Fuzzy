import 'package:flutter/material.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/pages/edit_post_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/e6_actions.dart' as actions;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import 'package:fuzzy/log_management.dart' as lm;

import '../web/e621/e621_access_data.dart';

// #region Logger
late final lRecord = lm.generateLogger("WFabBuilder");
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;
// #endregion Logger

class WFabBuilder extends StatelessWidget {
  final List<ActionButton>? customActions;
  final List<E6PostResponse>? posts;
  final E6PostResponse? post;
  bool get isSinglePost => post != null;
  bool get isMultiplePosts => posts != null;
  final void Function()? onClearSelections;
  final bool Function(int)? toggleSelectionCallback;
  final bool Function(int)? isPostSelected;

  const WFabBuilder.singlePost({
    super.key,
    required E6PostResponse this.post,
    this.onClearSelections,
    this.toggleSelectionCallback,
    this.isPostSelected,
    this.customActions,
  }) : posts = null;
  const WFabBuilder.multiplePosts({
    super.key,
    required List<E6PostResponse> this.posts,
    this.onClearSelections,
    this.toggleSelectionCallback,
    this.isPostSelected,
    this.customActions,
  }) : post = null;
  static ActionButton getClearSelectionButton(
    BuildContext context, [
    void Function()? clearSelection,
  ]) =>
      ActionButton(
        icon: const Icon(Icons.clear),
        tooltip: "Clear Selections",
        onPressed: clearSelection ??
            // context.watch<SearchResultsNotifier>().clearSelections,
            Provider.of<SearchResultsNotifier>(
              context,
              listen: false,
            ).clearSelections,
      );

  static ActionButton getSinglePostUpvoteAction(
    BuildContext context,
    E6PostResponse post, {
    bool noUnvote = true,
  }) {
    return ActionButton(
      icon: const Icon(Icons.arrow_upward),
      tooltip: "Upvote",
      onPressed: actions.makeVoteOnPostWithPost(
        context: context,
        post: post,
        isUpvote: true,
        noUnvote: noUnvote,
        updatePost: post is E6PostMutable,
      ),
    );
  }

  static ActionButton getSinglePostDownvoteAction(
    BuildContext context,
    E6PostResponse post,
  ) {
    return ActionButton(
      icon: const Icon(Icons.arrow_downward),
      tooltip: "Downvote",
      onPressed: actions.makeVoteOnPostWithPost(
        context: context,
        post: post,
        isUpvote: false,
        noUnvote: true,
        updatePost: post is E6PostMutable,
      ),
    );
  }

  static ActionButton getSinglePostAddFavAction(
    BuildContext context,
    E6PostResponse post, {
    double elevation = 4,
  }) {
    return ActionButton(
      icon: const Icon(Icons.favorite),
      tooltip: "Add to favorites",
      elevation: elevation,
      onPressed: actions.makeAddPostToFavoritesWithPost(
        post: post,
        context: context,
        updatePost: post is E6PostMutable,
      ),
    );
  }

  static ActionButton getMultiplePostsAddFavAction(
    BuildContext context,
    List<E6PostResponse> posts,
  ) {
    return ActionButton(
      icon: const Icon(Icons.favorite),
      tooltip: "Add selected to favorites",
      onPressed: () async {
        logger.finer("Adding ${posts.length} posts to favorites...");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Adding ${posts.length} posts to favorites...")),
        );
        E621.sendAddFavoriteRequestBatch(
          posts.map((e) => e.id),
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
              if (context.mounted &&
                  Provider.of<CachedFavorites>(context, listen: false)
                      .postIds
                      .contains(pId)) {
                sbs += " $pId Cached";
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(sbs),
                action: SnackBarAction(
                  label: "Undo",
                  onPressed: () async {
                    E621.sendDeleteFavoriteRequestBatch(
                      responses.map((e) => int.parse(
                            e.request!.url.queryParameters["post_id"]!,
                          )),
                      username: E621AccessData.fallback?.username,
                      apiKey: E621AccessData.fallback?.apiKey,
                      onComplete: (responses) =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts removed from favorites!"),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  static ActionButton getMultiplePostsAddToSetAction(
    BuildContext context,
    List<E6PostResponse> posts,
  ) {
    return ActionButton(
      icon: const Icon(Icons.add),
      tooltip: "Add selected to set",
      onPressed: () => actions.addToSetWithPosts(
        context: context,
        posts: posts,
      ),
    );
  }

  static ActionButton getSinglePostAddToSetAction(
    BuildContext context,
    E6PostResponse postListing,
  ) {
    return ActionButton(
      icon: const Icon(Icons.add),
      tooltip: "Add to set",
      onPressed: () async {
        logger.finer("Adding ${postListing.id} to a set");
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
                showCreateSetButton: true,
              ),
              // scrollable: true,
            );
          },
        );
        if (v != null) {
          logger.finer(
              "Adding ${postListing.id} to set ${v.id} (${v.shortname}, length ${v.postCount})");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Adding ${postListing.id}"
                    " to set ${v.id} (${v.shortname}, length ${v.postCount})"),
              ),
            );
          }
          var res = await E621
              .sendRequest(e621.Api.initAddToSetRequest(
                v.id,
                [postListing.id],
                credentials: E621AccessData.fallback?.cred,
              ))
              .toResponse();
          if (res.statusCode == 201) {
            logger.finer(
                "${postListing.id} successfully added to set ${v.id} (${v.shortname}, length ${v.postCount})");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      "${postListing.id} successfully added to set ${v.id} (${v.shortname}, length ${v.postCount})"),
                  action: SnackBarAction(
                    label: "See Set",
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(),
                          body: WPostSearchResults.directResultFromSearch(
                            "set:${v.shortname}",
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
          return;
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No Set Selected, canceling.")),
          );
          return;
        } else {
          return;
        }
      },
    );
  }

  static ActionButton getMultiplePostsRemoveFromSetAction(
      BuildContext context, List<E6PostResponse> posts) {
    return ActionButton(
      icon: const Icon(Icons.delete),
      tooltip: "Remove selected from set",
      onPressed: () => actions.removeFromSetWithPosts(
        context: context,
        posts: posts,
      ),
    );
  }

  static ActionButton getSinglePostRemoveFromSetAction(
      BuildContext context, E6PostResponse post) {
    return ActionButton(
      icon: const Icon(Icons.delete),
      tooltip: "Remove selected from set",
      onPressed: () async {
        logger.finer("Removing ${post.id} from a set, selecting set");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Removing ${post.id} from a set, selecting set"),
          ),
        );
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
          logger.finer("Removing ${post.id}"
              " from set ${v.id} (${v.shortname}, length ${v.postCount})");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Removing ${post.id}"
                    " from set ${v.id} (${v.shortname}, length ${v.postCount})"),
              ),
            );
          }
          var res = await E621
              .sendRequest(e621.Api.initRemoveFromSetRequest(
                v.id,
                [post.id],
                credentials: E621AccessData.fallback?.cred,
              ))
              .toResponse();

          util.logResponse(res, logger, lm.LogLevel.INFO);
          // if (res.statusCode == 201) {
          if (res.statusCodeInfo.isSuccessful) {
            final out =
                "${res.statusCode}: Post successfully removed from set ${v.id} (${v.shortname}, length ${v.postCount})";
            logger.finer(out);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(out),
                  action: SnackBarAction(
                    label: "See Set",
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: Text("Set ${v.id}: ${v.shortname}"),
                          ),
                          body: WPostSearchResults.directResultFromSearch(
                            "set:${v.shortname}",
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
                "${res.statusCode}: Failed to remove posts to set ${v.id} (${v.shortname}, length ${v.postCount})";
            logger.finer(out);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
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
                            "set:${v.shortname}",
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
        } else {
          const out = "No Set Selected, canceling.";
          logger.finer(out);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(out)),
            );
          }
        }
      },
    );
  }

  static ActionButton getMultiplePostsRemoveFavAction(
      BuildContext context, List<E6PostResponse> posts) {
    return ActionButton(
      icon: const Icon(Icons.heart_broken_outlined),
      tooltip: "Remove selected from favorites",
      onPressed: () async {
        logger.finer("Removing ${posts.length}"
            " posts from favorites...");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Removing ${posts.length}"
                " posts from favorites..."),
          ),
        );
        var postIds = <int>[];
        E621.sendRequestBatch(
          () => posts.map(
            (e) {
              postIds.add(e.id);
              return E621.initDeleteFavoriteRequest(
                e.id,
                username: E621AccessData.fallback?.username,
                apiKey: E621AccessData.fallback?.apiKey,
              );
            },
          ),
          onError: (error, trace) {
            logger.finer(error);
          },
          onComplete: (responses) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts removed from favorites!"),
              action: SnackBarAction(
                label: "Undo",
                onPressed: () async {
                  E621.sendRequestBatch(
                    () => responses.map(
                      (e) => E621.initAddFavoriteRequest(
                        int.parse(
                          e.request!.url.queryParameters["post_id"]!,
                        ),
                        username: E621AccessData.fallback?.username,
                        apiKey: E621AccessData.fallback?.apiKey,
                      ),
                    ),
                    onComplete: (responses) {
                      responses
                          .where((r) => r.statusCode == 422)
                          .forEach((r) async {
                        var rBody = await r.stream.bytesToString();
                        E621.favFailed.invoke(
                          PostActionArgs(
                            post: posts.firstWhere(
                              (e) =>
                                  e.id ==
                                  int.parse(
                                    r.request!.url.queryParameters["post_id"]!,
                                  ),
                            ),
                            responseBody: rBody,
                            statusCode: r.statusCodeInfo,
                          ),
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "${responses.where(
                                  (e) => e.statusCodeInfo.isSuccessful,
                                ).length}/${responses.length} "
                            "posts removed from favorites!",
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  static ActionButton getSinglePostRemoveFavAction(
      BuildContext context, E6PostResponse post) {
    return ActionButton(
      icon: const Icon(Icons.heart_broken_outlined),
      tooltip: "Remove from favorites",
      onPressed: actions.makeRemovePostFromFavoritesWithPost(
        post: post,
        context: context,
        updatePost: post is E6PostMutable,
      ),
    );
  }

  static ActionButton getSinglePostEditAction(
      BuildContext context, E6PostResponse post) {
    return ActionButton(
      icon: const Icon(Icons.edit),
      tooltip: "Edit",
      onPressed: () async {
        logger.finer("Editing ${post.id}...");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text("Editing ${post.id}..."),
        //   ),
        // );
        Navigator.pushNamed(
          context,
          "${EditPostPageLoader.routeNameString}?postId=${post.id}",
          arguments: (post: post),
          // MaterialPageRoute(
          //   builder: (context) => EditPostPageLoader(postId: post.id),
          // ),
        );
        // Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => EditPostPage(post: post),
        //     ));
        //     .onError(defaultOnError)
        //     .then(
        //       (value) => ScaffoldMessenger.of(context).showSnackBar(
        //         SnackBar(
        //           content: Text(
        //             "${value.statusCode}: ${value.reasonPhrase}",
        //           ),
        //         ),
        //       ),
        //     )
        //     .onError((error, stackTrace) {
        //   logger.finer(error);
        //   throw error!;
        // });
      },
    );
  }

  static ActionButton getSinglePostToggleSelectAction(
    BuildContext context,
    E6PostResponse post, {
    String? tooltip = "Toggle selection",
    bool? isSelected,
    bool Function(int)? toggleSelection,
  }) {
    return ActionButton(
      icon: const Icon(Icons.edit),
      tooltip: tooltip ??
          (isSelected == null
              ? null
              : isSelected
                  ? "Remove from selections"
                  : "Add to selections"),
      onPressed: () {
        final p = "${post.id}: $tooltip";
        logger.finer(p);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(p),
          ),
        );
        // context.watch<SearchResultsNotifier>().togglePostSelection(
        toggleSelection?.call(post.id) ??
            Provider.of<SearchResultsNotifier>(context, listen: false)
                .togglePostSelection(
              postId: post.id,
              resolveDesync: false,
              throwOnDesync: false,
            );
      },
    );
  }

  static ActionButton getPrintSelectionsAction(
    BuildContext context,
    E6PostResponse? post,
    List<E6PostResponse>? posts,
  ) {
    return ActionButton(
      icon: const Icon(Icons.info_outline),
      tooltip: "Print Selections",
      onPressed: () async {
        logger.finer("Printing selections...");
        var s = "posts: ${posts?.fold(
          "",
          (previousValue, element) => "$previousValue, ${element.id}",
        )}";
        logger.finer(s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s),
          ),
        );
        s = "post: ${post?.id}";
        logger.finer(s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s),
          ),
        );
      },
    );
  }
  // TODO: Figure out adding posts in post view (SRN)
  @override
  Widget build(BuildContext context) {
    bool? isSelected;
    try {
      if (isSinglePost) {
        isSelected = isPostSelected?.call(post!.id) ??
            Provider.of<SearchResultsNotifier>(context, listen: false)
                .getIsPostSelected(post!.id);
      }
    } catch (e, s) {
      logger.warning("Couldn't access SearchResultsNotifier in fab"/* , e, s */);
    }
    return ExpandableFab(
      useDefaultHeroTag: false,
      distance: Platform.isDesktop ? 112 : 224,
      disabledTooltip: (isSinglePost || (isMultiplePosts && posts!.isNotEmpty))
          ? ""
          : "Long-press to select posts and perform bulk actions.",
      children: (isSinglePost ||
              (isMultiplePosts && posts!.isNotEmpty) ||
              (customActions?.isNotEmpty ?? false))
          ? [
              if (!isSinglePost)
                WFabBuilder.getClearSelectionButton(context, onClearSelections),
              if (!isSinglePost)
                WFabBuilder.getMultiplePostsAddToSetAction(context, posts!),
              if (isSinglePost)
                WFabBuilder.getSinglePostAddToSetAction(context, post!),
              if (!isSinglePost &&
                  posts!.indexWhere((p) => !p.isFavorited) != -1)
                WFabBuilder.getMultiplePostsAddFavAction(context, posts!),
              if (isSinglePost && !post!.isFavorited)
                WFabBuilder.getSinglePostAddFavAction(context, post!),
              if (!isSinglePost)
                getMultiplePostsRemoveFromSetAction(context, posts!),
              if (isSinglePost)
                getSinglePostRemoveFromSetAction(context, post!),
              if (!isSinglePost &&
                  posts!.indexWhere((p) => p.isFavorited) != -1)
                getMultiplePostsRemoveFavAction(context, posts!),
              if (isSinglePost && post!.isFavorited)
                getSinglePostRemoveFavAction(context, post!),
              if (isSinglePost) getSinglePostUpvoteAction(context, post!),
              if (isSinglePost) getSinglePostDownvoteAction(context, post!),
              if (isSinglePost) getSinglePostEditAction(context, post!),
              if (isSinglePost && isSelected != null)
                if (isSelected)
                  getSinglePostToggleSelectAction(
                    context,
                    post!,
                    isSelected: isSelected,
                    toggleSelection: toggleSelectionCallback,
                  )
                else
                  getSinglePostToggleSelectAction(
                    context,
                    post!,
                    isSelected: isSelected,
                    toggleSelection: toggleSelectionCallback,
                  ),
              // getPrintSelectionsAction(context, post, posts),
              if (customActions != null) ...customActions!,
            ]
          : [],
    );
  }
}

/* class WFabWrapper extends StatefulWidget {
  final void Function()? onClearSelections;
  const WFabWrapper({
    super.key,
    this.onClearSelections,
  });

  @override
  State<WFabWrapper> createState() => _WFabWrapperState();
}

class _WFabWrapperState extends State<WFabWrapper> {
  @override
  Widget build(BuildContext context) {
    return WFabBuilder.multiplePosts(
      posts: Provider.of<ManagedPostCollectionSync>(context, listen: true)
              .posts
              ?.posts
              .where((e) =>
                  Provider.of<SearchResultsNotifier>(context, listen: true)
                      .selectedPostIds
                      .contains(e.id))
              .toList() ??
          [],
      onClearSelections: widget.onClearSelections,
    );
  }
}
 */