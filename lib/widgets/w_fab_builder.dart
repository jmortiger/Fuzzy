import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/pages/edit_post_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e6_actions.dart' as actions;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart'
    show ManagedPostCollectionSync, PostCollectionSync;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

ValueNotifier<bool> useFab = ValueNotifier(false);

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
  bool get hasMultiplePosts => posts?.isNotEmpty ?? false;
  final void Function()? onClearSelections;
  final bool Function(int)? toggleSelectionCallback;
  final bool Function(int)? isPostSelected;
  // final srn_lib.SearchResultsNotifier? selectedPosts;
  final List<E6PostResponse>? selectedPosts;

  const WFabBuilder.singlePost({
    super.key,
    required E6PostResponse this.post,
    this.onClearSelections,
    this.toggleSelectionCallback,
    this.isPostSelected,
    this.customActions,
    this.selectedPosts,
  }) : posts = null;
  const WFabBuilder.multiplePosts({
    super.key,
    required List<E6PostResponse> this.posts,
    this.onClearSelections,
    this.toggleSelectionCallback,
    this.isPostSelected,
    this.customActions,
    // this.selectedPosts,
  })  : post = null,
        selectedPosts = null /* posts */;

  @widgetFactory
  static Widget buildItFull(BuildContext context) {
    return Selector2<SearchResultsNotifier, ManagedPostCollectionSync,
        (Set<int>, PostCollectionSync)>(
      builder: (context, value, child) => WFabBuilder.multiplePosts(
        key: ObjectKey(value.$1),
        posts: value.$2
            .where((e) => value.$1.contains(e.inst.$Safe?.id))
            .map((e) => e.inst.$)
            .toList(),
      ),
      selector: (ctx, p1, p2) => (p1.selectedPostIds, p2.collection),
      shouldRebuild: (previous, next) => setEquals(previous.$1, next.$1),
    );
  }

  /// TODO: Fails after toggle selection in single post view
  static ActionButton getClearSelectionButton(
    BuildContext context, [
    void Function()? clearSelection,
    // srn_lib.SearchResultsNotifier? selected,
    List<E6PostResponse>? selected,
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
  static Widget getChangePageSelectionButton(
    BuildContext context, {
    required bool select,
  }) {
    final mpcW = Provider.of<ManagedPostCollectionSync>(context, listen: false);
    return ActionButton(
      icon: select
          ? const Icon(Icons.playlist_add_check, color: Colors.black54)
          : const Icon(Icons.playlist_remove, color: Colors.black54),
      tooltip: "${select ? "Select" : "Deselect"} all on page",
      onPressed: mpcW.getPostsOnPageSync(mpcW.currentPageIndex) != null
          ? () {
              final mpc = Provider.of<ManagedPostCollectionSync>(context,
                      listen: false),
                  page = mpc.getPostsOnPageSync(mpc.currentPageIndex);
              Provider.of<SearchResultsNotifier>(
                context,
                listen: false,
              ).assignPostSelections(
                select: select,
                postIds: page!.map((e) => e.id).toList(),
              );
            }
          : null,
    );
  }

  static ActionButton getSinglePostUpvoteAction(
    BuildContext context,
    E6PostResponse post, {
    bool noUnvote = true,
  }) {
    return ActionButton(
      icon: const Icon(Icons.arrow_upward),
      tooltip: "Upvote",
      onPressed: () => actions
          .voteOnPostWithPost(
            context: context,
            post: post,
            isUpvote: true,
            noUnvote: noUnvote,
            updatePost: post is E6PostMutable,
          )
          .ignore(),
    );
  }

  static ActionButton getSinglePostDownvoteAction(
    BuildContext context,
    E6PostResponse post, {
    bool noUnvote = true,
  }) {
    return ActionButton(
      icon: const Icon(Icons.arrow_downward),
      tooltip: "Downvote",
      onPressed: () => actions
          .voteOnPostWithPost(
            context: context,
            post: post,
            isUpvote: false,
            noUnvote: noUnvote,
            updatePost: post is E6PostMutable,
          )
          .ignore(),
    );
  }

  static ActionButton getMultiplePostsUpvoteAction(
    BuildContext context,
    List<E6PostResponse> posts, {
    bool noUnvote = true,
  }) {
    return ActionButton(
      icon: const Icon(Icons.keyboard_double_arrow_up),
      tooltip: "Upvote Selected",
      onPressed: () => actions.voteOnPostsWithPosts(
        isUpvote: true,
        noUnvote: noUnvote,
        posts: posts,
        context: context,
        updatePosts: true,
      ),
    );
  }

  static ActionButton getMultiplePostsDownvoteAction(
    BuildContext context,
    List<E6PostResponse> posts, {
    bool noUnvote = true,
  }) {
    return ActionButton(
      icon: const Icon(Icons.keyboard_double_arrow_down),
      tooltip: "Downvote Selected",
      onPressed: () => actions.voteOnPostsWithPosts(
        isUpvote: false,
        noUnvote: noUnvote,
        posts: posts,
        context: context,
        updatePosts: true,
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
      onPressed: () => actions
          .addPostToFavoritesWithPost(
            post: post,
            context: context,
            updatePost: post is E6PostMutable,
          )
          .ignore(),
    );
  }

  static ActionButton getMultiplePostsAddFavAction(
    BuildContext context,
    List<E6PostResponse> posts,
  ) {
    return ActionButton(
      icon: const Icon(Icons.favorite),
      tooltip: "Add selected to favorites",
      onPressed: () => actions
          .addToFavoritesWithPosts(
            posts: posts,
            context: context,
          )
          .ignore(),
    );
  }

  static ActionButton getMultiplePostsAddToSetAction(
    BuildContext context,
    List<E6PostResponse> posts,
  ) {
    return ActionButton(
      icon: const Icon(Icons.add),
      tooltip: "Add selected to set",
      onPressed: () => actions
          .addToSetWithPosts(
            context: context,
            posts: posts,
          )
          .ignore(),
    );
  }

  static ActionButton getSinglePostAddToSetAction(
    BuildContext context,
    E6PostResponse post,
  ) {
    return ActionButton(
      icon: const Icon(Icons.add),
      tooltip: "Add to set",
      onPressed: () =>
          actions.addToSetWithPost(context: context, post: post).ignore(),
    );
  }

  static ActionButton getMultiplePostsRemoveFromSetAction(
      BuildContext context, List<E6PostResponse> posts) {
    return ActionButton(
      icon: const Icon(Icons.delete),
      tooltip: "Remove selected from set",
      onPressed: () => actions
          .removeFromSetWithPosts(
            context: context,
            posts: posts,
          )
          .ignore(),
    );
  }

  static ActionButton getSinglePostRemoveFromSetAction(
      BuildContext context, E6PostResponse post) {
    return ActionButton(
      icon: const Icon(Icons.delete),
      tooltip: "Remove selected from set",
      onPressed: () => actions
          .removeFromSetWithPost(
            context: context,
            post: post,
          )
          .ignore(),
    );
  }

  static ActionButton getMultiplePostsRemoveFavAction(
      BuildContext context, List<E6PostResponse> posts) {
    return ActionButton(
      icon: const Icon(Icons.heart_broken_outlined),
      tooltip: "Remove selected from favorites",
      onPressed: () => actions
          .removeFromFavoritesWithPosts(
            posts: posts,
            context: context,
          )
          .ignore(),
    );
  }

  static ActionButton getSinglePostRemoveFavAction(
      BuildContext context, E6PostResponse post) {
    return ActionButton(
      icon: const Icon(Icons.heart_broken_outlined),
      tooltip: "Remove from favorites",
      onPressed: () => actions
          .removePostFromFavoritesWithPost(
            post: post,
            context: context,
            updatePost: post is E6PostMutable,
          )
          .ignore(),
    );
  }

  static ActionButton getSinglePostEditAction(
      BuildContext context, E6PostResponse post) {
    return ActionButton(
      icon: const Icon(Icons.edit),
      tooltip: "Edit",
      onPressed: () {
        logger.finer("Editing ${post.id}...");
        util.showUserMessage(
          context: context,
          content: Text("Editing ${post.id}..."),
        );
        Navigator.pushNamed(
          context,
          "${EditPostPageLoader.routeNameString}?postId=${post.id}",
          arguments: (post: post),
          // MaterialPageRoute(
          //   builder: (context) => EditPostPageLoader(postId: post.id),
          // ),
        ).ignore();
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
    List<E6PostResponse>? selected,
  }) {
    return ActionButton(
      icon: isSelected == null
          ? const Icon(Icons.edit)
          : isSelected
              ? const Icon(Icons.check_box_outline_blank)
              : const Icon(Icons.check_box),
      tooltip: tooltip ??
          (isSelected == null
              ? null
              : isSelected
                  ? "Remove from selections"
                  : "Add to selections"),
      onPressed: () {
        final p = "${post.id}: $tooltip";
        logger.finer(p);
        util.showUserMessage(context: context, content: Text(p));
        // context.watch<SearchResultsNotifier>().togglePostSelection(
        (selected == null)
            ? toggleSelection?.call(post.id) ??
                // selected?.togglePostSelection(postId: post.id) ??
                Provider.of<SearchResultsNotifier>(context, listen: false)
                    .togglePostSelection(
                  postId: post.id,
                  resolveDesync: false,
                  throwOnDesync: false,
                )
            : selected.remove(post)
                ? ""
                : selected.add(post);
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
        util.showUserMessage(context: context, content: Text(s));
        s = "post: ${post?.id}";
        logger.finer(s);
        util.showUserMessage(
          context: context,
          content: Text(s),
          autoHidePrior: false,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool? isSelected;
    bool canSelect = false;
    try {
      Provider.of<SearchResultsNotifier>(context, listen: false);
      canSelect = true;
      if (isSinglePost) {
        isSelected = isPostSelected?.call(post!.id) ??
            // selectedPosts?.getIsPostSelected(post!.id) ??
            selectedPosts?.any((e) => e.id == post!.id) ??
            Provider.of<SearchResultsNotifier>(context, listen: false)
                .getIsPostSelected(post!.id);
      }
    } catch (e, s) {
      logger.warning("Couldn't access SearchResultsNotifier in fab", e, s);
    }
    Widget builder(
            BuildContext context,
            ({
              bool useFab,
              List<E6PostResponse>? posts,
              E6PostResponse? post
            }) v,
            _) =>
        (v.useFab ? ExpandableFab.new : WPullTab.new)(
          anchorAlignment: AnchorAlignment.right,
          openIcon: isMultiplePosts
              ? IconButton(
                  onPressed: null,
                  disabledColor: Theme.of(context)
                          .iconButtonTheme
                          .style
                          ?.iconColor
                          ?.resolve(<WidgetState>{}) ??
                      Theme.of(context).iconTheme.color,
                  icon: Text(posts!.length.toString()),
                )
              : IconButton(
                  onPressed: null,
                  disabledColor: Theme.of(context)
                          .iconButtonTheme
                          .style
                          ?.iconColor
                          ?.resolve(<WidgetState>{}) ??
                      Theme.of(context).iconTheme.color,
                  icon: const Icon(Icons.create),
                ),
          useDefaultHeroTag: false,
          distance: v.useFab
              ? Platform.isDesktop
                  ? 112
                  : 224
              : MediaQuery.sizeOf(context).width - 24 * 2,
          initialOpen: true,
          // disabledTooltip: (isSinglePost || (isMultiplePosts && posts!.isNotEmpty))
          //     ? ""
          //     : "Long-press to select posts and perform bulk actions.",
          disabledTooltip:
              "Long-press to select posts and perform bulk actions.",
          children: /* (isSinglePost ||
                (isMultiplePosts && posts!.isNotEmpty) ||
                (customActions?.isNotEmpty ?? false))
            ?  */
              [
            if (hasMultiplePosts)
              getClearSelectionButton(
                context,
                onClearSelections, /* selectedPosts, */
              ),
            if (isMultiplePosts && canSelect)
              getChangePageSelectionButton(context, select: true),
            if (hasMultiplePosts && canSelect)
              getChangePageSelectionButton(context, select: false),
            if (isSinglePost)
              getSinglePostAddToSetAction(context, post!)
            else
              getMultiplePostsAddToSetAction(context, posts!),
            if (hasMultiplePosts && posts!.indexWhere((p) => !p.isFavorited) != -1)
              getMultiplePostsAddFavAction(context, posts!),
            if (isSinglePost && !post!.isFavorited)
              getSinglePostAddFavAction(context, post!),
            if (isSinglePost)
              getSinglePostRemoveFromSetAction(context, post!)
            else
              getMultiplePostsRemoveFromSetAction(context, posts!),
            if (hasMultiplePosts && posts!.indexWhere((p) => p.isFavorited) != -1)
              getMultiplePostsRemoveFavAction(context, posts!),
            if (isSinglePost && post!.isFavorited)
              getSinglePostRemoveFavAction(context, post!),
            if (isSinglePost)
              v.useFab
                  ? getSinglePostUpvoteAction(context, post!)
                  : getSinglePostDownvoteAction(context, post!)
            else
              v.useFab
                  ? getMultiplePostsUpvoteAction(context, posts!)
                  : getMultiplePostsDownvoteAction(context, posts!),
            if (isSinglePost)
              v.useFab
                  ? getSinglePostDownvoteAction(context, post!)
                  : getSinglePostUpvoteAction(context, post!)
            else
              v.useFab
                  ? getMultiplePostsDownvoteAction(context, posts!)
                  : getMultiplePostsUpvoteAction(context, posts!),
            if (isSinglePost) getSinglePostEditAction(context, post!),
            if (isSinglePost && isSelected != null)
              getSinglePostToggleSelectAction(
                context,
                post!,
                isSelected: isSelected,
                toggleSelection: toggleSelectionCallback,
                selected: selectedPosts,
              ),
            if (AppSettings.i?.enableDownloads ?? true)
              if (isSinglePost)
                ActionButton(
                  icon: const Icon(Icons.download),
                  tooltip: "Download",
                  onPressed: () => actions
                      .downloadPostWithPost(context: context, post: v.post!)
                      .ignore(),
                )
              else if (hasMultiplePosts)
                ActionButton(
                  icon: const Icon(Icons.download),
                  tooltip: "Download",
                  onPressed: () => actions
                      .downloadPostsWithPosts(context: context, posts: v.posts!)
                      .ignore(),
                ),
            if (AppSettings.i?.enableDownloads ?? true)
              if (isSinglePost && post!.description.isNotEmpty)
                ActionButton(
                  icon: const Icon(Icons.download),
                  tooltip: "Download Description",
                  onPressed: () => actions
                      .downloadDescriptionWithPost(
                          context: context, post: v.post!)
                      .ignore(),
                )
              else if (isMultiplePosts &&
                  posts!.any((e) => e.description.isNotEmpty))
                ActionButton(
                  icon: const Icon(Icons.download),
                  tooltip: "Download Descriptions",
                  onPressed: () => actions
                      .downloadDescriptionsWithPosts(
                          context: context, posts: v.posts!)
                      .ignore(),
                ),
            // getPrintSelectionsAction(context, post, posts),
            if (customActions != null) ...customActions!,
          ] /* : [] */,
        );
    return post is PostNotifier
        ? SelectorNotifier2(
            value1: useFab,
            value2: post as PostNotifier,
            selector: (_, value, post) =>
                (useFab: value.value, post: post, posts: posts),
            builder: builder,
          )
        : builder(
            context,
            (
              useFab: useFab.value,
              post: post,
              posts: posts,
            ),
            null);
    // : SelectorNotifier(
    //     value: useFab,
    //     selector: (_, useFab) => (
    //       useFab: useFab.value,
    //       post: post,
    //       posts: posts,
    //     ),
    //     builder: builder,
    //   );
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
