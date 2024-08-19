import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/pages/edit_post_page.dart';
import 'package:fuzzy/web/e621/e6_actions.dart' as actions;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

class WFabBuilder extends StatelessWidget {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WFabBuilder");
  // #endregion Logger
  final List<ActionButton>? customActions;
  final List<E6PostResponse>? posts;
  final E6PostResponse? post;
  bool get isSinglePost => post != null;
  bool get isMultiplePosts => posts != null;
  final void Function()? onClearSelections;
  final bool Function(int)? toggleSelectionCallback;
  final bool Function(int)? isPostSelected;
  // final srn_lib.SearchResultsNotifier? selectedPosts;

  const WFabBuilder.singlePost({
    super.key,
    required E6PostResponse this.post,
    this.onClearSelections,
    this.toggleSelectionCallback,
    this.isPostSelected,
    this.customActions,
    // required this.selectedPosts,
  }) : posts = null;
  const WFabBuilder.multiplePosts({
    super.key,
    required List<E6PostResponse> this.posts,
    this.onClearSelections,
    this.toggleSelectionCallback,
    this.isPostSelected,
    this.customActions,
    // this.selectedPosts,
  }) : post = null;
  static ActionButton getClearSelectionButton(
    BuildContext context, [
    void Function()? clearSelection,
    // srn_lib.SearchResultsNotifier? selected,
  ]) =>
      ActionButton(
        icon: const Icon(Icons.clear),
        tooltip: "Clear Selections",
        onPressed: clearSelection ??
            // selected?.clearSelections ??
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
      onPressed: () => actions.addToFavoritesWithPosts(
        posts: posts,
        context: context,
      ),
      // onPressed: () async {
      //   logger.finer("Adding ${posts.length} posts to favorites...");
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //         content: Text("Adding ${posts.length} posts to favorites...")),
      //   );
      //   E621.sendAddFavoriteRequestBatch(
      //     posts.map((e) => e.id),
      //     username: E621AccessData.fallback?.username,
      //     apiKey: E621AccessData.fallback?.apiKey,
      //     onComplete: (responses) {
      //       var total = responses.length;
      //       responses.removeWhere(
      //         (element) => element.statusCodeInfo.isSuccessful,
      //       );
      //       var sbs = "${total - responses.length}/"
      //           "$total posts added to favorites!";
      //       responses.where((r) => r.statusCode == 422).forEach((r) async {
      //         var pId = int.parse(r.request!.url.queryParameters["post_id"]!);
      //         if (context.mounted &&
      //             Provider.of<CachedFavorites>(context, listen: false)
      //                 .postIds
      //                 .contains(pId)) {
      //           sbs += " $pId Cached";
      //         }
      //       });
      //       ScaffoldMessenger.of(context).showSnackBar(
      //         SnackBar(
      //           content: Text(sbs),
      //           action: SnackBarAction(
      //             label: "Undo",
      //             onPressed: () async {
      //               E621.sendDeleteFavoriteRequestBatch(
      //                 responses.map((e) => int.parse(
      //                       e.request!.url.queryParameters["post_id"]!,
      //                     )),
      //                 username: E621AccessData.fallback?.username,
      //                 apiKey: E621AccessData.fallback?.apiKey,
      //                 onComplete: (responses) =>
      //                     ScaffoldMessenger.of(context).showSnackBar(
      //                   SnackBar(
      //                     content: Text(
      //                         "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts removed from favorites!"),
      //                   ),
      //                 ),
      //               );
      //             },
      //           ),
      //         ),
      //       );
      //     },
      //   );
      // },
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
    E6PostResponse post,
  ) {
    return ActionButton(
      icon: const Icon(Icons.add),
      tooltip: "Add to set",
      onPressed: () => actions.addToSetWithPost(context: context, post: post),
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
      onPressed: () => actions.removeFromSetWithPost(
        context: context,
        post: post,
      ),
    );
  }

  static ActionButton getMultiplePostsRemoveFavAction(
      BuildContext context, List<E6PostResponse> posts) {
    return ActionButton(
      icon: const Icon(Icons.heart_broken_outlined),
      tooltip: "Remove selected from favorites",
      onPressed: () => actions.removeFromFavoritesWithPosts(
        posts: posts,
        context: context,
      ),
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
    // srn_lib.SearchResultsNotifier? selected,
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
            // selected?.togglePostSelection(postId: post.id) ??
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
        isSelected = (isPostSelected?.call ??
            // selectedPosts?.getIsPostSelected ??
            Provider.of<SearchResultsNotifier>(context, listen: false)
                .getIsPostSelected)(post!.id);
      }
    } catch (e/* , s */) {
      logger
          .warning("Couldn't access SearchResultsNotifier in fab" /* , e, s */);
    }

    return ExpandableFab(
      openIcon: isMultiplePosts
          ? Text(posts!.length.toString())
          : const Icon(Icons.create),
      useDefaultHeroTag: false,
      distance: Platform.isDesktop ? 112 : 224,
      // disabledTooltip: (isSinglePost || (isMultiplePosts && posts!.isNotEmpty))
      //     ? ""
      //     : "Long-press to select posts and perform bulk actions.",
      children: (isSinglePost ||
              (isMultiplePosts && posts!.isNotEmpty) ||
              (customActions?.isNotEmpty ?? false))
          ? [
              if (!isSinglePost)
                WFabBuilder.getClearSelectionButton(
                    context, onClearSelections /* , selectedPosts */),
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
                    // selected: selectedPosts,
                  )
                else
                  getSinglePostToggleSelectAction(
                    context,
                    post!,
                    isSelected: isSelected,
                    toggleSelection: toggleSelectionCallback,
                    // selected: selectedPosts,
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
