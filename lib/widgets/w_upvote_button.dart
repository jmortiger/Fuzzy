import 'package:flutter/material.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_fab_builder.dart';
import 'package:j_util/j_util_widgets.dart';

class WUpvoteButton extends StatelessWidget {
  final E6PostResponse? post;
  final int? postId;
  int get myPostId => postId ?? post!.id;
  // const WUpvoteButton.fromId({
  //   super.key,
  //   required int this.postId
  // }) : post = null;
  const WUpvoteButton.fromPost({
    super.key,
    required E6PostResponse this.post,
  }) : postId = null;

  @override
  Widget build(BuildContext context) {
    return PullTab(
      anchorAlignment: AnchorAlignment.bottom,
      openIcon: const Icon(Icons.import_export),
      // initialOpen: true,
      distance: 200,
      color: Theme.of(context).buttonTheme.colorScheme?.onPrimary,
      children: [
        WFabBuilder.getSinglePostDownvoteAction(context, post!),
        WFabBuilder.getSinglePostUpvoteAction(context, post!),
        // WFabBuilder.getSinglePostDownvoteAction(context, post!),
      ],
    );
  }
}
