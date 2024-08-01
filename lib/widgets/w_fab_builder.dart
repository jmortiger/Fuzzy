import 'package:flutter/material.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

import '../models/search_cache.dart';
import '../web/e621/e621_access_data.dart';

late final lRecord = lm.genLogger("WFabBuilder");
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;
// #endregion Logger

class WFabBuilder extends StatelessWidget {
  final List<E6PostResponse>? posts;
  final E6PostResponse? post;
  bool get isSinglePost => post != null;
  bool get isMultiplePosts => posts != null;
  final void Function()? onClearSelections;

  const WFabBuilder.singlePost({
    super.key,
    required E6PostResponse this.post,
    // this.onClearSelections,
  })  : posts = null,
        onClearSelections = null;
  const WFabBuilder.multiplePosts({
    super.key,
    required List<E6PostResponse> this.posts,
    this.onClearSelections,
  }) : post = null;
  static ActionButton getClearSelectionButton(
    BuildContext context, [
    void Function()? clearSelection,
  ]) =>
      ActionButton(
        icon: const Icon(Icons.clear),
        tooltip: "Clear Selections",
        onPressed: clearSelection ??
            Provider.of<SearchResultsNotifier>(
              context,
              listen: false,
            ).clearSelections,
      );

  static ActionButton getSinglePostUpvoteAction(
    BuildContext context,
    E6PostResponse post,
  ) {
    return ActionButton(
      icon: const Icon(Icons.arrow_upward),
      tooltip: "Upvote",
      onPressed: () async {
        print("Upvoting ${post.id}...");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upvoting ${post.id}...")),
        );
        e621.Api.sendRequest(
          e621.Api.initVotePostRequest(
            postId: post.id,
            score: 1,
            credentials: E621AccessData.fallback?.cred,
          ),
        ).then(
          (v) {
            print(v.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("${v.statusCode}: ${v.reasonPhrase}"),
              ),
            );
          },
        );
      },
    );
  }

  static ActionButton getSinglePostDownvoteAction(
    BuildContext context,
    E6PostResponse post,
  ) {
    return ActionButton(
      icon: const Icon(Icons.arrow_downward),
      tooltip: "Downvote",
      onPressed: () async {
        print("Downvoting ${post.id}...");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Downvoting ${post.id}...")),
        );
        e621.Api.sendRequest(
          e621.Api.initVotePostRequest(
            postId: post.id,
            score: -1,
            credentials: E621AccessData.fallback?.cred,
          ),
        ).then(
          (v) {
            print(v.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("${v.statusCode}: ${v.reasonPhrase}"),
              ),
            );
          },
        );
      },
    );
  }

  static ActionButton getSinglePostAddFavAction(
    BuildContext context,
    E6PostResponse post,
  ) {
    return ActionButton(
      icon: const Icon(Icons.favorite),
      tooltip: "Add to favorites",
      onPressed: () async {
        print("Adding ${post.id} to favorites...");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Adding ${post.id} to favorites...")),
        );
        E621
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
            print(v.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("${v.statusCode}: ${v.reasonPhrase}"),
                action: SnackBarAction(
                  label: "Undo",
                  onPressed: () async {
                    try {
                      var newStream = E621.sendRequest(
                        E621.initDeleteFavoriteRequest(
                          int.parse(
                            v.request!.url.queryParameters["post_id"]!,
                          ),
                          username: E621AccessData.fallback?.username,
                          apiKey: E621AccessData.fallback?.apiKey,
                        ),
                      );
                      newStream.then(
                        (value2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${value2.statusCode}: ${value2.reasonPhrase}",
                              ),
                            ),
                          );
                        },
                      );
                    } catch (e) {
                      print(e);
                      rethrow;
                    }
                  },
                ),
              ),
            );
          },
        );
      },
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
        print("Adding ${posts.length} posts to favorites...");
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
  /* static ActionButton getMultiplePostsUpvoteAction(
    BuildContext context,
    List<E6PostResponse> posts,
  ) {
    return ActionButton(
      icon: const Icon(Icons.favorite),
      tooltip: "Upvote selected to favorites",
      onPressed: () async {
        print("Upvoting ${posts.length} posts to favorites...");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Upvoting ${posts.length} posts to favorites...")),
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
  } */

  static ActionButton getMultiplePostsAddToSetAction(
    BuildContext context,
    List<E6PostResponse> postListings,
  ) {
    return ActionButton(
      icon: const Icon(Icons.add),
      tooltip: "Add selected to set",
      onPressed: () {
        print("To Be Implemented");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("To Be Implemented")),
        );
      },
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
        print("Adding ${postListing.id} to a set");
        var v = await showDialog<e621.PostSet>(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: WSearchSet(
                initialLimit: 10,
                initialPage: null,
                initialSearchCreatorName: "***REMOVED***,
                initialSearchOrder: e621.SetOrder.updatedAt,
                initialSearchName: null,
                initialSearchShortname: null,
                onSelected: (e621.PostSet set) => Navigator.pop(context, set),
              ),
              // scrollable: true,
            );
          },
        );
        if (v != null) {
          print("Adding ${postListing.id} to set ${v.id}");
          var res = await E621
              .sendRequest(e621.Api.initAddToSetRequest(
                v.id,
                [postListing.id],
                credentials: (E621.accessData.$Safe ??=
                        await E621AccessData.devAccessData.getItem())
                    .cred,
              ))
              .toResponse();
          if (res.statusCode == 201) {
            print("${postListing.id} successfully added to set ${v.id}");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      "${postListing.id} successfully added to set ${v.id}"),
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
      onPressed: () {
        print("To Be Implemented");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("To Be Implemented")),
        );
      },
    );
  }

  static ActionButton getSinglePostRemoveFromSetAction(
      BuildContext context, E6PostResponse e6postResponse) {
    return ActionButton(
      icon: const Icon(Icons.delete),
      tooltip: "Remove selected from set",
      onPressed: () {
        print("To Be Implemented");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("To Be Implemented")),
        );
      },
    );
  }

  static ActionButton getMultiplePostsRemoveFavAction(
      BuildContext context, List<E6PostResponse> posts) {
    return ActionButton(
      icon: const Icon(Icons.heart_broken_outlined),
      tooltip: "Remove selected from favorites",
      onPressed: () async {
        print("Removing ${posts.length}"
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
            print(error);
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
      tooltip: "Remove selected from favorites",
      onPressed: () async {
        print("Removing ${post.id} from favorites...");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Removing ${post.id} from favorites..."),
          ),
        );
        E621
            .sendRequest(
              E621.initDeleteFavoriteRequest(
                post.id,
                username: E621AccessData.fallback?.username,
                apiKey: E621AccessData.fallback?.apiKey,
              ),
            )
            .toResponse()
            .onError(defaultOnError)
            .then(
              (value) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "${value.statusCode}: ${value.reasonPhrase}",
                  ),
                  action: SnackBarAction(
                    label: "Undo",
                    onPressed: () async {
                      var newStream = E621
                          .sendRequest(
                        E621.initAddFavoriteRequest(
                          int.parse(
                            value.request!.url.pathSegments.last.substring(
                              0,
                              value.request!.url.pathSegments.last.indexOf("."),
                            ),
                          ),
                          username: E621AccessData.fallback?.username,
                          apiKey: E621AccessData.fallback?.apiKey,
                        ),
                      )
                          .onError((error, stackTrace) {
                        print(error);
                        throw error!;
                      });
                      newStream.then(
                        (value2) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                              "${value2.statusCode}: ${value2.reasonPhrase}",
                            ),
                          ));
                        },
                      );
                    },
                  ),
                ),
              ),
            )
            .onError((error, stackTrace) {
          print(error);
          throw error!;
        });
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
        print("Printing selections...");
        var s = "posts: ${posts?.fold(
          "",
          (previousValue, element) => "$previousValue, ${element.id}",
        )}";
        print(s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s),
          ),
        );
        s = "post: ${post?.id}";
        print(s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpandableFab(
      useDefaultHeroTag: false,
      distance: 112,
      disabledTooltip: (isSinglePost || (isMultiplePosts && posts!.isNotEmpty))
          ? ""
          : "Long-press to select posts and perform bulk actions.",
      children: (isSinglePost || (isMultiplePosts && posts!.isNotEmpty))
          ? [
              if (!isSinglePost /* && onClearSelections != null */)
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
              // getPrintSelectionsAction(context, post, posts),
            ]
          : [],
    );
  }
}

class WFabWrapper extends StatefulWidget {
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
      posts: Provider.of<SearchCacheLegacy>(context, listen: true)
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
